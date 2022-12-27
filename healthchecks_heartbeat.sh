#!/usr/bin/env bash
set -e
set -o pipefail

. <(cat /opt/app/cron.env | sed 's/^/export /')
curl -fsS -m 10 --retry 5 --data-raw "$(hostname) $(uptime)" "${HC_PING_URL}"
