#!/usr/bin/env bash
set -e
set -o pipefail

# system updates

# Rust for cryptography wheel
curl https://sh.rustup.rs -sSf | sh -s -- -y
# Add rustc to PATH
source $HOME/.cargo/env

# virtual-env updates

python -m venv --system-site-packages /opt/app/
. /opt/app/bin/activate
# work around timeouts to www.piwheels.org
export PIP_DEFAULT_TIMEOUT=60
python -m pip install --upgrade pip
python -m pip install --upgrade setuptools
python -m pip install --upgrade wheel
# add pylib dependencies
if [ -f /opt/app/pylib/requirements.txt ]; then
  python -m pip install --upgrade -r "/opt/app/pylib/requirements.txt"
fi

deactivate
