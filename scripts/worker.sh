#!/bin/bash -l
sleep 5
module load singularity
interface_addr=$(cat ./sched.addr)
export IMAGE=./byteps_latest.sif 
export SINGULARITYENV_DMLC_ENABLE_RDMA=ibverbs
export SINGULARITYENV_DMLC_INTERFACE=ib0
export SINGULARITYENV_DMLC_NUM_WORKER=2 
export SINGULARITYENV_DMLC_NUM_SERVER=1
export SINGULARITYENV_DMLC_PS_ROOT_URI=${interface_addr}
export SINGULARITYENV_DMLC_PS_ROOT_PORT=10010
export SINGULARITYENV_BYTEPS_ENABLE_IPC=0
#export SINGULARITYENV_BYTEPS_LOG_LEVEL=INFO
#export SINGULARITYENV_PS_VERBOSE=2
#export SINGULARITYENV_BYTEPS_FORCE_DISTRIBUTED=1
#export SINGULARITYENV_DISTRIBUTED_FRAMEWORK=byteps
export SINGULARITYENV_DMLC_WORKER_ID=${OMPI_COMM_WORLD_RANK}
export SINGULARITYENV_BYTEPS_RDMA_RX_DEPTH=64
# invoke worker
export SINGULARITYENV_DMLC_ROLE=worker


mkdir -p logs/${SLURM_JOBID}
singularity exec -B /usr/lib64 --nv ${IMAGE} bpslaunch python ./benchmark.py --num-iters 10 --batch-size 32 &> logs/${SLURM_JOBID}/worker${OMPI_COMM_WORLD_RANK}.log &
wait %1
