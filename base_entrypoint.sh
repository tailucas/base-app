#!/usr/bin/env bash
set -eu
set -o pipefail

/opt/app/pylib/config_interpol < /opt/app/config/app.conf > /opt/app/app.conf
cp /opt/app/config/supervisord.conf /opt/app/supervisord.conf
# cron
cat << EOF >> /opt/app/supervisord.conf
[program:cron]
command=/usr/sbin/cron -f -L 4
autorestart=unexpected
EOF
printenv >> /opt/app/cron.env
if [ -n "${AWS_DEFAULT_REGION:-}" ]; then
  # AWS configuration (no tee for secrets)
  /opt/app/pylib/config_interpol < /opt/app/config/aws-config > /home/app/.aws/config
fi