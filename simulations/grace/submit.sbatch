#!/bin/bash
#SBATCH --job-name=clima
#SBATCH --ntasks=1
#SBATCH --time=1:00:00
#SBATCH --account eisaman
#SBATCH --nodes 1
#SBATCH --mem 10G
#SBATCH --partition gpu_devel
#SBATCH --gpus=a100:1

module purge
module load miniconda/24.9.2 
module load Julia/1.11.3-linux-x86_64

# this is where all the forcing and environment files will be downloaded to
export JULIA_DEPOT_PATH=/home/ljg48/project/oceananigans/scratch

# to setup an .env file so you don't accidently expose ECCO username and password
# haven't setup or tested this yet
#set -a  
#source /home/ljg48/project/oceananigans/.env  
#set +a 

export ECCO_USERNAME=username
export ECCO_PASSWORD=password

# should only have to run this once
#julia --project=/home/ljg48/project/oceananigans -e "using Pkg; Pkg.instantiate()"

julia --project=/home/ljg48/project/oceananigans ./salish-sea-tracer-release-coupled.jl
