# Native Graphify fixtures

This directory records deterministic output from Graphify's native installers.
It is the upstream evidence used to review and regenerate the Repertoire
catalog without relying on another repository.

- `native/` contains normalized project and isolated-home output for every
  platform reported by `graphify install --help`.
- `artifact-map.tsv` records how each native project artifact is represented
  in `repertoire.yaml`.

Refresh the snapshots with:

```sh
./scripts/refresh-native-fixtures.sh
```

Use `--check` to regenerate into a temporary directory and fail on any
difference:

```sh
./scripts/refresh-native-fixtures.sh --check
```

The native snapshots are derived from Graphify and licensed under Apache-2.0.
This README and the translation map are Phillarmonic maintenance material
licensed under MIT.
