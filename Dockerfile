FROM debian:bullseye
ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true
RUN apt-get clean && apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cron \
    curl \
    dbus \
    html-xml-utils \
    htop \
    jq \
    less \
    lsof \
    libffi-dev \
    # for rust build of Python cryptography
    libssl-dev \
    procps \
    python3-certifi \
    python3-dbus \
    python3 \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-venv \
    python3-wheel \
    rsyslog \
    strace \
    sqlite3 \
    supervisor \
    tree \
    unzip \
    vim \
    wget
# python3 default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1
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
# create group ID for external volume permissions
RUN groupadd -f -r -g 999 app
# create run-as user
RUN useradd -r -u 999 -g 999 app
# user permissions
RUN adduser app audio
RUN adduser app video
RUN chown app /opt/app/
RUN chown app /var/log/
# cron
RUN chmod u+s /usr/sbin/cron
# heartbeat
ADD config/healthchecks_heartbeat /etc/cron.d/healthchecks_heartbeat
RUN crontab -u app /etc/cron.d/healthchecks_heartbeat
RUN chmod 0600 /etc/cron.d/healthchecks_heartbeat
# used by pip, awscli
RUN mkdir -p /home/app
RUN mkdir -p /home/app/.aws/
RUN chown -R app /home/app/
# ssh, http, zmq, ngrok
EXPOSE 22 5000 5556 5558 4040 8080
# switch to user
USER app
CMD ["/opt/app/entrypoint.sh"]
