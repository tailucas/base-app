#!/usr/bin/env bash
set -eu

. <(sed 's/^/export /' /opt/app/cron.env)

logger "Health checks URL is ${HC_PING_URL}."
