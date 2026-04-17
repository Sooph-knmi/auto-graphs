#!/bin/bash

cd $(pwd -P)

# Make files executable in the container (might not be needed)
chmod 770 base.sh

PROJECT_DIR=/pfs/lustrep4/scratch/project_465000527


singularity exec -B /pfs:/pfs $CONTAINER $(pwd -P)/base.sh

