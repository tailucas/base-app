#!/bin/bash
set -eu
set -o pipefail

cat /opt/app/config/app.conf | /opt/app/pylib/config_interpol > "/opt/app/${APP_NAME}.conf"
export APP_USER="${APP_USER:-app}"
cat /opt/app/config/supervisord.conf | /opt/app/pylib/config_interpol > /opt/app/supervisord.conf
# cron
cat << EOF >> /opt/app/supervisord.conf
[program:cron]
command=/usr/sbin/cron -f
autorestart=unexpected
EOF
printenv >> /opt/app/cron.env
