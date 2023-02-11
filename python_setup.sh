#!/usr/bin/env sh
set -e

# system updates
poetry --version || curl -sSL https://install.python-poetry.org | python -
poetry install
poetry show
