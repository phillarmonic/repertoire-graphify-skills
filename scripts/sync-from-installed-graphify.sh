#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Phillarmonic Software
# SPDX-License-Identifier: MIT

set -euo pipefail

catalog_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_root=${GRAPHIFY_FIXTURE_ROOT:-"$catalog_root/fixtures/native"}
fixture_root=$(cd "$fixture_root" && pwd)
graphify_bin=$(command -v graphify)
graphify_python=$(head -1 "$graphify_bin" | sed 's/^#!//')
package_root=$(
  "$graphify_python" -c 'from pathlib import Path; import graphify; print(Path(graphify.__file__).parent)'
)
version=$("$graphify_bin" --version | awk '{print $2}')

find_upstream_legal_file() {
  "$graphify_python" - "$1" <<'PY'
from importlib.metadata import distribution
import sys

dist = distribution("graphifyy")
name = sys.argv[1]
path = next((path for path in dist.files or () if path.name == name), None)
if path is None:
    raise SystemExit(1)
print(dist.locate_file(path))
PY
}

refresh_upstream_legal_file() {
  local name=$1
  local destination=$2
  local source

  if source=$(find_upstream_legal_file "$name"); then
    cp "$source" "$destination"
  elif [[ ! -f "$destination" ]]; then
    echo "graphifyy omits $name and no checked-in fallback exists." >&2
    exit 1
  else
    echo "graphifyy omits $name; preserving checked-in $destination." >&2
  fi
}

refresh_upstream_apache_license() {
  local destination=$1
  local source

  if source=$(find_upstream_legal_file LICENSE) &&
    grep -Fq "Apache License" "$source" &&
    grep -Fq "Version 2.0, January 2004" "$source"; then
    cp "$source" "$destination"
  elif [[ ! -f "$destination" ]]; then
    echo "graphifyy does not ship Apache-2.0 and no checked-in fallback exists." >&2
    exit 1
  else
    echo "graphifyy does not ship Apache-2.0; preserving checked-in $destination." >&2
  fi
}

if [[ ! -d "$fixture_root" ]]; then
  echo "Native fixtures are missing at $fixture_root." >&2
  echo "Run scripts/refresh-native-fixtures.sh first." >&2
  exit 1
fi

rm -rf "$catalog_root/skills/graphify" "$catalog_root/platforms" "$catalog_root/project-files"
mkdir -p "$catalog_root/skills/graphify" "$catalog_root/platforms" "$catalog_root/project-files"
mkdir -p "$catalog_root/LICENSES"

refresh_upstream_apache_license "$catalog_root/LICENSES/Apache-2.0.txt"
refresh_upstream_legal_file NOTICE "$catalog_root/NOTICE"
refresh_upstream_legal_file LICENSE-MIT "$catalog_root/LICENSE-MIT"

copy_bundle() {
  local destination=$1
  local skill_file=$2
  local reference_bundle=$3
  mkdir -p "$destination"
  cp "$package_root/$skill_file" "$destination/SKILL.md"
  perl -0pi -e 's/\A(---\s*\n.*?^name:)\s*[^\n]+/$1 graphify/ms' "$destination/SKILL.md"
  perl -0pi -e \
    's/\A(---\s*\n.*?^---\s*\n)/$1<!-- Modified by Phillarmonic Software for portable Repertoire packaging. -->\n/sm' \
    "$destination/SKILL.md"
  cp "$catalog_root/LICENSES/Apache-2.0.txt" "$destination/LICENSE"
  cp "$catalog_root/LICENSE-MIT" "$destination/LICENSE-MIT"
  cp "$catalog_root/NOTICE" "$destination/NOTICE"
  printf '%s\n' "$version" >"$destination/.graphify_version"
  if [[ "$reference_bundle" != "-" ]]; then
    cp -R "$package_root/skills/$reference_bundle/references" "$destination/references"
  fi
}

copy_bundle "$catalog_root/skills/graphify" "skill-agents.md" "agents"

while IFS='|' read -r platform skill_file references; do
  [[ -n "$platform" ]] || continue
  copy_bundle "$catalog_root/platforms/$platform" "$skill_file" "$references"
done <<'BUNDLES'
agents|skill-agents.md|agents
aider|skill-aider.md|-
amp|skill-amp.md|amp
antigravity|skill.md|claude
antigravity-windows|skill-windows.md|windows
claude|skill.md|claude
claw|skill-claw.md|claw
codebuddy|skill.md|claude
codex|skill-codex.md|codex
copilot|skill-copilot.md|copilot
cursor|skill-agents.md|agents
devin|skill-devin.md|-
droid|skill-droid.md|droid
gemini|skill.md|claude
hermes|skill-claw.md|claw
kilo|skill-kilo.md|kilo
kimi|skill.md|claude
kiro|skill-kiro.md|kiro
openclaw|skill-claw.md|claw
opencode|skill-opencode.md|opencode
pi|skill-pi.md|pi
trae|skill-trae.md|trae
trae-cn|skill-trae.md|trae
vscode|skill-vscode.md|vscode
windows|skill-windows.md|windows
windsurf|skill-agents.md|agents
BUNDLES

mkdir -p \
  "$catalog_root/project-files/shared" \
  "$catalog_root/project-files/antigravity" \
  "$catalog_root/project-files/claude" \
  "$catalog_root/project-files/codebuddy" \
  "$catalog_root/project-files/codex" \
  "$catalog_root/project-files/cursor" \
  "$catalog_root/project-files/devin" \
  "$catalog_root/project-files/gemini" \
  "$catalog_root/project-files/git-hooks" \
  "$catalog_root/project-files/kilo" \
  "$catalog_root/project-files/kiro" \
  "$catalog_root/project-files/opencode"

cp "$package_root/always_on/agents-md.md" "$catalog_root/project-files/shared/agents.md"
cp "$package_root/always_on/claude-md.md" "$catalog_root/project-files/shared/claude.md"
cp "$package_root/always_on/gemini-md.md" "$catalog_root/project-files/shared/gemini.md"
cp "$package_root/always_on/vscode-instructions.md" "$catalog_root/project-files/shared/vscode-instructions.md"
cp "$fixture_root/antigravity/project/.agents/rules/graphify.md" "$catalog_root/project-files/antigravity/rules.md"
cp "$fixture_root/antigravity/project/.agents/workflows/graphify.md" "$catalog_root/project-files/antigravity/workflow.md"
cp "$fixture_root/claude/project/.claude/CLAUDE.md" "$catalog_root/project-files/claude/CLAUDE.md"
cp "$fixture_root/claude/project/.claude/settings.json" "$catalog_root/project-files/claude/settings.json"
cp "$fixture_root/codebuddy/project/.codebuddy/settings.json" "$catalog_root/project-files/codebuddy/settings.json"
cp "$fixture_root/codex/project/.codex/hooks.json" "$catalog_root/project-files/codex/hooks.json"
cp "$fixture_root/cursor/project/.cursor/rules/graphify.mdc" "$catalog_root/project-files/cursor/graphify.mdc"
cp "$fixture_root/devin/project/.windsurf/rules/graphify.md" "$catalog_root/project-files/devin/graphify.md"
cp "$fixture_root/gemini/project/.gemini/settings.json" "$catalog_root/project-files/gemini/settings.json"
cp "$fixture_root/kilo/project/.kilo/kilo.json" "$catalog_root/project-files/kilo/kilo.json"
cp "$fixture_root/kilo/project/.kilo/plugins/graphify.js" "$catalog_root/project-files/kilo/graphify.js"
cp "$fixture_root/kiro/project/.kiro/steering/graphify.md" "$catalog_root/project-files/kiro/graphify.md"
cp "$fixture_root/opencode/project/.opencode/opencode.json" "$catalog_root/project-files/opencode/opencode.json"
cp "$fixture_root/opencode/project/.opencode/plugins/graphify.js" "$catalog_root/project-files/opencode/graphify.js"
cp "$fixture_root/git-hooks/project/.git/hooks/post-commit" "$catalog_root/project-files/git-hooks/post-commit"
cp "$fixture_root/git-hooks/project/.git/hooks/post-checkout" "$catalog_root/project-files/git-hooks/post-checkout"

perl -pi -e \
  's#"command": "[^"]*/graphify hook-check"#"command": "graphify hook-check"#g' \
  "$catalog_root/project-files/codex/hooks.json"
perl -pi -e 's#file://[^"]*/\.kilo/plugins/graphify\.js#.kilo/plugins/graphify.js#g' \
  "$catalog_root/project-files/kilo/kilo.json"
perl -pi -e 's#<GRAPHIFY_PYTHON>##g' \
  "$catalog_root/project-files/git-hooks/post-commit" \
  "$catalog_root/project-files/git-hooks/post-checkout"
chmod +x \
  "$catalog_root/project-files/git-hooks/post-commit" \
  "$catalog_root/project-files/git-hooks/post-checkout"

while IFS= read -r artifact; do
  cat >"$artifact.license" <<'LICENSE'
SPDX-FileCopyrightText: 2026 Safi Shamsi and the Graphify contributors
SPDX-License-Identifier: Apache-2.0
SPDX-FileComment: Modified by Phillarmonic Software for portable Repertoire packaging.
LICENSE
done < <(find "$catalog_root/project-files" -type f ! -name '*.license' -print)

printf 'graphify %s\n' "$version" >"$catalog_root/UPSTREAM_VERSION"

echo "Synchronized Graphify $version into $catalog_root."
