#!/usr/bin/env bash
set -e
set -o pipefail

# cron

# combine crons and register (note missing users)
rm -f /opt/app/config/app_crontabs
for c in /opt/app/config/cron/*; do
  cat "$c" >> /opt/app/config/app_crontabs
done
# register user crons
crontab -u app /opt/app/config/app_crontabs
