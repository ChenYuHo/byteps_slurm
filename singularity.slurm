#!/bin/bash
#SBATCH --partition=batch
#SBATCH -J byteps_singularity
#SBATCH -o logs/%J.out
#SBATCH -e logs/%J.err
#SBATCH --time=0:4:59
#SBATCH --mem=64g
#SBATCH --gpus=4
#SBATCH --gpus-per-node=1
#SBATCH --constraint=v100,gpu_ai
#SBATCH --ntasks=4

wdir="/ibex/scratch/hoc0a/e2e-exps/byteps"
NW=${1:-$((SLURM_NTASKS/2))}
NS=${2:-$((SLURM_NTASKS-NW))}
echo $NW workers $NS servers
echo nodes: $SLURM_JOB_NODELIST
#Using ib0 as interface
export INTERFACE=ib0
export interface_addr=$(ifconfig $INTERFACE 2>/dev/null | grep "inet " | awk '{print $2}')
export PORT=`python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'`
export IMAGE=/ibex/scratch/hoc0a/byteps_horovod.sif

module load singularity/3.6
module load openmpi/4.0.3-cuda10.1
#module load mpich

echo scheduler $(hostname) IP $interface_addr PORT $PORT
export SINGULARITYENV_DMLC_ENABLE_RDMA=ibverbs
export SINGULARITYENV_DMLC_INTERFACE=$INTERFACE
export SINGULARITYENV_DMLC_NUM_WORKER=$NW
export SINGULARITYENV_DMLC_NUM_SERVER=$NS
export SINGULARITYENV_DMLC_PS_ROOT_URI=${interface_addr}
export SINGULARITYENV_DMLC_PS_ROOT_PORT=$PORT
export SINGULARITYENV_BYTEPS_ENABLE_IPC=0
export SINGULARITYENV_DMLC_ROLE=scheduler
#BYTEPS_SERVER_ENGINE_THREAD=4 BYTEPS_RDMA_START_DEPTH=32 BYTEPS_RDMA_RX_DEPTH=256
singularity exec ${IMAGE} bpslaunch &
SCHEDULER_PID=$!


#srun -r 1 -n $NS $wdir/bpsrun_singularity.sh server $interface_addr $PORT $NW $NS : -r $((NS+1)) -n $NW $wdir/bpsrun_singularity.sh worker $interface_addr $PORT $NW $NS 'python /examples/tensorflow/resnet-50/benchmark.py --num-iters 10 --batch-size 32'

#srun -n1 -r 1 $wdir/bpsrun_singularity.sh server $interface_addr $PORT $NW $NS &
#j=$!
#srun -n1 -r 2 $wdir/bpsrun_singularity.sh worker $interface_addr $PORT $NW $NS 'python /examples/tensorflow/resnet-50/benchmark.py --num-iters 10 --batch-size 32' &
#i=$!
#echo donelaunch
#wait $i
#wait $j

#for i in $(seq 0 $((NS-1))); do
#  echo srun -n1 -r $((i+1)) $wdir/bpsrun_singularity.sh server $interface_addr $PORT $NW $NS
#  srun -n1 -r $((i+1)) $wdir/bpsrun_singularity.sh server $interface_addr $PORT $NW $NS &
#  server_pids[${i}]=$!
#done
#WID=0
#for i in $(seq $NS $((NS+NW-1))); do
#  echo srun -n1 -r $((i+1)) $wdir/bpsrun_singularity.sh worker $interface_addr $PORT $NW $NS $WID 'python /examples/tensorflow/resnet-50/benchmark.py --num-iters 10 --batch-size 32'
#  srun -n1 -r $((i+1)) $wdir/bpsrun_singularity.sh worker $interface_addr $PORT $NW $NS $WID 'python /examples/tensorflow/resnet-50/benchmark.py --num-iters 10 --batch-size 32' &
#  worker_pids[${i}]=$!
#  WID=$((WID+1))
#done


#CONFIG="0,1,2,3,4,5,6,7     $wdir/bpsrun_singularity.sh      server  $interface_addr $PORT $NW $NS\n8,9,10,11,12,13,14,15 $wdir/bpsrun_singularity.sh worker  $interface_addr $PORT $NW $NS %o 'python $wdir/bps_microbenchmark.py -t 26214400 -b 256 -d 1.0' "
#CONFIG="$(seq -s, 0 $((NS-1)))     $wdir/bpsrun_singularity.sh      server  $interface_addr $PORT $NW $NS\n$(seq -s, $NS $((NS+NW-1))) $wdir/bpsrun_singularity.sh worker  $interface_addr $PORT $NW $NS %o 'python /examples/tensorflow/resnet-50/benchmark.py --num-iters 10 --batch-size 32' "
#CONFIG="$(seq -s, 1 $NS)     $wdir/bpsrun_singularity.sh      server  $interface_addr $PORT $NW $NS\n$(seq -s, $((NS+1)) $((NS+NW))) $wdir/bpsrun_singularity.sh worker  $interface_addr $PORT $NW $NS %o 'python /examples/tensorflow/resnet-50/benchmark.py --num-iters 10 --batch-size 32' "
#echo -e $CONFIG
#echo -e $CONFIG > $wdir/logs/${SLURM_JOB_ID}.conf
#srun --multi-prog $wdir/logs/${SLURM_JOB_ID}.conf &
#srun -n $NS -c 6 $wdir/bpsrun_singularity.sh server $interface_addr $PORT $NW $NS
#SRUN_SERVER_PID=$!
mpirun -output-filename mpi_logs_$SLURM_JOB_ID -n $((NW+NS)) $wdir/bpsrun_singularity2.sh $interface_addr $PORT $NW $NS 'python /examples/tensorflow/resnet-50/benchmark.py --num-iters 10 --batch-size 32' &
SRUN_PID=$!
#mpirun -n $((NW+NS)) $wdir/bpsrun_singularity2.sh $interface_addr $PORT $NW $NS "python $wdir/bps_microbenchmark.py -t 26214400 -b 256 -d 1.0" &

#echo "waiting for workers"
## wait for all pids
#for pid in ${worker_pids[*]}; do
#    wait $pid
#done
#
#echo "done, kill servers and scheduler"
#
#for pid in ${server_pids[*]}; do
#    kill $pid
#done
#
#kill SCHEDULER_PID

DELAY_SECONDS=10
while [ ! -f "$HOME/iamdone-$SLURM_JOB_ID" ];
    do
        sleep $DELAY_SECONDS
done

echo "done"
rm -f $HOME/iamdone-$SLURM_JOB_ID
#rm -f $wdir/logs/${SLURM_JOB_ID}.conf

kill SRUN_PID
kill SCHEDULER_PID
