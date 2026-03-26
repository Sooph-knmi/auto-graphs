from process_configs import ProcessConfigs
from graph_setup import graph_setup
import hydra
from omegaconf import DictConfig
from omegaconf import OmegaConf
from base_schema import UnvalidatedBaseSchema
import logging


# CHANGE CONFIG PATH TO THE BASE CONFIG PATH OF THE hectometric_finetuning.yaml CONFIG
@hydra.main(version_base=None, config_path="/leonardo_work/DestE_330_25/users/sbuurman/multi-domain-training/anemoi-core/training/src/anemoi/training/config/", config_name="hectometric_finetuning.yaml")
def main(config: DictConfig) -> None:
    print("Received config:")
    print(OmegaConf.to_yaml(config))
    logging.basicConfig(level=logging.DEBUG, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
    pc = ProcessConfigs(base_config=config, hectometric=True)
    pc.process
    config=pc.update()
    config = OmegaConf.to_object(config)
    config = UnvalidatedBaseSchema(**DictConfig(config))
    graph_setup(config, dynamic_mode=True)


if __name__ == "__main__":
    main()
