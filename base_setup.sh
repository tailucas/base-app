#!/usr/bin/env sh
set -e

# system updates

# virtual-env updates
python -m venv /opt/app/
. /opt/app/bin/activate
# output site configuration
python -m site
# work around timeouts to www.piwheels.org
export PIP_DEFAULT_TIMEOUT=60
# add pylib dependencies
if [ -f /opt/app/pylib/requirements.txt ]; then
  python -m pip install -r "/opt/app/pylib/requirements.txt"
fi

deactivate
