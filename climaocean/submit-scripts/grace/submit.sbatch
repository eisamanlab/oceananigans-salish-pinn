#!/bin/bash
#SBATCH --job-name=clima
#SBATCH --ntasks=1
#SBATCH --time=3:00:00
#SBATCH --account eisaman
#SBATCH --nodes 1
#SBATCH --mem 10G
#SBATCH --partition gpu
#SBATCH --gpus=a100:1

module purge
module load miniconda/24.9.2 
module load Julia/1.11.3-linux-x86_64

###---------------------------------------------------------
### if true, this will instantiste the project
### set to true only if the project is not instantiated yet
### this will only need to be done once
###---------------------------------------------------------

INSTANTIATE=true

###---------------------------------------------------------
### path to simulation you want to run
###---------------------------------------------------------

SIMULATION=/home/${USER}/palmer_scratch/climaocean/init-after-spinup.jl 

###---------------------------------------------------------
### this is path where where Project.toml is
### note: do not put Project.toml at end of the path
###---------------------------------------------------------

PROJECT=/home/${USER}/palmer_scratch/climaocean

###---------------------------------------------------------
### this is where all downloaded file will live
### will make scratch directory if does not already exist
###---------------------------------------------------------

DEPOT_PATH=/home/${USER}/palmer_scratch/climaocean/scratch
mkdir -p ${DEPOT_PATH}

export JULIA_DEPOT_PATH=${DEPOT_PATH}

###-------------------------------------------
### this contains ECCO credentials
### your ~/.ecco-credentials 
### should contain only these two lines:
###
### export ECCO_USERNAME=your-username
### export ECCO_PASSWORD=your-password
###-------------------------------------------

source /home/${USER}/.ecco-drive  

###-------------------------------------------
### instantiates packages
### should only have to run this once
###-------------------------------------------

if ${INSTANTIATE}; then
    julia --project="${PROJECT}" -e "using Pkg; Pkg.instantiate()"
fi

wait

###-------------------------------------------
### runs the actual simulation
###-------------------------------------------

julia --project=${PROJECT} ${SIMULATION}

