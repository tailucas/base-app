#!/usr/bin/env bash
set -eu
set -o pipefail

/opt/app/config_interpol < /opt/app/config/app.conf > /opt/app/app.conf
cp /opt/app/config/supervisord.conf /opt/app/supervisord.conf
# cron
cat << EOF >> /opt/app/supervisord.conf
[program:cron]
command=/usr/sbin/cron -f -L 4
autorestart=unexpected
EOF
printenv | sed 's/=\(.*\)/="\1"/' >> /opt/app/cron.env
if [ -n "${AWS_DEFAULT_REGION:-}" ]; then
  # AWS configuration (no tee for secrets)
  /opt/app/config_interpol < /opt/app/config/aws-config > /home/app/.aws/config
fi

# override Python application
if [ "${NO_PYTHON_APP:-}" != "true" ]; then
  cat << EOF >> /opt/app/supervisord.conf
[program:app]
priority=1
command=poetry run app
directory=/opt/app/
user=app
autorestart=unexpected
stdout_syslog=true
stderr_syslog=true
EOF
fi

# add optional Java application
if [ "${RUN_JAVA_APP:-}" == "true" ]; then
  cat << EOF >> /opt/app/supervisord.conf
[program:japp]
priority=2
command=java -jar app.jar
directory=/opt/app/
user=app
autorestart=unexpected
stdout_syslog=true
stderr_syslog=true
EOF
fi
