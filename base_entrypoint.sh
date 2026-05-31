#!/usr/bin/env bash
set -eu
set -o pipefail

if [ -f /opt/app/config/app.conf ]; then
  uv run config_interpol < /opt/app/config/app.conf > /opt/app/app.conf
fi
cp /opt/app/config/supervisord.conf /opt/app/supervisord.conf

if [ "${NO_CRON:-}" != "true" ]; then
  # cron
  cat << EOF >> /opt/app/supervisord.conf
[program:cron]
command=/usr/sbin/cron -f -L 4
autorestart=unexpected
EOF
fi
printenv | sed 's/=\(.*\)/="\1"/' >> /opt/app/cron.env

# set AWS config
if [ -n "${AWS_DEFAULT_REGION:-}" ]; then
  # AWS configuration (no tee for secrets)
  uv run config_interpol < /opt/app/config/aws-config > /home/app/.aws/config
fi

# override Python application
if [ "${NO_PYTHON_APP:-}" != "true" ]; then
  cat << EOF >> /opt/app/supervisord.conf
[program:app]
priority=1
command=uv run app
directory=/opt/app/
user=app
autorestart=unexpected
stopwaitsecs=30
stdout_events_enabled=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_events_enabled=true
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
redirect_stderr=false
EOF
fi

# add optional Rust application
if [ "${RUN_RUST_APP:-}" == "true" ]; then
  cat << EOF >> /opt/app/supervisord.conf
[program:rapp]
priority=2
command=cargo run --release
directory=/opt/app/
user=app
autorestart=unexpected
stopwaitsecs=30
startsecs=0
stdout_events_enabled=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_events_enabled=true
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
redirect_stderr=false
EOF
fi

# add optional Java application
if [ "${RUN_JAVA_APP:-}" == "true" ]; then
  cat << EOF >> /opt/app/supervisord.conf
[program:japp]
priority=3
command=java -jar app.jar
directory=/opt/app/
user=app
autorestart=unexpected
stopwaitsecs=30
stdout_events_enabled=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_events_enabled=true
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
redirect_stderr=false
EOF
fi

# add optional Java application
if [ "${RUN_GO_APP:-}" == "true" ]; then
  cat << EOF >> /opt/app/supervisord.conf
[program:gapp]
priority=2
command=go run ./internal/main.go
directory=/opt/app/
user=app
autorestart=unexpected
stopwaitsecs=30
stdout_events_enabled=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_events_enabled=true
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
redirect_stderr=false
EOF
fi
