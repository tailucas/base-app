#!/usr/bin/env bash
set -eu

# reduce log noise for workflow builds
if [ -n "${GITHUB_ACTIONS:-}" ]; then
    mvn --no-transfer-progress -q package
else
    mvn --no-transfer-progress package
    mvn --no-transfer-progress dependency:tree
fi
