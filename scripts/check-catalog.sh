#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Phillarmonic Software
# SPDX-License-Identifier: MIT

set -euo pipefail

catalog_root=${GRAPHIFY_CATALOG_ROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}
catalog_root=$(cd "$catalog_root" && pwd)
repertoire_command=${REPERTOIRE_BIN:-repertoire}
repertoire_bin=$(command -v "$repertoire_command")
scratch_root=$(mktemp -d "${TMPDIR:-/tmp}/graphify-catalog.XXXXXX")
home_root="$scratch_root/home"
bootstrap_project="$scratch_root/bootstrap-project"
project_install="$scratch_root/project-install"
target_projects="$scratch_root/target-projects"

cleanup() {
  if [[ "${KEEP_SCRATCH:-false}" == true ]]; then
    echo "Retained scratch directory: $scratch_root"
    return
  fi
  rm -rf "$scratch_root"
}
trap cleanup EXIT

mkdir -p \
  "$home_root/AppData/Local" \
  "$home_root/AppData/Roaming" \
  "$bootstrap_project" \
  "$project_install" \
  "$target_projects"
git -C "$bootstrap_project" init -q
git -C "$project_install" init -q

catalog_source=$catalog_root
if command -v cygpath >/dev/null 2>&1; then
  catalog_source=$(cygpath -m "$catalog_root")
fi

run_repertoire() {
  local project_root=$1
  shift
  (
    export HOME="$home_root"
    export USERPROFILE="$home_root"
    export APPDATA="$home_root/AppData/Roaming"
    export LOCALAPPDATA="$home_root/AppData/Local"
    unset CODEX_HOME XDG_CONFIG_HOME XDG_CACHE_HOME
    cd "$project_root"
    "$repertoire_bin" "$@"
  )
}

assert_file() {
  if [[ ! -f "$1" ]]; then
    echo "Expected file is missing: $1" >&2
    exit 1
  fi
}

assert_missing() {
  if [[ -e "$1" ]]; then
    echo "Unexpected path exists: $1" >&2
    exit 1
  fi
}

cat >"$bootstrap_project/AGENTS.md" <<'EOF'
# Test project

Keep this user-owned instruction.
EOF

write_bootstrap_manifest() {
  local hooks=$1
  cat >"$bootstrap_project/repertoire.yaml" <<EOF
schema: 1

catalogs:
  graphify:
    source: $catalog_source

skills:
  graphify:
    catalog: graphify
    scope: global
    targets: [codex, copilot]
EOF
  if [[ "$hooks" == true ]]; then
    printf '    hooks: true\n' >>"$bootstrap_project/repertoire.yaml"
  fi
}

write_bootstrap_manifest false
run_repertoire "$bootstrap_project" bootstrap

assert_file "$home_root/.codex/skills/graphify/SKILL.md"
assert_file "$home_root/.copilot/skills/graphify/SKILL.md"
assert_file "$bootstrap_project/AGENTS.md"
assert_file "$bootstrap_project/.github/copilot-instructions.md"
assert_missing "$bootstrap_project/.codex/skills/graphify"
assert_missing "$bootstrap_project/.copilot/skills/graphify"
assert_missing "$bootstrap_project/repertoire.lock.json"
assert_missing "$bootstrap_project/.codex/hooks.json"
assert_missing "$bootstrap_project/.git/hooks/post-commit"
grep -Fq "Keep this user-owned instruction." "$bootstrap_project/AGENTS.md"
grep -Fq "This repository uses Graphify." "$bootstrap_project/AGENTS.md"

write_bootstrap_manifest true
run_repertoire "$bootstrap_project" bootstrap
assert_file "$bootstrap_project/.codex/hooks.json"
assert_file "$bootstrap_project/.git/hooks/post-commit"
assert_file "$bootstrap_project/.git/hooks/post-checkout"
grep -Fq '"command": "graphify hook-check"' \
  "$bootstrap_project/.codex/hooks.json"

write_bootstrap_manifest false
run_repertoire "$bootstrap_project" bootstrap
assert_missing "$bootstrap_project/.codex/hooks.json"
assert_missing "$bootstrap_project/.git/hooks/post-commit"
assert_missing "$bootstrap_project/.git/hooks/post-checkout"
grep -Fq "This repository uses Graphify." "$bootstrap_project/AGENTS.md"

run_repertoire "$bootstrap_project" remove graphify
if grep -Fq "This repository uses Graphify." "$bootstrap_project/AGENTS.md"; then
  echo "Global removal left the managed AGENTS.md pointer." >&2
  exit 1
fi
assert_missing "$bootstrap_project/.github/copilot-instructions.md"
grep -Fq "Keep this user-owned instruction." "$bootstrap_project/AGENTS.md"

mkdir -p "$project_install/.codex"
cat >"$project_install/.codex/hooks.json" <<'EOF'
{
  "userSetting": true
}
EOF
run_repertoire "$project_install" --project catalog add "$catalog_source" \
  --name graphify
run_repertoire "$project_install" --project add graphify \
  --catalog graphify \
  --target codex \
  --with-hooks

assert_file "$project_install/.codex/skills/graphify/SKILL.md"
assert_file "$project_install/.codex/hooks.json"
assert_file "$project_install/.git/hooks/post-commit"
grep -Fq '"userSetting": true' "$project_install/.codex/hooks.json"
grep -Fq '"command": "graphify hook-check"' \
  "$project_install/.codex/hooks.json"

run_repertoire "$project_install" --project update graphify --no-hooks
assert_missing "$project_install/.git/hooks/post-commit"
grep -Fq '"userSetting": true' "$project_install/.codex/hooks.json"
if grep -Fq '"command": "graphify hook-check"' \
  "$project_install/.codex/hooks.json"; then
  echo "Project update left the managed Codex hook." >&2
  exit 1
fi

run_repertoire "$project_install" --project remove graphify
assert_missing "$project_install/.codex/skills/graphify"
grep -Fq '"userSetting": true' "$project_install/.codex/hooks.json"

target_count=0
while IFS= read -r target; do
  [[ -n "$target" ]] || continue
  target_count=$((target_count + 1))
  target_project="$target_projects/$target"
  mkdir -p "$target_project"
  git -C "$target_project" init -q

  run_repertoire "$target_project" --project catalog add "$catalog_source" \
    --name graphify >/dev/null
  run_repertoire "$target_project" --project add graphify \
    --catalog graphify \
    --target "$target" \
    --with-hooks >/dev/null

  if ! find "$target_project" -type f -path '*/graphify/SKILL.md' \
    -print -quit | grep -q .; then
    echo "Target $target did not install a Graphify skill bundle." >&2
    exit 1
  fi

  run_repertoire "$target_project" --project remove graphify >/dev/null
  if find "$target_project" -type f -path '*/graphify/SKILL.md' \
    -print -quit | grep -q .; then
    echo "Target $target left its Graphify skill bundle after removal." >&2
    exit 1
  fi
done < <(
  find "$catalog_root/platforms" -mindepth 1 -maxdepth 1 -type d \
    -exec basename {} \; | sort
)

echo "Graphify catalog clean-slate lifecycle passed for $target_count targets."
