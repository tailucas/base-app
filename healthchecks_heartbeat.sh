#!/usr/bin/env sh
set -eu
set -o pipefail

curl -fsS -m 10 --retry 5 --data-raw "$(hostname) $(uptime)" "${HC_PING_URL}"
