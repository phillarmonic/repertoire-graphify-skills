# SPDX-FileCopyrightText: 2026 Phillarmonic Software
# SPDX-License-Identifier: MIT
#
# Isolated environment for syncing this catalog from an upstream graphify
# release, without touching the local Python/Homebrew setup.
#
# Build (pin the upstream version here):
#   docker build --build-arg GRAPHIFY_VERSION=0.9.97 -t repertoire-graphify-sync .
#
# Run (mounts this repo; both scripts run in order):
#   docker run --rm -v "$PWD:/work" repertoire-graphify-sync
#
# Artifacts are written back into the mounted repo as the invoking user when
# HOST_UID/HOST_GID are provided:
#   docker run --rm -v "$PWD:/work" \
#     -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
#     repertoire-graphify-sync

FROM python:3.13-bookworm

ARG GRAPHIFY_VERSION=0.9.97

RUN apt-get update \
 && apt-get install -y --no-install-recommends git perl rsync \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "graphifyy==${GRAPHIFY_VERSION}"

WORKDIR /work

COPY scripts/docker-sync-entrypoint.sh /usr/local/bin/docker-sync-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-sync-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-sync-entrypoint.sh"]
