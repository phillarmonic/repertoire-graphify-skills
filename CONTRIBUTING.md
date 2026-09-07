# Contributing

This repository is a reviewed Repertoire translation of Graphify's native
installer surfaces. Changes normally begin with an upstream Graphify release,
not hand edits to generated bundles.

## Repository ownership

The following paths are generated from Graphify and retain its Apache-2.0
license:

- `skills/`
- `platforms/`
- `project-files/`
- `fixtures/native/`

The following paths are maintained by Phillarmonic Software under MIT:

- `pointers/`
- `repertoire.yaml`
- `scripts/`
- `fixtures/artifact-map.tsv`
- repository documentation and automation

Keep this boundary intact. When a generated file needs a portability edit,
retain its modification notice and update the synchronization logic so the
change survives the next refresh.

## Refreshing Graphify

The refresh can run locally (steps below) or inside Docker (next section).
Either way the result is identical; Docker avoids upgrading the `graphifyy`
package in your local Python environment.

1. Upgrade the native package:

   ```sh
   uv tool install --upgrade graphifyy
   graphify --version
   graphify install --help
   ```

2. Refresh the normalized native installer fixtures:

   ```sh
   ./scripts/refresh-native-fixtures.sh
   ```

3. Review the fixture diff platform by platform. Update
   `fixtures/artifact-map.tsv` whenever Graphify adds, removes, or relocates a
   project artifact.

4. Synchronize the vendored catalog assets:

   ```sh
   ./scripts/sync-from-installed-graphify.sh
   ```

5. Review every change. Pay particular attention to supported platform names,
   skill activation text, artifact destinations, JSON merge entries, and Git
   hook behavior.

6. Build Repertoire from a current `repertoire-ai` checkout and run:

   ```sh
   REPERTOIRE_BIN=/path/to/repertoire ./scripts/check-catalog.sh
   ./scripts/check-native-coverage.sh
   ./scripts/check-licenses.sh
   uvx --from 'reuse[charset-normalizer]' reuse lint
   ```

7. Confirm the checked-in native snapshots are reproducible:

   ```sh
   ./scripts/refresh-native-fixtures.sh --check
   ```

8. Update this guide when Graphify changes its platform list, schema, commands,
   or hook behavior. `sync-from-installed-graphify.sh` records the installed
   release in `UPSTREAM_VERSION`.

### Refreshing with Docker

The repository `Dockerfile` builds an isolated image with a pinned upstream
`graphifyy` release and everything the scripts need (git, perl, rsync). It
replaces steps 1, 2, and 4 above:

```sh
docker build --build-arg GRAPHIFY_VERSION=<x.y.z> -t repertoire-graphify-sync .
docker run --rm -v "$PWD:/work" \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  repertoire-graphify-sync
```

The container mounts this repository at `/work` and runs
`scripts/docker-sync-entrypoint.sh`, which executes
`refresh-native-fixtures.sh` followed by `sync-from-installed-graphify.sh`.
`HOST_UID`/`HOST_GID` are optional; when set, files written into the mounted
repository are chowned back to the invoking user instead of staying
root-owned. Review the diff and run the validation scripts from step 6 as
usual.

The committed native snapshots replace a separate fixture repository. Managed
catalog installations are generated in temporary projects by
`check-catalog.sh`; they are deliberately not checked in as a second copy of
the catalog.

## Review rules

- Project hook commands must invoke `graphify` through `PATH`; never commit a
  developer-specific absolute binary path.
- Repertoire installs hooks as managed data and must never execute them during
  installation.
- Compact pointer files should activate the global skill without duplicating
  the full platform bundle in a project.
- Installation, update, and removal must preserve unrelated user content.
- All validation must pass on Linux and Windows before publishing.
