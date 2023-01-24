FROM python:alpine
# system setup
# https://stackoverflow.com/questions/63046301/how-to-run-cron-as-non-root-in-alpine
RUN apk update \
    && apk upgrade \
    && apk --no-cache add \
        dcron \
        libcap \
        supervisor

# app setup
WORKDIR /opt/app
COPY requirements.txt .
COPY pylib/requirements.txt ./pylib/requirements.txt
COPY base_setup.sh .
RUN /opt/app/base_setup.sh
COPY app_setup.sh .
RUN /opt/app/app_setup.sh
COPY config ./config
COPY base_entrypoint.sh .
COPY app_entrypoint.sh .
COPY entrypoint.sh .
COPY healthchecks_heartbeat.sh .
COPY pylib ./pylib
COPY pylib/pylib ./lib
COPY base_app .
# create no-password run-as user
# https://wiki.alpinelinux.org/wiki/Setting_up_a_new_user
RUN delgroup ping
RUN addgroup --g 999 app
RUN adduser -u 999 -G app -h /home/app -D app
RUN addgroup app audio
RUN addgroup app video
# cron
RUN chown app:app /usr/sbin/crond \
    && setcap cap_setgid=ep /usr/sbin/crond
# heartbeat
COPY --chown=app:app config/healthchecks_heartbeat /etc/cron.d/healthchecks_heartbeat
RUN crontab -u app /etc/cron.d/healthchecks_heartbeat
RUN chmod 0600 /etc/cron.d/healthchecks_heartbeat
# used by pip, awscli
RUN mkdir -p /home/app/.aws/
# file system permissions
RUN chown app /var/log/
RUN chown app:app /opt/app/
RUN chown -R app:app /home/app/
# ssh, http, zmq, ngrok
EXPOSE 22 5000 5556 5558 4040 8080
# switch to user
USER app
CMD ["/opt/app/entrypoint.sh"]
