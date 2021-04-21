#!/bin/bash
./clean.sh

sbatch sched.slurm
sbatch server.slurm
sbatch workers.slurm
