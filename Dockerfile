FROM python:3.11-slim
ENV DEBIAN_FRONTEND=noninteractive
# generate correct locales
ARG LANG
ENV LANG=$LANG
ARG LANGUAGE
ENV LANGUAGE=$LANGUAGE
ARG LC_ALL
ENV LC_ALL=$LC_ALL
ARG ENCODING
ENV ENCODING=$ENCODING
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        locales
RUN sed -i -e "s/# ${LANG} ${ENCODING}/${LANG} ${ENCODING}/" /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=${LANG}
# system setup
RUN apt-get install -y --no-install-recommends \
        curl \
        cron \
        jq \
        less \
        lsof \
        # provides uptime
        procps \
        supervisor
# create no-password run-as user
RUN groupadd -f -r -g 999 app
# create run-as user
RUN useradd -r -u 999 -g 999 app
# user permissions
RUN adduser app audio
RUN adduser app video
# cron
RUN chmod u+s /usr/sbin/cron
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
COPY poetry.lock pyproject.toml python_setup.sh ./
RUN /opt/app/python_setup.sh
# ssh, http, zmq, ngrok
EXPOSE 22 5000 5556 5558 4040 8080
CMD ["/opt/app/entrypoint.sh"]
