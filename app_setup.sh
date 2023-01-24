#!/usr/bin/env sh
set -e
set -o pipefail

. /opt/app/bin/activate
# output site configuration
python -m site
export PIP_DEFAULT_TIMEOUT=60
#python -m pip install --upgrade pip
#python -m pip install --upgrade setuptools
#python -m pip install --upgrade wheel
python -m pip install -r "/opt/app/requirements.txt"

deactivate
