#!/usr/bin/env bash
set -u

# system updates
if ! poetry --version; then
  curl -sSL https://install.python-poetry.org | python -
else
  poetry self update
fi

set -e
poetry install --no-interaction
poetry show --tree
poetry run python -c "import platform;import sys;print(f'{sys.version} on {platform.platform()} {platform.uname()}')"
