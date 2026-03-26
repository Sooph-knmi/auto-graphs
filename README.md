# auto-graphs
Collection of Anemoi repositories and scripts used to automatically generate graphs

## Getting started
On LUMI: 
To setup the environment, run 

```
bash create_environment.sh
```

Then, to generate the graphs
1. Change the graph and dataset config in the `config` folder
2. Modify the paths in the `generate_graphs.sh` scipt 
    - DATASETS_TXT: a .txt file with the names of the datasets of which to generate the graphs from
    - DATASET_BASE_FOLDER: the folder where these datasets reside
    - TMP_CONFIG_DIR: where to store the temporarily generated configs
    - BASE_CONFIG: the path to the modified config in the config folder (example: `hectometric_finetuning`.yaml)
    - OUTPUT_PATH: where to store the generated graphs
3. Finally, run `sbatch generate_graphs.sh` which will schedule parallel array jobs for each graph

