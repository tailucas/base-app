#!/usr/bin/env bash
set -eu
set -o pipefail

. <(sed 's/^/export /' /opt/app/cron.env)

curl -fsS -m 10 --retry 5 --data-raw "$(hostname) $(uptime)" "${HC_PING_URL}"
