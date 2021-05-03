#!/bin/bash -l
module load singularity/3.6
export IMAGE=/ibex/scratch/hoc0a/e2e-exps/byteps/byteps_slurm/scripts/byteps_latest.sif

[[ -z "$5" ]] \
    && ROLE="server" \
    || ROLE="worker"
WID=$OMPI_COMM_WORLD_RANK
echo $(hostname) is $ROLE rank $OMPI_COMM_WORLD_RANK
export SINGULARITYENV_DMLC_ENABLE_RDMA=ibverbs
export SINGULARITYENV_DMLC_INTERFACE=ib0
export SINGULARITYENV_BYTEPS_ENABLE_IPC=0
export SINGULARITYENV_DMLC_ROLE=$ROLE
export SINGULARITYENV_DMLC_PS_ROOT_URI=$1
export SINGULARITYENV_DMLC_PS_ROOT_PORT=$2
export SINGULARITYENV_DMLC_NUM_WORKER=$3
export SINGULARITYENV_DMLC_NUM_SERVER=$4
export SINGULARITYENV_BYTEPS_RDMA_RX_DEPTH=64
#BYTEPS_SERVER_ENGINE_THREAD=8 BYTEPS_RDMA_START_DEPTH=32 BYTEPS_RDMA_RX_DEPTH=256
if [ "$ROLE" = "worker" ]; then
  export SINGULARITYENV_DMLC_WORKER_ID=$WID
  module load openmpi/4.0.3-cuda10.1
  echo launching worker $WID
  singularity exec -B /usr/lib64 -B /ibex/scratch/hoc0a/e2e-exps/byteps/byteps_slurm --nv ${IMAGE} bpslaunch $5
else
  echo launching server
  singularity exec -B /usr/lib64 ${IMAGE} bpslaunch
fi
