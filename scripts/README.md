# Scripts

Utility scripts to support repository maintenance while keeping solution folders lightweight in day-to-day operations.

## build-manifest.sh

Generates `repo-manifest.json`, a concise JSON summary containing:

- `generated`: UTC timestamp
- `solutions`: solution names from `solutions.json`
- `workflows`: discovered workflow files under `.github/workflows/`
- `notes`: flags (currently `solutionsContentExcluded`)

Usage:

```bash
bash scripts/build-manifest.sh
```

Typically invoked by `reindex.sh`.

## reindex.sh

Creates or refreshes developer convenience indexes, excluding the heavy unpacked solution contents:

- `.file-index` (tracked files without `solutions/`)
- `.tags` (symbol index if `ctags` is available)
- `repo-manifest.json` (via `build-manifest.sh`)

Usage:

```bash
bash scripts/reindex.sh
```

A VS Code task "Reindex (exclude solutions/)" is configured to call this script.

## Conventions

- Scripts are bash (`set -euo pipefail`).
- Safe to re-run; they do not mutate solution contents.
- If `jq` is available it is used for JSON parsing; otherwise a minimal fallback applies.

## Future ideas

- Add a `validate` script (previously removed) if consistency checks need to return.
- Provide a PowerShell equivalent for Windows-only environments.
- Extend manifest with environment metadata if required.
