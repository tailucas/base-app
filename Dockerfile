FROM ubuntu:latest AS builder
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        software-properties-common \
        unzip \
        zip
ENV APP_DIR /opt/app
ENV SDKMAN_DIR="${APP_DIR}/.sdkman"
RUN curl -s "https://get.sdkman.io?ci=true&rcupdate=false" | bash
RUN bash -c "source $SDKMAN_DIR/bin/sdkman-init.sh && sdk install java 25-amzn"
ENV JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
RUN bash -c "source $SDKMAN_DIR/bin/sdkman-init.sh && sdk install maven"
ENV PATH "${PATH}:$HOME/.local/bin:$HOME/.cargo/bin:${JAVA_HOME}/bin:${SDKMAN_DIR}/candidates/maven/current/bin"
# app setup
WORKDIR "${APP_DIR}"
# prepare source
COPY src ./src/
COPY java_setup.sh pom.xml rules.xml ./
RUN "${APP_DIR}/java_setup.sh"

###############################################################################

FROM ubuntu:latest
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cron \
        curl \
        gnupg \
        jq \
        less \
        locales \
        lsof \
        netcat-openbsd \
        # provides uptime
        procps \
        software-properties-common \
        supervisor \
        unzip \
        zip \
    && rm -rf /var/lib/apt/lists/*
# generate correct locales
ARG LANG
ARG LANGUAGE
RUN locale-gen ${LANGUAGE} \
    && locale-gen ${LANG} \
    && update-locale \
    && locale -a
# environment
ENV USER app
ENV HOME /home/app
ENV APP_DIR /opt/app
ENV SDKMAN_DIR="${APP_DIR}/.sdkman"
RUN curl -s "https://get.sdkman.io?ci=true&rcupdate=false" | bash
RUN bash -c "source $SDKMAN_DIR/bin/sdkman-init.sh && sdk install java 25-amzn"
ENV JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
RUN bash -c "source $SDKMAN_DIR/bin/sdkman-init.sh && sdk install maven"
ENV PATH "${PATH}:${HOME}/.local/bin:${HOME}/.cargo/bin:${JAVA_HOME}/bin:${SDKMAN_DIR}/candidates/maven/current/bin"
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
RUN mkdir -p "${HOME}/.aws/" "${APP_DIR}/"
# file system permissions
RUN chown app /var/log/
RUN chown app:app "${APP_DIR}/"
RUN chown -R app:app "${HOME}/"
# app setup
WORKDIR "$APP_DIR"
# configuration
COPY config ./config
COPY dot_env_setup.sh base_setup.sh app_setup.sh ./
RUN "${APP_DIR}/base_setup.sh"
RUN "${APP_DIR}/app_setup.sh"
# user scripts
COPY app_entrypoint.sh \
    base_entrypoint.sh \
    entrypoint.sh \
    base_job.sh \
    healthchecks_heartbeat.sh \
    connect_to_app.sh \
    README.md \
    ./
# Rust
COPY rapp ./rapp
COPY rlib ./rlib
COPY rust_setup.sh Cargo.toml Cargo.lock ./
RUN chown app:app Cargo.lock
# Python
COPY app ./app
COPY python_setup.sh pyproject.toml uv.lock ./
RUN chown app:app uv.lock
# Java
COPY --from=builder "${APP_DIR}/target/app-0.1.0-jar-with-dependencies.jar" ./app.jar
# switch to run user now because uv does not use the environment to infer
USER app
RUN "${APP_DIR}/rust_setup.sh"
RUN "${APP_DIR}/python_setup.sh"
# example HTTP backend
# EXPOSE 8080
CMD ["/opt/app/entrypoint.sh"]