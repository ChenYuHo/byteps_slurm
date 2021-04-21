#!/bin/bash

#SBATCH --time=00:10:00
#SBATCH --gres=gpu:1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=40G
#SBATCH --constraint=v100,gpu_ai
#SBATCH -A ibex-cs


#Using ib0 as interface
sleep 5
interface_addr=$(cat ./sched.addr)
export IMAGE=./byteps_latest.sif 

module load singularity

export SINGULARITYENV_DMLC_ENABLE_RDMA=ibverbs
export SINGULARITYENV_DMLC_INTERFACE=ib0
export SINGULARITYENV_DMLC_NUM_WORKER=2  
export SINGULARITYENV_DMLC_NUM_SERVER=1
export SINGULARITYENV_DMLC_PS_ROOT_URI=${interface_addr}
export SINGULARITYENV_DMLC_PS_ROOT_PORT=10010
export SINGULARITYENV_BYTEPS_ENABLE_IPC=0

#invoke server

export SINGULARITYENV_DMLC_ROLE=server
export SINGULARITYENV_BYTEPS_RDMA_RX_DEPTH=64

singularity exec -B /usr/lib64 ${IMAGE} bpslaunch


