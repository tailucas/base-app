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
COPY config ./config
COPY base_setup.sh .
RUN /opt/app/base_setup.sh
COPY app_setup.sh .
RUN /opt/app/app_setup.sh
# user scripts
COPY app_entrypoint.sh .
COPY app_setup.sh .
COPY base_entrypoint.sh .
COPY base_job.sh .
COPY base_setup.sh .
COPY connect_to_app.sh .
COPY entrypoint.sh .
COPY healthchecks_heartbeat.sh .
# application setup
COPY requirements.txt .
COPY pylib/requirements.txt ./pylib/requirements.txt
# tools
COPY pylib/cred_tool ./pylib/
COPY pylib/config_interpol ./pylib/
COPY pylib/yaml_interpol ./pylib/
# python lib
COPY --chown=app:app pylib/pylib ./lib
# switch to user
USER app
ENV PYTHON_ADD_WHEEL 1
ENV PATH="${PATH}:/home/app/.local/bin"
COPY python_setup.sh .
RUN /opt/app/python_setup.sh
COPY base_app .
# ssh, http, zmq, ngrok
EXPOSE 22 5000 5556 5558 4040 8080
CMD ["/opt/app/entrypoint.sh"]
