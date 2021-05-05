#!/bin/bash -l
set -x
module load singularity/3.6
# https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
IMAGE=$SCRIPTDIR/byteps.sif
WORKER_COMMAND=${5:-"python ${SCRIPTDIR}/bps_microbenchmark.py -t 26214400 -b 256 -d 0.5"}
echo $(hostname) is $ROLE rank $OMPI_COMM_WORLD_RANK
export SINGULARITYENV_DMLC_ENABLE_RDMA=ibverbs
export SINGULARITYENV_DMLC_INTERFACE=ib0
export SINGULARITYENV_BYTEPS_ENABLE_IPC=0
export SINGULARITYENV_DMLC_PS_ROOT_URI=$1
export SINGULARITYENV_DMLC_PS_ROOT_PORT=$2
export SINGULARITYENV_DMLC_NUM_WORKER=$3
export SINGULARITYENV_DMLC_NUM_SERVER=$4
export SINGULARITYENV_BYTEPS_RDMA_RX_DEPTH=64
export SINGULARITYENV_BYTEPS_SERVER_ENGINE_THREAD=8
#export SINGULARITYENV_BYTEPS_LOG_LEVEL=INFO
#export SINGULARITYENV_PS_VERBOSE=2
#export SINGULARITYENV_BYTEPS_FORCE_DISTRIBUTED=1
#export SINGULARITYENV_DISTRIBUTED_FRAMEWORK=byteps
export SINGULARITYENV_DMLC_ROLE=server
singularity exec -B /usr/lib64 ${IMAGE} bpslaunch &
SERVER_PID=$!
export SINGULARITYENV_DMLC_ROLE=worker
export SINGULARITYENV_DMLC_WORKER_ID=$OMPI_COMM_WORLD_RANK
module load openmpi/4.0.3-cuda10.1
singularity exec -B /usr/lib64 -B $SCRIPTDIR --nv ${IMAGE} bpslaunch $WORKER_COMMAND
kill $SERVER_PID
