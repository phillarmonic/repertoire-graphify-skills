#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Phillarmonic Software
# SPDX-License-Identifier: MIT
#
# Runs the catalog sync inside the Dockerfile image against the repo mounted
# at /work: refresh the native fixtures, then sync skills/platforms/project
# files from the installed graphify package.

set -euo pipefail

cd /work

scripts/refresh-native-fixtures.sh
scripts/sync-from-installed-graphify.sh

# Hand ownership of everything written during the run back to the host user.
if [[ -n "${HOST_UID:-}" && -n "${HOST_GID:-}" ]]; then
  chown -R "$HOST_UID:$HOST_GID" \
    /work/fixtures /work/skills /work/platforms /work/project-files \
    /work/UPSTREAM_VERSION /work/NOTICE /work/LICENSE-MIT /work/LICENSES
fi

echo "Docker sync complete: $(cat /work/UPSTREAM_VERSION)"
