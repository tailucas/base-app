#!/usr/bin/env sh
set -u

# system updates
if [ -n "${BASE_APP_BUILD:-}" ]; then
  if ! poetry --version; then
    curl -sSL https://install.python-poetry.org | python -
  else
    poetry self update
  fi
fi
poetry install
poetry show
