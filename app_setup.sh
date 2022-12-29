#!/usr/bin/env bash
set -e
set -o pipefail

. /opt/app/bin/activate
# output site configuration
python -m site
export PIP_DEFAULT_TIMEOUT=60
python -m pip install --upgrade -r "/opt/app/requirements.txt"

deactivate
