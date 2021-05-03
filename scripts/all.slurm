#!/bin/bash
#SBATCH --partition=batch
#SBATCH -J byteps_singularity
#SBATCH -o logs/%J.out
#SBATCH -e logs/%J.err
#SBATCH --time=0:4:59
#SBATCH --mem=64g
#SBATCH --gres=gpu:v100:1
#SBATCH --ntasks-per-node=1
#SBATCH -c 6
###SBATCH --constraint=gpu_ai

wdir="/ibex/scratch/hoc0a/e2e-exps/byteps/byteps_slurm"
log_dir=${wdir}/logs
mkdir -p $log_dir
NW=${1:-$((SLURM_NTASKS/2))}
NS=${2:-$((SLURM_NTASKS-NW))}
echo $NW workers $NS servers
echo nodes: $SLURM_JOB_NODELIST
#Using ib0 as interface
export INTERFACE=ib0
export interface_addr=$(ifconfig $INTERFACE 2>/dev/null | grep "inet " | awk '{print $2}')
export PORT=`python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'`
export IMAGE=/ibex/scratch/hoc0a/e2e-exps/byteps/byteps_slurm/scripts/byteps_latest.sif
THIS_HOST=$(hostname)
OTHER_HOSTS=$(srun -N$SLURM_NTASKS -c 1 /bin/hostname | grep -v ${THIS_HOST} | head -n $((NW+NS)))
WORKER_HOSTNAMES=$(echo ${OTHER_HOSTS} | cut -d' ' -f-${NW} --output-delimiter=,)
SERVER_HOSTNAMES=$(echo ${OTHER_HOSTS} | cut -d' ' -f$((NW+1))- --output-delimiter=,)

module load singularity/3.6
module load openmpi/4.0.3-cuda10.1

echo scheduler $THIS_HOST IP $interface_addr PORT $PORT
export SINGULARITYENV_DMLC_ENABLE_RDMA=ibverbs
export SINGULARITYENV_DMLC_INTERFACE=$INTERFACE
export SINGULARITYENV_DMLC_NUM_WORKER=$NW
export SINGULARITYENV_DMLC_NUM_SERVER=$NS
export SINGULARITYENV_DMLC_PS_ROOT_URI=${interface_addr}
export SINGULARITYENV_DMLC_PS_ROOT_PORT=$PORT
export SINGULARITYENV_BYTEPS_ENABLE_IPC=0
export SINGULARITYENV_DMLC_ROLE=scheduler
export SINGULARITYENV_BYTEPS_RDMA_RX_DEPTH=64
#BYTEPS_SERVER_ENGINE_THREAD=4 BYTEPS_RDMA_START_DEPTH=32 BYTEPS_RDMA_RX_DEPTH=256
singularity exec -B /usr/lib64 ${IMAGE} bpslaunch > ${log_dir}/${SLURM_JOB_ID}_scheduler.stdout 2> ${log_dir}/${SLURM_JOB_ID}_scheduler.stderr &
SCHEDULER_PID=$!


export OMPI_MCA_btl=openib
export OMPI_MCA_btl_openib_allow_ib=1
# servers
sleep 2
echo launching servers on $SERVER_HOSTNAMES
mpirun --display-map --display-allocation -map-by slot -bind-to none -nooversubscribe --mca btl_base_verbose 30 --tag-output -mca pml ob1 -output-filename ${log_dir}/${SLURM_JOB_ID}_servers -n $NS -H ${SERVER_HOSTNAMES} $wdir/scripts/worker_server.sh $interface_addr $PORT $NW $NS &
SERVERS_PID=$!

sleep 2
echo launching workers on $WORKER_HOSTNAMES
# workers
mpirun --display-map --display-allocation -map-by slot -bind-to none -nooversubscribe --mca btl_base_verbose 30 --tag-output -mca pml ob1 -output-filename ${log_dir}/${SLURM_JOB_ID}_workers -n $NW -H ${WORKER_HOSTNAMES} $wdir/scripts//worker_server.sh $interface_addr $PORT $NW $NS 'python /ibex/scratch/hoc0a/e2e-exps/byteps/byteps_slurm/scripts/bps_microbenchmark.py -t 26214400 -b 256 -d 0.5'

kill SCHEDULER_PID
kill SERVERS_PID
