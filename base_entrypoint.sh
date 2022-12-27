#!/bin/bash
set -eu
set -o pipefail

cat /opt/app/config/app.conf | /opt/app/pylib/config_interpol > "/opt/app/${APP_NAME}.conf"
export APP_USER="${APP_USER:-app}"
cat /opt/app/config/supervisord.conf | /opt/app/pylib/config_interpol > /opt/app/supervisord.conf

# host heartbeat
if [ -n "${HC_PING_URL:-}" ]; then
  echo "Installing heartbeat to ${HC_PING_URL}"
  cp /opt/app/config/healthchecks_heartbeat /etc/cron.d/healthchecks_heartbeat
  cat << EOF >> /opt/app/supervisord.conf
[program:cron]
command=/usr/sbin/cron -f
autorestart=unexpected
EOF
fi
