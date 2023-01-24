#!/usr/bin/env sh
set -eu
set -o pipefail

. /opt/app/base_entrypoint.sh
. /opt/app/app_entrypoint.sh

# replace this entrypoint with process manager
exec env supervisord -n -c /opt/app/supervisord.conf
