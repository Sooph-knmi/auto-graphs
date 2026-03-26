#!/bin/bash
set -euo pipefail

ROOT="$(pwd -P)"
VENV="$ROOT/.venv-graphs"

echo "ROOT=$ROOT"
echo "VENV=$VENV"

# Create a real virtual environment if missing
if [ ! -f "$VENV/bin/python" ]; then
    python3 -m venv "$VENV"
fi

# Activate it, or better: call its python explicitly
source "$VENV/bin/activate"

# Make sure pip/setuptools are available in the venv
python3 -m pip install --upgrade pip setuptools wheel

# Optional: avoid confusion; this is not needed for a venv workflow
unset PYTHONUSERBASE

echo "Using python: $(which python)"
echo "Using pip:    $(which pip)"
python3 --version

if [ ! -d anemoi-core ]; then
    echo "Cloning anemoi-core from ECMWF"
    git clone https://github.com/ecmwf/anemoi-core.git
fi
python3 -m pip install --no-deps -e anemoi-core/graphs

if [ ! -d anemoi-utils ]; then
    echo "Cloning anemoi-utils from ECMWF"
    git clone https://github.com/ecmwf/anemoi-utils.git
fi
python3 -m pip install --no-deps -e anemoi-utils

if [ ! -d anemoi-datasets ]; then
    echo "Cloning anemoi-datasets from ECMWF"
    git clone https://github.com/ecmwf/anemoi-datasets.git
fi
python3 -m pip install --no-deps -e anemoi-datasets

if [ ! -d anemoi-transform ]; then
    echo "Cloning anemoi-transform from ECMWF"
    git clone https://github.com/ecmwf/anemoi-transform.git
fi
python3 -m pip install --no-deps -e anemoi-transform
