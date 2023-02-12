#!/usr/bin/env sh
set -eu
set -o pipefail

/opt/app/pylib/config_interpol < /opt/app/config/app.conf > /opt/app/app.conf
cp /opt/app/config/supervisord.conf /opt/app/supervisord.conf
# cron
cat << EOF >> /opt/app/supervisord.conf
[program:cron]
command=/usr/sbin/crond -f -l 8
autorestart=unexpected
EOF
if [ -n "${AWS_DEFAULT_REGION:-}" ]; then
  # AWS configuration (no tee for secrets)
  /opt/app/pylib/config_interpol < /opt/app/config/aws-config > /home/app/.aws/config
fi