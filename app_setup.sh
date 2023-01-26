#!/usr/bin/env sh
set -e
set -o pipefail

. /opt/app/bin/activate
# output site configuration
python -m site
export PIP_DEFAULT_TIMEOUT=60
python -m pip install -r "/opt/app/requirements.txt"

deactivate

# cron

# combine crons and register (note missing users)
rm -f /opt/app/config/app_crontabs
for c in /opt/app/config/cron/*; do
  cat "$c" >> /opt/app/config/app_crontabs
done
# register user crons
crontab -u app /opt/app/config/app_crontabs
chown -R app:app /etc/crontabs/
