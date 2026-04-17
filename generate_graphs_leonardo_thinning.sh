#!/bin/bash
#SBATCH --job-name=generate-graphs
#SBATCH --output=logs/generate_graphs.out
#SBATCH --error=logs/generate_graphs.err

########## RESOURCE REQUESTS ##########
#SBATCH --nodes=1                     # Example: M=4 nodes
#SBATCH --ntasks-per-node=4           # 4 tasks per node
#SBATCH --gpus-per-node=4             # 4 GPUs per node
#SBATCH --gpus-per-task=1             # 1 GPU per array task
#SBATCH --cpus-per-task=8
#SBATCH --mem=0
#SBATCH --account=DestE_340_26
#SBATCH --partition=boost_usr_prod
#SBATCH --qos=boost_qos_dbg
#SBATCH --time=00:30:00


########## ARRAY JOB ##########
##SBATCH --array=0-73               # 73 graph configs

########## OPTIONAL ##########
#SBATCH --exclusive
#SBATCH --switches=1


########################################
#        SET PATHS
########################################
DATASETS_TXT=/leonardo_work/DestE_340_26/users/sbuurman/multi-domain-training/anemoi-core/test_hectometric/hectometric_validation.txt #INSERT .txt files with all dataset paths
DATASET_BASE_FOLDER=/leonardo_work/DestE_330_25/anemoi/datasets/DEODE # Base folder for all datasets, will be injected into config
TMP_CONFIG_DIR=/leonardo_work/DestE_340_26/users/sbuurman/auto-graphs/config # Base folder for temporary configs, will be injected into config
BASE_CONFIG=/leonardo_work/DestE_340_26/users/sbuurman/auto-graphs/config/hectometric_thinning_leonardo.yaml # Base config to copy from, should have placeholders null for dataset paths
OUTPUT_PATH=/leonardo_work/DestE_340_26/users/sbuurman/graphs/hectometric/res7_10_validation/ # Base output path for output graphs, will be injected into config

########################################
#        ENVIRONMENT SETUP
########################################

module load gcc/12.2.0

export PYTHON_HOME=/leonardo_work/DestE_330_25/users/asalihi0/compiled-libraries/python/python-3.11.7-gcc-12.2.0-cmake-3.27.9
export SQLITE3_HOME=/leonardo_work/DestE_330_25/users/asalihi0/compiled-libraries/python/sqlite-3.45-gcc-12.2.0

export PATH=$PYTHON_HOME/bin:$SQLITE3_HOME/bin:$PATH
export LD_LIBRARY_PATH=$PYTHON_HOME/lib:$SQLITE3_HOME/lib:$LD_LIBRARY_PATH

# REPLACE WITH YOUR OWN VIRTUAL ENVIRONMENT, CONTAINING ANEMOI-CORE FROM https://github.com/destination-earth-digital-twins/anemoi-core/tree/feature/hectometric
VENV=/leonardo_work/DestE_340_26/users/sbuurman/multi-domain-training/temp-torch-2.6.0-cu124 #.venv
source $VENV/bin/activate
export VIRTUAL_ENV=$VENV
export PYTHONUSERBASE=$VIRTUAL_ENV
export PATH=$PATH:$VIRTUAL_ENV/bin

IDX=${SLURM_ARRAY_TASK_ID}
# Take the (IDX+1)-th line from paths.txt — this is JUST the path, not a tuple
DATASET_NAME=$(sed -n "$((IDX+1))p" ${DATASETS_TXT})

########################################
#     LOG START + HARDWARE INFO
########################################

echo "------------------------------------------------------------"
echo "Task $SLURM_ARRAY_TASK_ID starting"
echo "Node:        $(hostname)"
echo "GPU:         $CUDA_VISIBLE_DEVICES"
echo "Start time:  $(date)"
echo "Graph path:  $GRAPH_PATH"
echo "------------------------------------------------------------"

########################################
#        RUN PYTHON WITH INJECTED PATH
########################################

# Inject path from paths.txt into config.yaml WITHOUT modifying the file
TMP_CONFIG=$(mktemp --tmpdir=$TMP_CONFIG_DIR config_XXXX.yaml)
echo $TMP_CONFIG
DATA_DIR=${DATASET_BASE_FOLDER}/${DATASET_NAME}
echo DATA_DIR: $DATA_DIR
if [[ $DATASET_NAME == *"v2.zarr" ]]; then
    ITEM=$(ls -1 $DATA_DIR | head -n 1)
    FULL_DATA_PATH=${DATA_DIR}/${ITEM}
else
    FULL_DATA_PATH=$DATA_DIR
fi
echo $DATA_DIR
echo $ITEM
echo $FULL_DATA_PATH
if [[ $DATASET_NAME == *"v2.zarr" ]]; then
    sed -e 's|drop: \[cp, q_250, q_50, q_600, sdor, slor, stl1, swvl1, t_250, t_50, t_600, tcw, u_250, u_50, u_600, v_250, v_50, v_600, w_250, w_50, w_600, z_250, z_50, z_600\]|drop: [cp, q_250, q_50, q_600, sdor, slor, stl1, swvl1, t_250, t_50, t_600, tcw, u_250, u_50, u_600, v_250, v_50, v_600, w_250, w_50, w_600, z_250, z_50, z_600, 100u, 100v]|' \
        -e "s|hectometric_dataset_training: null|hectometric_dataset_training: ${FULL_DATA_PATH}|" \
        -e "s|hectometric_dataset_validation: null|hectometric_dataset_validation: ${FULL_DATA_PATH}|" \
        -e "s|graph: null|graph: ${OUTPUT_PATH}|" $BASE_CONFIG > $TMP_CONFIG 
else
    sed -e "s|hectometric_dataset_training: null|hectometric_dataset_training: ${FULL_DATA_PATH}|" -e "s|hectometric_dataset_validation: null|hectometric_dataset_validation: ${FULL_DATA_PATH}|" -e "s|graph: null|graph: ${OUTPUT_PATH}|" $BASE_CONFIG > $TMP_CONFIG
fi
echo "Temporary config created at: $TMP_CONFIG"
python3 generate_graphs.py   --config-name "$(basename "$TMP_CONFIG" .yaml)" --config-path $(dirname ${TMP_CONFIG})


########################################
#              FINISHED
########################################

echo "------------------------------------------------------------"
echo "Task $SLURM_ARRAY_TASK_ID finished"
# trap "rm -f ${TMP_CONFIG}" EXIT
echo "End time: $(date)"
echo "------------------------------------------------------------"
