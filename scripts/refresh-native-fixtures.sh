#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Phillarmonic Software
# SPDX-License-Identifier: MIT

set -euo pipefail

check_only=false
if [[ "${1:-}" == "--check" ]]; then
  check_only=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--check]" >&2
  exit 2
fi

catalog_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_root="$catalog_root/fixtures/native"
graphify_bin=$(command -v graphify)
graphify_python=$(head -1 "$graphify_bin" | sed 's/^#!//')
scratch_root=$(mktemp -d "${TMPDIR:-/tmp}/graphify-fixtures.XXXXXX")
scratch_root=$(cd "$scratch_root" && pwd -P)
next_root="$catalog_root/.graphify-native.next"
previous_root="$catalog_root/.graphify-native.previous"

cleanup() {
  rm -rf "$scratch_root"
  rm -rf "$next_root"
}
trap cleanup EXIT

platforms=$(
  "$graphify_bin" install --help |
    sed -n 's/^Platforms: //p' |
    tr ',' '\n' |
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
)
if [[ -z "$platforms" ]]; then
  echo "Could not discover Graphify platforms." >&2
  exit 1
fi

rm -rf "$next_root"
mkdir -p "$next_root"
graphify --version >"$next_root/VERSION"
printf '%s\n' "$platforms" >"$next_root/platforms.txt"

while IFS= read -r platform; do
  [[ -n "$platform" ]] || continue
  run_root="$scratch_root/$platform"
  project_root="$run_root/project"
  isolated_home="$run_root/home"
  output_root="$next_root/$platform"
  mkdir -p "$project_root" "$isolated_home" "$output_root/project" "$output_root/home"
  git -C "$project_root" init -q

  {
    echo '$ graphify install --project --platform '"$platform"
    (
      cd "$project_root"
      env HOME="$isolated_home" XDG_CONFIG_HOME="$isolated_home/.config" \
        "$graphify_bin" install --project --platform "$platform"
    )
    echo
    echo '$ graphify '"$platform"' install'
    if (
      cd "$project_root"
      env HOME="$isolated_home" XDG_CONFIG_HOME="$isolated_home/.config" \
        "$graphify_bin" "$platform" install
    ); then
      :
    else
      status=$?
      echo "Dedicated installer unavailable (exit $status); generic project install remains canonical."
    fi
  } >"$output_root/install.log" 2>&1

  rsync -a \
    --exclude '.git/' \
    --exclude 'graphify-out/' \
    "$project_root/" "$output_root/project/"
  rsync -a \
    --exclude '.cache/' \
    --exclude '__pycache__/' \
    "$isolated_home/" "$output_root/home/"

  # Shell variables stay literal because Perl reads them from its environment.
  # shellcheck disable=SC2016
  FIXTURE_RUN_ROOT="$run_root" GRAPHIFY_BIN_PATH="$graphify_bin" GRAPHIFY_PYTHON_PATH="$graphify_python" \
    find "$output_root" -type f -exec env \
      FIXTURE_RUN_ROOT="$run_root" \
      GRAPHIFY_BIN_PATH="$graphify_bin" \
      GRAPHIFY_PYTHON_PATH="$graphify_python" \
      perl -pi -e '
        s/\Q$ENV{FIXTURE_RUN_ROOT}\E/<FIXTURE_ROOT>/g;
        s/\Q$ENV{GRAPHIFY_BIN_PATH}\E/graphify/g;
        s/\Q$ENV{GRAPHIFY_PYTHON_PATH}\E/<GRAPHIFY_PYTHON>/g;
      ' {} +
done <<<"$platforms"

hooks_run="$scratch_root/git-hooks"
mkdir -p "$hooks_run/project"
git -C "$hooks_run/project" init -q
mkdir -p "$next_root/git-hooks/project/.git/hooks"
(
  cd "$hooks_run/project"
  env HOME="$hooks_run/home" XDG_CONFIG_HOME="$hooks_run/home/.config" \
    "$graphify_bin" hook install
) >"$next_root/git-hooks/install.log" 2>&1
cp "$hooks_run/project/.git/hooks/post-commit" "$next_root/git-hooks/project/.git/hooks/post-commit"
cp "$hooks_run/project/.git/hooks/post-checkout" "$next_root/git-hooks/project/.git/hooks/post-checkout"
# Shell variables stay literal because Perl reads them from its environment.
# shellcheck disable=SC2016
FIXTURE_RUN_ROOT="$hooks_run" GRAPHIFY_BIN_PATH="$graphify_bin" GRAPHIFY_PYTHON_PATH="$graphify_python" \
  find "$next_root/git-hooks" -type f -exec env \
    FIXTURE_RUN_ROOT="$hooks_run" \
    GRAPHIFY_BIN_PATH="$graphify_bin" \
    GRAPHIFY_PYTHON_PATH="$graphify_python" \
    perl -pi -e '
      s/\Q$ENV{FIXTURE_RUN_ROOT}\E/<FIXTURE_ROOT>/g;
      s/\Q$ENV{GRAPHIFY_BIN_PATH}\E/graphify/g;
      s/\Q$ENV{GRAPHIFY_PYTHON_PATH}\E/<GRAPHIFY_PYTHON>/g;
    ' {} +

if [[ -d "$fixture_root" ]]; then
  if ! diff -qr "$fixture_root" "$next_root" >/dev/null; then
    diff -ruN "$fixture_root" "$next_root" || true
    if [[ "$check_only" == true ]]; then
      echo "Native Graphify fixtures are stale." >&2
      exit 1
    fi
  elif [[ "$check_only" == true ]]; then
    echo "Native Graphify fixtures match the installed version."
    exit 0
  fi
  rm -rf "$previous_root"
  mv "$fixture_root" "$previous_root"
elif [[ "$check_only" == true ]]; then
  echo "Native Graphify fixtures do not exist." >&2
  exit 1
fi
mkdir -p "$(dirname "$fixture_root")"
mv "$next_root" "$fixture_root"
rm -rf "$previous_root"
echo "Refreshed $fixture_root for $(printf '%s\n' "$platforms" | wc -l | tr -d ' ') platforms."
