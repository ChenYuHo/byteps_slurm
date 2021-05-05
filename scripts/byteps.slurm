#!/bin/bash
#SBATCH --partition=batch
#SBATCH -J byteps_singularity
#SBATCH -o %J.out
#SBATCH -e %J.err
#SBATCH --time=0:1:59
#SBATCH --mem=64g
#SBATCH --gres=gpu:v100:1
#SBATCH --ntasks-per-node=1
#SBATCH -c 8
#SBATCH --constraint=gpu_ai

set -ux

# https://stackoverflow.com/questions/56962129/how-to-get-original-location-of-script-used-for-slurm-job
SCRIPTPATH=$(scontrol show job $SLURM_JOBID | awk -F= '/Command=/{print $2}')
# https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
SCRIPTDIR="$( cd -- "$(dirname "$SCRIPTPATH")" >/dev/null 2>&1 ; pwd -P )"
WDIR=$SCRIPTDIR
SINGULARITY_IMAGE=$WDIR/byteps.sif
INTERFACE=ib0
LOG_DIR=${WDIR}/logs
mkdir -p $LOG_DIR

MASTER_IP=$(ifconfig $INTERFACE 2>/dev/null | grep "inet " | awk '{print $2}')
PORT=`python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'`
THIS_HOST=$(hostname)
echo localhost is $THIS_HOST

# if no arguments given, use all tasks for workers and servers (colocated)
if [[ $# -eq 0 ]]; then
  MODE=colocated
  NW=$SLURM_NTASKS
  NS=$NW
  WORKER_HOSTNAMES="localhost:1,""$(srun -N$SLURM_NTASKS -c 1 hostname | grep -v $THIS_HOST | paste -sd ',' - | sed 's%,%:1,%g')"":1"
  SERVER_HOSTNAMES=$WORKER_HOSTNAMES
else
  MODE=dedicated
  NW=$1
  NS=${2:-$((SLURM_NTASKS-NW))}
  HOSTS=$(srun -N$SLURM_NTASKS -c 1 hostname | grep -v $THIS_HOST)
  WORKER_HOSTNAMES="$(echo ${HOSTS} | cut -d' ' -f-${NW} --output-delimiter=':1,')"":1"
  SERVER_HOSTNAMES="localhost:1,""$(echo ${HOSTS} | cut -d' ' -f$((NW+1))- --output-delimiter=':1,')"":1"
fi

LOG_NAME="byteps_NW_${NW}_NS_${NS}_MODE_${MODE}_${SLURM_JOB_ID}"
echo nodes: $SLURM_JOB_NODELIST
echo $NW workers $NS servers running $MODE mode
echo workers: $WORKER_HOSTNAMES
echo servers: $SERVER_HOSTNAMES

module load singularity/3.6

echo scheduler $(hostname) IP $MASTER_IP PORT $PORT
export SINGULARITYENV_DMLC_ENABLE_RDMA=ibverbs
export SINGULARITYENV_DMLC_INTERFACE=$INTERFACE
export SINGULARITYENV_DMLC_NUM_WORKER=$NW
export SINGULARITYENV_DMLC_NUM_SERVER=$NS
export SINGULARITYENV_DMLC_PS_ROOT_URI=${MASTER_IP}
export SINGULARITYENV_DMLC_PS_ROOT_PORT=$PORT
export SINGULARITYENV_BYTEPS_ENABLE_IPC=0
export SINGULARITYENV_DMLC_ROLE=scheduler
export SINGULARITYENV_BYTEPS_RDMA_RX_DEPTH=64
export SINGULARITYENV_BYTEPS_SERVER_ENGINE_THREAD=8
singularity exec -B /usr/lib64 ${SINGULARITY_IMAGE} bpslaunch > ${LOG_DIR}/${LOG_NAME}_scheduler.out 2> ${LOG_DIR}/${LOG_NAME}_scheduler.err &
SCHEDULER_PID=$!

module load openmpi/4.0.3-cuda10.1
export OMPI_MCA_btl=openib
export OMPI_MCA_btl_openib_allow_ib=1

if [[ $MODE = "colocated" ]]; then
  echo launching colocated workers and servers on $WORKER_HOSTNAMES
  mpirun -map-by slot -bind-to none -nooversubscribe -output-filename ${LOG_DIR}/${LOG_NAME}_workers_servers -n $NW -H ${WORKER_HOSTNAMES} $WDIR/colocated_worker_server.sh $MASTER_IP $PORT $NW $NS ${WORKER_COMMAND:-""}
  kill $SCHEDULER_PID
else
  echo launching servers on $SERVER_HOSTNAMES
  #-mca pml ob1
  mpirun -map-by slot -bind-to none -nooversubscribe -output-filename ${LOG_DIR}/${LOG_NAME}_servers -n $NS -H ${SERVER_HOSTNAMES} $WDIR/worker_server.sh $MASTER_IP $PORT $NW $NS server &
  # > /dev/null 2>&1 &
  SERVERS_PID=$!
  
  echo launching workers on $WORKER_HOSTNAMES
  mpirun -map-by slot -bind-to none -nooversubscribe -output-filename ${LOG_DIR}/${LOG_NAME}_workers -n $NW -H ${WORKER_HOSTNAMES} $WDIR/worker_server.sh $MASTER_IP $PORT $NW $NS worker ${WORKER_COMMAND:-""} # > /dev/null 2>&1
  kill $SCHEDULER_PID
  kill $SERVERS_PID
fi

echo "mv $WDIR/${SLURM_JOBID}.out ${LOG_DIR}/${LOG_NAME}_slurm.out" >> rename.sh
echo "mv $WDIR/${SLURM_JOBID}.err ${LOG_DIR}/${LOG_NAME}_slurm.err" >> rename.sh
chmod +x rename.sh
