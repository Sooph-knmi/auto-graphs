#!/bin/bash
#SBATCH --job-name=generate-graphs
#SBATCH --output=logs/generate_graphs.out
#SBATCH --error=logs/generate_graphs.err

########## RESOURCE REQUESTS ##########
#SBATCH --nodes=1                     # Example: M=4 nodes
#SBATCH --ntasks-per-node=4           # 4 tasks per node
#SBATCH --cpus-per-task=8
#SBATCH --mem=0
#SBATCH --partition=dev-g
#SBATCH --gpus-per-node=8
#SBATCH --account=project_465000527
#SBATCH --time=02:00:00


########## ARRAY JOB ##########
##SBATCH --array=0-600               # 252 graph configs

########## OPTIONAL ##########
#SBATCH --exclusive
#SBATCH --switches=1

########################################
#        ENVIRONMENT SETUP
########################################

module load gcc/12.2.0

export PYTHON_HOME=/leonardo_work/DestE_330_25/users/asalihi0/compiled-libraries/python/python-3.11.7-gcc-12.2.0-cmake-3.27.9
export SQLITE3_HOME=/leonardo_work/DestE_330_25/users/asalihi0/compiled-libraries/python/sqlite-3.45-gcc-12.2.0

export PATH=$PYTHON_HOME/bin:$SQLITE3_HOME/bin:$PATH
export LD_LIBRARY_PATH=$PYTHON_HOME/lib:$SQLITE3_HOME/lib:$LD_LIBRARY_PATH

# REPLACE WITH YOUR OWN VIRTUAL ENVIRONMENT, CONTAINING ANEMOI-CORE FROM https://github.com/destination-earth-digital-twins/anemoi-core/tree/feature/hectometric
CONTAINER=/pfs/lustrep4/scratch/project_465000527/anemoi/containers/pytorch-2.7.0-rocm-6.2.4-py-3.12.9-v2.0.sif
VENV=$(pwd -P)/.venv-graphs #.venv
source $VENV/bin/activate
export VIRTUAL_ENV=$VENV
export PYTHONUSERBASE=$VIRTUAL_ENV
export PATH=$PATH:$VIRTUAL_ENV/bin

########################################
#        SET PATHS
########################################
DATASETS_TXT=/pfs/lustrep4/scratch/project_465000527/buurmans/DE_330_WP14/Anemoi/multi-domain-hectometric/auto-graphs/txt_hectometric/hectometric_validation.txt #INSERT .txt files with all dataset paths
DATASET_BASE_FOLDER=/pfs/lustrep4/scratch/project_465000527/dschonac/DE330_ARCHIVE/zarr # Base folder for all datasets, will be injected into config
TMP_CONFIG_DIR=/pfs/lustrep4/scratch/project_465000527/buurmans/DE_330_WP14/Anemoi/multi-domain-hectometric/auto-graphs/config # Base folder for temporary configs, will be injected into config
BASE_CONFIG=/pfs/lustrep4/scratch/project_465000527/buurmans/DE_330_WP14/Anemoi/multi-domain-hectometric/auto-graphs/config/hectometric_finetuning.yaml # Base config to copy from, should have placeholders null for dataset paths
OUTPUT_PATH=/pfs/lustrep4/scratch/project_465000527/buurmans/DE_330_WP14/Anemoi/graphs/hectometric_7_12_minus11 # Base output path for output graphs, will be injected into config

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
# if [[ $DATASET_NAME == *"v2.zarr" ]]; then
#     ITEM=$(ls -1 $DATA_DIR | head -n 1)
#     FULL_DATA_PATH=${DATA_DIR}/${ITEM}
# else
FULL_DATA_PATH=$DATA_DIR
# fi
echo $DATA_DIR
echo $ITEM
echo $FULL_DATA_PATH
sed -e "s|hectometric_dataset_training: null|hectometric_dataset_training: ${FULL_DATA_PATH}|" -e "s|hectometric_dataset_validation: null|hectometric_dataset_validation: ${FULL_DATA_PATH}|" -e "s|graph: null|graph: ${OUTPUT_PATH}|" $BASE_CONFIG > $TMP_CONFIG 

module purge
module load LUMI/25.03 partition/G
module use /appl/local/laifs/modules
module load lumi-aif-singularity-bindings


# run run-pytorch.sh in singularity container like recommended
# in LUMI doc: https://lumi-supercomputer.github.io/LUMI-EasyBuild-docs/p/PyTorch
# Printing GPU information to terminal once
if [ $SLURM_LOCALID -eq 0 ] ; then
    rocm-smi --showtoponuma
fi
sleep 2
# !Remove this if using an image extended with cotainr or a container from elsewhere.!
# Start conda environment inside the container
#$WITH_CONDA

# MIOPEN needs some initialisation for the cache as the default location
# does not work on LUMI as Lustre does not provide the necessary features.
export MIOPEN_USER_DB_PATH="/tmp/$(whoami)-miopen-cache-$SLURM_NODEID"
export MIOPEN_CUSTOM_CACHE_DIR=$MIOPEN_USER_DB_PATH

# The OMP_NUM_THREADS environment variable sets the number of 
# threads to use for parallel regions by setting the 
# initial value of the nthreads-var ICV.
export OMP_NUM_THREADS=6

# Enables MPI to communicate with GPU
export MPICH_GPU_SUPPORT_ENABLED=1

if [ $SLURM_LOCALID -eq 0 ] ; then
    rm -rf $MIOPEN_USER_DB_PATH
    mkdir -p $MIOPEN_USER_DB_PATH
fi
sleep 2


# For ROCM AITER (AI tensor engine for ROCM) to work properly..
# Create job-unique temp dir
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export AITER_JIT_DIR="/tmp/aiter_jit_${SLURM_JOBID}_${SLURM_LOCALID}"
mkdir -p "$AITER_JIT_DIR/build"

# Cleanup on trappable exits
cleanup() {
    [[ -n "$AITER_JIT_DIR" && -d "$AITER_JIT_DIR" ]] && rm -rf -- "$AITER_JIT_DIR"
}
trap cleanup EXIT SIGINT SIGTERM SIGHUP SIGQUIT

# Required for AITER
export CC=clang
export CXX=clang++

# Intel libfabric essential for aws-ofi-rccl
# change cache monitoring method:
export FI_MR_CACHE_MONITOR=memhooks

export NCCL_DEBUG=DEBUG #INFO #TRACE more detailed LOGS
#export NCCL_DEBUG_SUBSYS=INIT,COLL

# Peer-to-peer communication i.e GPU-to-GPU communication
export NCCL_P2P_DISABLE=0

# Make NCCL use non-default connection.
# This utilizes the interconnect between the
# nodes and gpus. hsn0, hsn1, hsn2, hsn3 enables
# HPE Cray Slingshot-11 with 200Gbp network interconnect
export NCCL_SOCKET_IFNAME=hsn0,hsn1,hsn2,hsn3

# This ariable allows the user to finely control 
# when to use GPU Direct RDMA between a NIC and a GPU. 
# The level defines the maximum distance between the NIC and the GPU. 
# A string representing the path type should be 
# used to specify the topographical cutoff for GpuDirect.
export NCCL_NET_GDR_LEVEL=3 #SYS #COL

# The NCCL_BUFFSIZE variable controls the size of the 
# buffer used by NCCL when communicating data between pairs of GPUs.
export NCCL_BUFFSIZE=67108864 # 64mb buffsize


# Increasing the number of CUDA CTAs 
# per peer from 1 to 4 in NCCL send/recv operations 
# may/can improve performance in sparse communication patterns 
# set NCCL_NCHANNELS_PER_NET_PEER=4. Makes communication between
# more stable.
export NCCL_NCHANNELS_PER_NET_PEER=4

# Use CUDA cuMem* functions to allocate memory in NCCL.
export NCCL_CUMEM_ENABLE=1

# COMMENT: NCCL_NCHANNELS_PER_NET_PEER and NCCL_CUMEM_ENABLE
# only works for NCCL 2.18.3 and above


# Report affinity to check
echo "Rank $SLURM_PROCID --> $(taskset -p $$); GPU $ROCR_VISIBLE_DEVICES"


get_master_node() {
    # Get the first item in the node list
    first_nodelist=$(echo $SLURM_NODELIST | cut -d',' -f1)

    if [[ "$first_nodelist" == *'['* ]]; then
        # Split the node list and extract the master node
        base_name=$(echo "$first_nodelist" | cut -d'[' -f1)
        range_part=$(echo "$first_nodelist" | cut -d'[' -f2 | cut -d'-' -f1)
        master_node="${base_name}${range_part}"
    else
        # If no range, the first node is the master node
        master_node="$first_nodelist"
    fi

    echo "$master_node"
}

# Pytorch (and lightning) setup 
# for distributed training
export MASTER_ADDR=$(get_master_node)
export MASTER_PORT=29500
export WORLD_SIZE=$SLURM_NPROCS
export RANK=$SLURM_PROCID

#export HIPBLASLT_DISABLE_TUNING=1
#export NVTE_USE_HIPBLASLT=0

export HSA_FORCE_FINE_GRAIN_PCIE=1
export HYDRA_FULL_ERROR=1
export AIFS_BASE_SEED=1337420

export PYTHONUSERBASE=$VIRTUAL_ENV
export PATH=$PATH:$VIRTUAL_ENV/bin

export AMD_SERIALIZE_KERNEL=3
export TORCH_USE_HIP_DSA=True

srun singularity exec $CONTAINER python3 generate_graphs.py --config-name $(basename $TMP_CONFIG) --config-path $(dirname $TMP_CONFIG)




########################################
#              FINISHED
########################################

echo "------------------------------------------------------------"
echo "Task $SLURM_ARRAY_TASK_ID finished"
trap "rm -f $TMP_CONFIG" EXIT
echo "End time: $(date)"
echo "------------------------------------------------------------"
