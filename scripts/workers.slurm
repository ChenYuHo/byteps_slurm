#!/bin/bash 

#SBATCH --gres=gpu:1
#SBATCH --ntasks=2
#SBATCH --nodes=2
#SBATCH --mem=40G
#SBATCH --cpus-per-task=4
#SBATCH --time=00:10:00
#SBATCH --constraint=v100,gpu_ai
#SBATCH -A ibex-cs

module load openmpi/4.0.3-cuda10.2

export OMPI_MCA_btl=openib
export OMPI_MCA_btl_openib_allow_ib=1

srun -n 2 -N 2 /bin/hostname > host.list
mpirun -np 2 --hostfile ./host.list ./worker.sh

