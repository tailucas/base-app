#!/bin/bash
set -eu
set -o pipefail

. /opt/app/base_entrypoint.sh

# replace this entrypoint with process manager
exec env supervisord -n -c /opt/app/supervisord.conf
