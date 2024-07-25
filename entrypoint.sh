#!/usr/bin/env bash
set -eu
set -o pipefail

if [ -n "${TEST_ON_START_ADDRESS:-}" ]; then
  nc -zvw2 "${TEST_ON_START_ADDRESS}" "${TEST_ON_START_PORT:-80}"
fi

. /opt/app/base_entrypoint.sh
. /opt/app/app_entrypoint.sh

# replace this entrypoint with process manager
exec env supervisord -n -c /opt/app/supervisord.conf
