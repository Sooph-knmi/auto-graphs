# (C) Copyright 2024- ECMWF.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
# In applying this licence, ECMWF does not waive the privileges and immunities
# granted to it by virtue of its status as an intergovernmental organisation
# nor does it submit to any jurisdiction.
#


import logging
import sys
from typing import Any

from omegaconf import DictConfig
from omegaconf import OmegaConf
from pydantic import BaseModel as PydanticBaseModel
from pydantic import model_validator
from pydantic._internal import _model_construction
from pydantic_core import PydanticCustomError
from pydantic_core import ValidationError
from typing_extensions import Self


class UnvalidatedBaseSchema(PydanticBaseModel):
    dataloader: Any
    """Dataloader configuration."""
    hardware: Any
    """Hardware configuration."""
    graph: Any
    """Graph configuration."""
    config_validation: bool = False
    """Flag to disable validation of the configuration"""

    def model_dump(self, by_alias: bool = False) -> dict:
        dumped_model = super().model_dump(by_alias=by_alias)
        return DictConfig(dumped_model)

def convert_to_omegaconf(config) -> dict:
    config = config.model_dump(by_alias=True)
    return OmegaConf.create(config)