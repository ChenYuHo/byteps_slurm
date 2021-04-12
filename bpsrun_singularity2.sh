#!/bin/bash -l
module load singularity/3.6
IMAGE=/ibex/scratch/hoc0a/byteps_horovod.sif

[[ $OMPI_COMM_WORLD_RANK -lt $3 ]] \
    && ROLE="worker" \
    || ROLE="server"
#WID=$((${OMPI_COMM_WORLD_RANK}-${4}))
WID=$OMPI_COMM_WORLD_RANK
echo $ROLE $OMPI_COMM_WORLD_RANK $(hostname) 
export SINGULARITYENV_DMLC_ENABLE_RDMA=ibverbs
export SINGULARITYENV_DMLC_INTERFACE=ib0
export SINGULARITYENV_BYTEPS_ENABLE_IPC=0
export SINGULARITYENV_DMLC_ROLE=$ROLE
export SINGULARITYENV_DMLC_PS_ROOT_URI=$1
export SINGULARITYENV_DMLC_PS_ROOT_PORT=$2
export SINGULARITYENV_DMLC_NUM_WORKER=$3
export SINGULARITYENV_DMLC_NUM_SERVER=$4
#BYTEPS_SERVER_ENGINE_THREAD=8 BYTEPS_RDMA_START_DEPTH=32 BYTEPS_RDMA_RX_DEPTH=256
if [ "$ROLE" = "worker" ]; then
  export SINGULARITYENV_DMLC_WORKER_ID=$WID
#  module load 
  echo launching worker $WID
  singularity exec -B /ibex/scratch/hoc0a/e2e-exps/byteps --nv ${IMAGE} bpslaunch $5
else
  echo launching server
  singularity exec ${IMAGE} bpslaunch
fi
#R=$?
if [ "$ROLE" = "worker" ] && [ "$WID" = "0" ]; then
  echo worker 0 done
  touch "$HOME/iamdone-$SLURM_JOB_ID"
fi
