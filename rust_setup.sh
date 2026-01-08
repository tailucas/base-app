#!/usr/bin/env bash
set -eu
set -o pipefail

# Workaround for https://github.com/rust-lang/rustup/issues/1239
rm -rf "${HOME}/.rustup/"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
