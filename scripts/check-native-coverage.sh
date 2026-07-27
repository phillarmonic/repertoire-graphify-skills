#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Phillarmonic Software
# SPDX-License-Identifier: MIT

set -euo pipefail

catalog_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
native_root="$catalog_root/fixtures/native"
artifact_map="$catalog_root/fixtures/artifact-map.tsv"
failures=0

fail() {
  echo "ERROR: $*" >&2
  failures=$((failures + 1))
}

if [[ ! -f "$native_root/platforms.txt" ]]; then
  echo "Native platform fixture is missing: $native_root/platforms.txt" >&2
  exit 1
fi
if [[ ! -f "$artifact_map" ]]; then
  echo "Artifact translation map is missing: $artifact_map" >&2
  exit 1
fi

while IFS= read -r platform; do
  [[ -n "$platform" ]] || continue
  [[ -f "$catalog_root/platforms/$platform/SKILL.md" ]] ||
    fail "catalog variant missing for $platform"

  project_root="$native_root/$platform/project"
  [[ -d "$project_root" ]] || continue
  while IFS= read -r native_file; do
    relative=${native_file#"$project_root/"}
    case "$relative" in
      */skills/graphify/* | .aider/graphify/*)
        continue
        ;;
    esac
    if ! awk -F '\t' -v platform="$platform" -v path="$relative" \
      '$1 == platform && $2 == path { found=1 } END { exit !found }' \
      "$artifact_map"; then
      fail "native artifact has no catalog treatment: $platform/$relative"
    fi
  done < <(find "$project_root" -type f | sort)
done <"$native_root/platforms.txt"

for alias in openclaw vscode windsurf; do
  [[ -f "$catalog_root/platforms/$alias/SKILL.md" ]] ||
    fail "Repertoire compatibility variant missing for $alias"
done

while IFS= read -r variant; do
  grep -Fq "        $variant: platforms/$variant" \
    "$catalog_root/repertoire.yaml" ||
    fail "platform bundle is not declared as a catalog variant: $variant"
done < <(
  find "$catalog_root/platforms" -mindepth 1 -maxdepth 1 -type d \
    -exec basename {} \; | sort
)

while IFS=$'\t' read -r platform native_path treatment; do
  [[ -n "$platform" && "$platform" != \#* ]] || continue

  native_file="$native_root/$platform/project/$native_path"
  [[ -f "$native_file" ]] ||
    fail "mapped native artifact is missing: $platform/$native_path"

  destination=${treatment#*:}
  if [[ "$destination" == "$treatment" ]]; then
    fail "invalid catalog treatment for $platform/$native_path: $treatment"
    continue
  fi
  grep -Fq "destination: $destination" "$catalog_root/repertoire.yaml" ||
    fail "catalog destination is undeclared: $destination"
done <"$artifact_map"

if matches=$(rg -n \
  '<GRAPHIFY_BIN>|([A-Za-z]:[\\/]|/)[^"[:space:]]*graphify(\.exe)? hook-check' \
  "$native_root" "$catalog_root/project-files" 2>/dev/null); then
  fail "committed hook commands must use the graphify binary from PATH:
$matches"
fi

global_only_count=$(find "$native_root" -path '*/home/*' -type f |
  wc -l | tr -d ' ')

if ((failures > 0)); then
  echo "$failures catalog coverage check(s) failed." >&2
  exit 1
fi

echo "Native Graphify coverage is complete for all platforms and project artifacts."
echo "$global_only_count native home artifact(s) are intentionally global-only."
