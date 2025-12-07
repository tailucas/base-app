#!/usr/bin/env bash
set -eu

# reduce log noise for workflow builds
if [ -n "${GITHUB_ACTIONS:-}" ]; then
    mvn -q package
else
    mvn package
    mvn dependency:tree
fi
