#!/usr/bin/env bash
set -eu
set -o pipefail

# Defines the Go version (adjust as necessary)
GO_VERSION="1.26.3"
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    ARCH="arm64"
fi
TARBALL="go${GO_VERSION}.linux-${ARCH}.tar.gz"
# Download the Go tarball
curl -sLO "https://go.dev/dl/${TARBALL}"

# Extract Go to /usr/local
tar -C /usr/local -xzf "${TARBALL}"

# Add Go to the system PATH so it is available to all users
cat << 'EOF' >> /etc/profile.d/go.sh
export PATH=$PATH:/usr/local/go/bin
EOF

# Clean up the tarball
rm "${TARBALL}"

echo "$(go version)"
