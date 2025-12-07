#!/usr/bin/env bash
set -eu

mvn package
mvn dependency:tree
