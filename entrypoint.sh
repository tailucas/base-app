#!/bin/bash
set -eu
set -o pipefail

cat /opt/app/config/app.conf | /opt/app/pylib/config_interpol > "/opt/app/${APP_NAME}.conf"
cat /opt/app/config/Procfile | sed "s~__APP_NAME__~${APP_NAME}~g" > /opt/app/Procfile
# replace this entrypoint with process manager
exec env hivemind