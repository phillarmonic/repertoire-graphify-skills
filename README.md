# Graphify skill catalog

[Graphify](https://github.com/Graphify-Labs/graphify) skills, activation
pointers, and optional hooks packaged as a
[Repertoire](https://github.com/phillarmonic/repertoire-ai) catalog.

The primary use case is a global Graphify skill installation with only compact,
managed activation pointers in each project. Full platform bundles stay in the
user's agent directories instead of being repeated across repositories.

Repertoire copies hook scripts and configuration as managed data. It does not
execute any copied hook during installation. Git hook files are executable once
installed so Git can invoke them later.

## Install with the Repertoire CLI

The quickest way to get the Graphify skill is a single `repertoire add` with
the source-qualified ID — no catalog registration or manifest edits needed:

```bash
repertoire add github.com/phillarmonic/repertoire-graphify-skills/graphify --target claude
```

Repeat `--target` for every agent you use (`--target codex --target copilot`,
…), or pass `--target all` to install onto every supported target. The command
installs into user-global scope by default; use `--project` to install into
the current Git worktree instead.

Add `--with-hooks` to also install Graphify's optional hooks and integrations
(Git hooks, agent hook configuration, plugins). Without it, interactive `add`
asks before installing them; noninteractive runs skip them unless the flag is
present.

If you prefer a short name, register the catalog once and then reference it by
name:

```bash
repertoire catalog add github.com/phillarmonic/repertoire-graphify-skills --name graphify
repertoire add graphify --catalog graphify --target claude
```

Later maintenance uses the same short name:

```bash
repertoire update graphify    # refresh the catalog and reinstall
repertoire remove graphify    # remove the skill and its managed pointers
```

## Global bootstrap

The primary installation style keeps Graphify's platform skill bundles in the
user's home directory and adds only small activation pointers to each
repository:

```yaml
schema: 1

catalogs:
  graphify:
    source: https://github.com/phillarmonic/repertoire-graphify-skills.git
    ref: master

skills:
  graphify:
    catalog: graphify
    scope: global
    targets: [codex, copilot]
```

Run `repertoire bootstrap` from the repository. Repertoire installs or repairs
the global skill bundles, adds managed pointer sections to the applicable
project instruction files, and keeps the pointer state in its global lock. It
does not create project-local skill directories or a project lock.

Add `hooks: true` to the declaration when the repository should also receive
Graphify's managed hooks and integrations. Pointer instructions remain present
when hooks are disabled. Removing the globally managed skill removes its known
project pointers and hooks while preserving unrelated project content.

## Repository layout

| Path | Purpose |
| --- | --- |
| `repertoire.yaml` | Repertoire catalog, variants, pointers, and optional artifacts |
| `skills/graphify/` | Default portable Agent Skills bundle |
| `platforms/<target>/` | Graphify bundle for a specific agent target |
| `pointers/` | Compact project instructions for global installations |
| `project-files/` | Optional hooks, plugins, and configuration |
| `fixtures/native/` | Normalized output from Graphify's native installers |
| `fixtures/artifact-map.tsv` | Native-to-catalog translation decisions |
| `scripts/` | Synchronization and clean-slate validation |

Generated skill bodies and project files come from the locally installed
`graphifyy` package. `repertoire.yaml` is the reviewed translation from
Graphify's installer surfaces into Repertoire's managed catalog schema.

## Maintaining the catalog

Everything required to refresh and audit the catalog lives in this repository.
After upgrading Graphify, regenerate `fixtures/native/`, review the upstream
diff, and synchronize the vendored catalog assets from the installed package
and reviewed fixtures.

The synchronization script refreshes upstream-derived bundles and project
artifacts but leaves the MIT-authored `pointers/` directory untouched. Review
those pointers when Graphify changes its skill activation contract.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the mechanical refresh and validation
procedure, including a Docker-based refresh (`Dockerfile`) that pins the
upstream `graphifyy` release without touching the local Python environment.
For a clean-slate local check with a freshly built Repertoire binary:

```sh
REPERTOIRE_BIN=/path/to/repertoire ./scripts/check-catalog.sh
./scripts/check-native-coverage.sh
./scripts/check-licenses.sh
```

## Licensing

This is a mixed-license repository. The boundary follows file ownership:

| Repository area | License |
| --- | --- |
| `skills/`, `platforms/`, `project-files/`, `fixtures/native/` | Apache-2.0, derived from Graphify |
| `pointers/`, `repertoire.yaml`, `scripts/`, fixture mapping, documentation and automation | MIT, copyright Phillarmonic Software |

See `LICENSE` for the overview, `REUSE.toml` for machine-readable path
assignments, and `NOTICE` for Graphify attribution. Graphify's historical MIT
license is preserved in `LICENSE-MIT` as required by its upstream notice.
Each generated skill bundle carries its own Apache `LICENSE`, historical
`LICENSE-MIT`, and Graphify `NOTICE`, so those files remain attached when
Repertoire installs the bundle outside this catalog checkout.

The synchronization script refreshes the upstream legal texts from the
installed `graphifyy` distribution. It also marks generated files that
Phillarmonic modifies for catalog portability.

Graphify 0.9.2's wheel still contains the earlier MIT license, while Graphify's
current repository licenses the maintained work under Apache-2.0 and retains
the MIT text for pre-relicensing contributions. The synchronization script
therefore accepts an Apache license from a newer wheel but never replaces the
checked-in Apache text with an older wheel's MIT license.

Run the license audit after every synchronization:

```sh
./scripts/check-licenses.sh
```
