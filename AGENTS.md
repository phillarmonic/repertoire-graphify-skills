# Agent guidance

This repository is a reviewed Repertoire translation of Graphify's native
installer surfaces. Most work arrives as an upstream Graphify release, so
refresh from the package instead of hand-editing generated files.

`CONTRIBUTING.md` is the authoritative procedure. This file is the short path
for agents doing the work.

## Refresh with Docker first

Use the repository `Dockerfile` for every version bump. It installs one pinned
`graphifyy` release in an isolated image, so the host's Python environment and
the user's `uv tool` install stay untouched.

1. Find the target release. It is `info.version` in
   <https://pypi.org/pypi/graphifyy/json>, and the checked-in value lives in
   `UPSTREAM_VERSION`.

2. Build the sync image, then run it against the checkout:

   ```sh
   VERSION=0.9.97
   docker build --build-arg GRAPHIFY_VERSION="$VERSION" \
     -t repertoire-graphify-sync:"$VERSION" .
   docker run --rm \
     -v "$PWD:/work" \
     -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
     repertoire-graphify-sync:"$VERSION"
   ```

   Pass `HOST_UID` and `HOST_GID`, or the container leaves root-owned files in
   the checkout. The entrypoint runs `scripts/refresh-native-fixtures.sh`, then
   `scripts/sync-from-installed-graphify.sh`, and writes `UPSTREAM_VERSION`.

Keep the Dockerfile's default `GRAPHIFY_VERSION` on the release that is
currently vendored, so a plain `docker build` reproduces the checkout.

Do not install or upgrade `graphifyy` locally just to perform a refresh. The
local tool can differ from the PyPI release under review, and a local refresh
leaves machine state behind that the next agent cannot reproduce. Use the local
path only when debugging the sync scripts themselves, and say so in the report.

## When the sync aborts

The sync script copies a known set of upstream artifacts. A release can move or
drop one, and the first failed `cp` stops the run after the fixtures were
already replaced, leaving the tree half-synced.

1. Read `fixtures/native/<platform>/install.log` to see what the installer
   actually wrote.
2. Update every place that describes the artifact: the copy block in
   `scripts/sync-from-installed-graphify.sh`, the row in
   `fixtures/artifact-map.tsv`, and the `artifacts:` block in
   `repertoire.yaml`. Remove all three when upstream no longer produces the
   file.
3. Rebuild the image and run it again, until the sync completes with no
   `cannot stat` error. Rebuilding matters because the entrypoint script is
   baked into the image.

Never paper over the failure by copying an older artifact, and never leave a
destination declared that the installer stopped writing.

## Review the diff

Check these before validating, since the checks cannot judge intent:

- `fixtures/native/platforms.txt` for added or removed platforms, and whether
  `repertoire.yaml` variants and `scripts/check-native-coverage.sh` aliases
  still match.
- Skill activation text and `pointers/`. Pointers are MIT and hand-maintained;
  review them when Graphify changes how it asks agents to activate the skill.
- Artifact destinations, JSON merge entries, and Git hook behavior.
- That hook commands still invoke `graphify` through `PATH`, never an absolute
  path.

## Validate

```sh
REPERTOIRE_BIN=/path/to/repertoire ./scripts/check-catalog.sh
./scripts/check-native-coverage.sh
./scripts/check-licenses.sh
./scripts/refresh-native-fixtures.sh --check
uvx --from 'reuse[charset-normalizer]' reuse lint
shellcheck scripts/*.sh
```

`refresh-native-fixtures.sh --check` compares the snapshots against the local
`graphify` binary. Run it with the same version the image used, or it reports
stale fixtures on a correct checkout.

## Generated paths

`skills/`, `platforms/`, `project-files/`, and `fixtures/native/` are generated
from Graphify and carry Apache-2.0. `pointers/`, `repertoire.yaml`, `scripts/`,
`fixtures/artifact-map.tsv`, documentation, and automation are MIT. Keep the
boundary intact: `scripts/check-licenses.sh` and `reuse lint` enforce it.

Make portability changes in the sync script, with the existing modification
notice, so they survive the next refresh.

## Commit

Create one local commit per release, subject `Graphify vX.Y.Z`, following the
history in `git log`. Do not push, tag, or publish without an explicit request.
