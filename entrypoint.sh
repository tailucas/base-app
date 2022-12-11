#!/bin/bash
set -eu
set -o pipefail

cat /opt/app/config/app.conf | /opt/app/pylib/config_interpol > "/opt/app/${APP_NAME}.conf"
export APP_USER="${APP_USER:-app}"
cat /opt/app/config/supervisord.conf | /opt/app/pylib/config_interpol > /opt/app/supervisord.conf

# replace this entrypoint with process manager
exec env supervisord -n -c /opt/app/supervisord.conf