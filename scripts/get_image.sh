#!/bin/bash
module load singularity
export SINGULARITY_TMPDIR=$HOME
export XDG_RUNTIME_DIR=$HOME

DEST_DIR=$PWD
cd $HOME
singularity pull docker://mshaikh/byteps:latest
mv byteps_latest.sif $PWD
