#!/usr/bin/env sh
set -u

# system updates
if ! poetry --version; then
  curl -sSL https://install.python-poetry.org | python -
else
  poetry self update
fi
poetry install
poetry show
