FROM python:3.11-slim-bullseye
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        netcat \
        java-common \
        locales \
        software-properties-common
# generate correct locales
ARG LANG
ENV LANG ${LANG}
ARG LANGUAGE
ENV LANGUAGE ${LANGUAGE}
ARG LC_ALL
ENV LC_ALL ${LC_ALL}
ARG ENCODING
RUN localedef -i ${LANGUAGE} -c -f ${ENCODING} -A /usr/share/locale/locale.alias ${LANG}
RUN curl -sS https://apt.corretto.aws/corretto.key | gpg --dearmor | dd of=/etc/apt/trusted.gpg.d/corretto.gpg \
    && add-apt-repository 'deb https://apt.corretto.aws stable main' \
    # repeat so that it is detected; seems unrelated to async or layering issues
    && add-apt-repository 'deb https://apt.corretto.aws stable main' \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cron \
        java-21-amazon-corretto-jdk \
        jq \
        less \
        lsof \
        # provides uptime
        procps \
        supervisor \
    && rm -rf /var/lib/apt/lists/*
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
COPY config_interpol ./
COPY cred_tool ./
COPY yaml_interpol ./
# application
COPY ./target/app-*-jar-with-dependencies.jar ./app.jar
COPY rust_setup.sh Cargo.toml Cargo.lock rapp rlib ./
RUN chown app:app Cargo.lock
COPY pyproject.toml poetry.lock python_setup.sh ./
RUN chown app:app poetry.lock
# switch to run user
USER app
ENV PATH "${PATH}:/home/app/.local/bin:/home/app/.cargo/bin"
RUN /opt/app/rust_setup.sh
RUN /opt/app/python_setup.sh
# example HTTP backend
# EXPOSE 8080
CMD ["/opt/app/entrypoint.sh"]
