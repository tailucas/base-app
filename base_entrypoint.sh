#!/usr/bin/env sh
set -eu
set -o pipefail

cat /opt/app/config/app.conf | /opt/app/pylib/config_interpol > "/opt/app/${APP_NAME}.conf"
cat /opt/app/config/supervisord.conf | /opt/app/pylib/config_interpol > /opt/app/supervisord.conf
# cron
cat << EOF >> /opt/app/supervisord.conf
[program:cron]
command=/usr/sbin/crond -f
autorestart=unexpected
EOF
printenv >> /opt/app/cron.env
if [ -n "${AWS_DEFAULT_REGION:-}" ]; then
  # AWS configuration (no tee for secrets)
  cat /opt/app/config/aws-config | /opt/app/pylib/config_interpol > "/home/app/.aws/config"
fi