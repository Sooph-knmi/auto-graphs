#!/bin/bash

cd $(pwd -P)

# Make files executable in the container (might not be needed)
chmod 770 base.sh

PROJECT_DIR=/pfs/lustrep4/scratch/project_465000527
CONTAINER=/pfs/lustrep4/scratch/project_465000527/salihiar/container/FMI/container/pytorch-2.9.1-rocm-6.4.4-py-3.12.3-v1.0.sif
# Clone and pip install anemoi repos from the container
module purge
module use /appl/local/laifs/modules
module load lumi-aif-singularity-bindings

singularity exec -B /pfs:/pfs $CONTAINER $(pwd -P)/base.sh

