#!/bin/bash
module load singularity/3.6
TMPDIR=$HOME
export SINGULARITY_TMPDIR=$TMPDIR
export XDG_RUNTIME_DIR=$TMPDIR

DEST_DIR=$PWD
cd $TMPDIR
singularity pull docker://mshaikh/byteps:latest
mv byteps_latest.sif $DEST_DIR/byteps.sif
