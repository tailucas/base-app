#!/usr/bin/env sh
set -e

# system updates
curl -sSL https://install.python-poetry.org | python3 -
poetry --version

# virtual-env updates
python -m venv /opt/app/
. /opt/app/bin/activate
# output site configuration
python -m site
# work around timeouts to www.piwheels.org
export PIP_DEFAULT_TIMEOUT=60
# wheel builder
if [ -n "${PYTHON_ADD_WHEEL:-}" ]; then
  python -m pip install --upgrade pip
  python -m pip install --upgrade setuptools
  python -m pip install --upgrade wheel
fi
# add pylib dependencies
if [ -f /opt/app/pylib/requirements.txt ]; then
  python -m pip install -r "/opt/app/pylib/requirements.txt"
fi

deactivate

# cron

# non-root user
chown app:app /usr/sbin/crond
setcap cap_setgid=ep /usr/sbin/crond
