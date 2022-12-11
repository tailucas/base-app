#!/bin/bash
set -eux
set -o pipefail

HIVEMIND_VERSION=${HIVEMIND_VERSION:-1.1.0}
URL_HIVEMIND_BINARY="https://github.com/DarthSim/hivemind/releases/download/v${HIVEMIND_VERSION}/hivemind-v${HIVEMIND_VERSION}-linux-amd64.gz"
# URL_HIVEMIND_CHECKSUM="https://github.com/DarthSim/hivemind/releases/download/v${HIVEMIND_VERSION}/hivemind-v${HIVEMIND_VERSION}-linux-amd64.gz.sha256sum"
TMP_DIR=$(mktemp -d -t hivemind-XXX)
wget -nv -P "${TMP_DIR}" "${URL_HIVEMIND_BINARY}"
# wget -nv -P "${TMP_DIR}" "${URL_HIVEMIND_CHECKSUM}"
COMPUTED_CHECKSUM=$(sha256sum ${TMP_DIR}/*.gz|awk '{print $1}')
# CHECKSUM=$(<${TMP_DIR}/*.sha256sum)
# [ "${COMPUTED_CHECKSUM}" == "${CHECKSUM}" ]
gzip -dc ${TMP_DIR}/*.gz > /usr/local/bin/hivemind
chmod +x /usr/local/bin/hivemind
