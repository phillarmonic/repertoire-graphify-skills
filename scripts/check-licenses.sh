#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Phillarmonic Software
# SPDX-License-Identifier: MIT

set -euo pipefail

catalog_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$catalog_root"

required_files=(
  LICENSE
  LICENSE-MIT
  LICENSES/Apache-2.0.txt
  LICENSES/MIT.txt
  NOTICE
  REUSE.toml
  fixtures/native/VERSION
  fixtures/native/platforms.txt
  fixtures/artifact-map.tsv
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "Missing required license file: $path" >&2
    exit 1
  fi
done

if ! cmp -s UPSTREAM_VERSION fixtures/native/VERSION; then
  echo "UPSTREAM_VERSION does not match the native fixture version." >&2
  exit 1
fi

grep -Fq "Copyright 2026 Safi Shamsi and the Graphify contributors." NOTICE
grep -Fq "Copyright (c) 2026 Safi Shamsi" LICENSE-MIT
grep -Fq "Copyright (c) 2026 Phillarmonic Software" LICENSES/MIT.txt
grep -Fq "Apache License" LICENSES/Apache-2.0.txt
grep -Fq "Version 2.0, January 2004" LICENSES/Apache-2.0.txt

while IFS= read -r skill_file; do
  skill_directory=$(dirname "$skill_file")
  if ! grep -Fq \
    "Modified by Phillarmonic Software for portable Repertoire packaging." \
    "$skill_file"; then
    echo "Missing modification notice: $skill_file" >&2
    exit 1
  fi
  cmp -s LICENSES/Apache-2.0.txt "$skill_directory/LICENSE" || {
    echo "Skill has stale Apache license: $skill_directory" >&2
    exit 1
  }
  cmp -s LICENSE-MIT "$skill_directory/LICENSE-MIT" || {
    echo "Skill has stale historical MIT license: $skill_directory" >&2
    exit 1
  }
  cmp -s NOTICE "$skill_directory/NOTICE" || {
    echo "Skill has stale Graphify notice: $skill_directory" >&2
    exit 1
  }
done < <(find skills platforms -name SKILL.md -type f -print)

while IFS= read -r artifact; do
  sidecar="$artifact.license"
  if [[ ! -f "$sidecar" ]]; then
    echo "Missing license sidecar: $sidecar" >&2
    exit 1
  fi
  grep -Fq "SPDX""-License-Identifier: Apache-2.0" "$sidecar"
  grep -Fq "Modified by Phillarmonic Software" "$sidecar"
done < <(find project-files -type f ! -name '*.license' -print)

if grep -Eq 'source: .*\.license$' repertoire.yaml; then
  echo "License sidecars must not be installed as project artifacts." >&2
  exit 1
fi

if ! grep -Fq '"command": "graphify hook-check"' project-files/codex/hooks.json; then
  echo "Codex hooks must invoke graphify by binary name through PATH." >&2
  exit 1
fi
if grep -ERq \
  '<GRAPHIFY_BIN>|([A-Za-z]:[\\/]|/)[^"[:space:]]*graphify(\.exe)? hook-check' \
  project-files; then
  echo "Project hook commands must not contain an absolute Graphify path." >&2
  exit 1
fi

echo "License boundaries are complete."
