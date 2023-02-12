FROM python:alpine
# system setup
# https://github.com/inter169/systs/blob/master/alpine/crond/README.md
RUN apk update \
    && apk upgrade \
    && apk --no-cache add \
        curl \
        dcron \
        jq \
        libcap \
        supervisor
# create no-password run-as user
# https://wiki.alpinelinux.org/wiki/Setting_up_a_new_user
RUN delgroup ping
RUN addgroup --g 999 app
RUN adduser -u 999 -G app -h /home/app -D app
RUN addgroup app audio
RUN addgroup app video
# used by pip, awscli, app
RUN mkdir -p /home/app/.aws/ /opt/app/
# file system permissions
RUN chown app /var/log/
RUN chown app:app /opt/app/
RUN chown -R app:app /home/app/
# app setup
WORKDIR /opt/app
# configuration
COPY app ./app
COPY config ./config
COPY base_setup.sh app_setup.sh ./
RUN /opt/app/base_setup.sh
RUN /opt/app/app_setup.sh
# user scripts
COPY app_entrypoint.sh \
    base_entrypoint.sh \
    entrypoint.sh \
    base_job.sh \
    healthchecks_heartbeat.sh \
    connect_to_app.sh \
    README.md \
    ./
# tools
COPY pylib/ ./pylib/
# switch to user
USER app
ENV PATH "${PATH}:/home/app/.local/bin"
ENV PIP_DEFAULT_TIMEOUT 60
ENV PIP_DISABLE_PIP_VERSION_CHECK 1
ENV PIP_NO_CACHE_DIR 1
COPY poetry.lock pyproject.toml python_setup.sh ./
ENV BASE_APP_BUILD 1
RUN /opt/app/python_setup.sh
# ssh, http, zmq, ngrok
EXPOSE 22 5000 5556 5558 4040 8080
CMD ["/opt/app/entrypoint.sh"]
