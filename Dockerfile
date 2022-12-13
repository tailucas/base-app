FROM debian:buster
ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true

RUN apt-get clean && apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
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
COPY entrypoint.sh .
COPY pylib ./pylib
COPY pylib/pylib ./lib
COPY base_app .

# create group ID 1024 for external volume permissions
RUN groupadd -f -r -g 1024 app
# create run-as user
RUN useradd -r -g app app
# user permissions
RUN adduser app audio
RUN chown app:app /opt/app/
RUN chown app /var/log/

# ssh, http, zmq, ngrok
EXPOSE 22 5000 5556 5558 4040 8080

# switch to user
USER app
CMD ["/opt/app/entrypoint.sh"]
