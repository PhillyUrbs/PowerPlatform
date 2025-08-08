# PowerPlatform

Power Platform ALM repository for exporting, unpacking, versioning, and releasing solutions with GitHub Actions.

This repo keeps your solutions as source (unpacked) under `solutions/` and automates common tasks like exporting from DEV, creating PRs, maintaining workflow dropdowns, and deleting backed-up solutions when needed.

## Status

![yaml-lint](https://github.com/PhillyUrbs/PowerPlatform/actions/workflows/yaml-lint.yml/badge.svg)
![actionlint](https://github.com/PhillyUrbs/PowerPlatform/actions/workflows/actionlint.yml/badge.svg)

## Repository layout

- `solutions/` — Unpacked solution folders tracked in git (e.g., `solutions/ALMLab`).
- `solutions.json` — Source of truth list of solution names used to populate workflow dropdowns.
- `scripts/` — Utility scripts for local maintenance (e.g., syncing dropdown options).
- `.github/workflows/` — CI workflows:
	- `export-and-branch-solution.yml` — Export from DEV, unpack, and open a PR with changes.
	- `release-solution-to-prod-with-inputs.yml` / `release-action-call.yml` — Release pipeline (invoke and/or orchestrate releases).
	- `sync-solution-choices.yml` — Keeps dropdown options in workflows in sync with `solutions.json`.
	- `delete-solution.yml` — Deletes a backed-up solution folder from `solutions/` and opens a PR with the removal.
- `.yamllint.yaml` — YAML lint rules (2-space indents, max line length 160, final newline, etc.).
- `.editorconfig` — Enforces editor settings (indentation, final newline, trimming) across contributors.
- `.pre-commit-config.yaml` — Local hooks (yamllint, actionlint) to catch issues before committing.
- `LICENSE` — License for this repository.

Note: `scripts/sync-solution-choices.ps1` is a local helper; the repo primarily uses a GitHub Actions step (`actions/github-script`) to perform the same sync server-side.

## Required GitHub secrets

Add these repository secrets (Settings → Secrets and variables → Actions → New repository secret):

- `ENVIRONMENTURL_DEV` — URL of the DEV Dataverse environment (e.g., `https://org12345.crm.dynamics.com`).
- `POWERPLATFORM_APPID` — Azure AD app (service principal) Application (client) ID.
- `POWERPLATFORMSPN` — Client secret for the service principal.
- `TENANTID` — Azure AD tenant ID.

Other environments (e.g., TEST/PROD) may require analogous secrets referenced by the release workflows.

## Workflows

### Export and branch a solution

Workflow: `.github/workflows/export-and-branch-solution.yml`

Purpose: Export an unmanaged solution from DEV, unpack it, and open a PR with the changes.

Inputs (workflow_dispatch):
- `solution_name_choice` (choice) — Pick from `solutions.json`-backed dropdown.
- `solution_name_custom` (string, optional) — Provide a custom name (overrides dropdown).
- Staging folders: `solution_exported_folder`, `solution_folder`, `solution_target_folder` (use defaults unless you know you need to change them).

Behavior:
- Uses secrets listed above to authenticate.
- Exports the solution zip → unpacks into `solutions/<name>`.
- Ensures `solutions.json` contains `<name>` and opens a PR to add it if missing.

### Sync solution choices

Workflow: `.github/workflows/sync-solution-choices.yml`

Purpose: Regenerates the dropdown options blocks in workflows from `solutions.json` between the markers:

```
# GENERATED-OPTIONS-START
- Name1
- Name2
# GENERATED-OPTIONS-END
```

Triggers on changes to `solutions.json` or affected workflow files, and can be run manually.

### Release process (automated or manual)

Workflow: `.github/workflows/release-action-call.yml`

Purpose: Orchestrates releases to PREPROD or PROD by calling the reusable workflow `release-solution-to-prod-with-inputs.yml`.

Triggers:
- GitHub Release events: `prereleased` and `released`.
- Manual: `workflow_dispatch` with a solution dropdown.

How the solution name is resolved:
- For Release events, the workflow inspects the tag and the release title to extract the solution name using these patterns (in order):
	- `solution/<name>@<version>` (e.g., `solution/ALMLab@1.2.3`)
	- `<name>-v<version>` or `<name>-<version>` (e.g., `ALMLab-v1.2.3`)
	- Fallback: a single token without spaces.
	- If none match, the workflow fails with guidance to include one of the above patterns.
- For Manual runs, it uses the `solution_name` dropdown input directly.

Environments and behavior:
- If the GitHub Release is marked prerelease, it deploys to PREPROD (`ENVIRONMENTURL_PREPROD`).
- If it’s a full release, it deploys to PROD (`ENVIRONMENTURL_PROD`).
- Both paths use the build environment (`ENVIRONMENTURL_BUILD`) and call the reusable workflow with the resolved `solution_name`.
- The manual path defaults to PREPROD (see the comment in the workflow) but can be changed in the YAML if desired.

Required secrets for release:
- `POWERPLATFORMSPN` (as `envSecret`)
- `ENVIRONMENTURL_BUILD`
- `ENVIRONMENTURL_PREPROD` (for prereleases)
- `ENVIRONMENTURL_PROD` (for full releases)
- `POWERPLATFORM_APPID`
- `TENANTID`

Examples of acceptable release tags/titles:
- Tag: `solution/ALMLab@1.2.3`
- Tag: `ALMLab-v1.2.3`
- Title: `ALMLab v1.2.3`

### Delete a backed-up solution

Workflow: `.github/workflows/delete-solution.yml`

Purpose: Deletes `solutions/<name>` and removes the name from `solutions.json`, then opens a PR with the change.

Inputs (workflow_dispatch):
- `solution_name_choice` (choice) — Pick the name to delete.

Safety: Runs in a PR; you review and merge the deletion.

### Linting workflows

- `yaml-lint` — Runs yamllint on all `*.yml`/`*.yaml` on PRs and pushes.
- `actionlint` — Validates GitHub Actions YAML, expressions, and shell steps on PRs and pushes.

Both jobs use concurrency to cancel stale runs on the same branch.

## Local development

### Editor setup

- Install “YAML” by Red Hat for schema and indentation checks.
- Editors that support EditorConfig will pick up `.editorconfig` automatically.
- Optional: set an editor ruler at column 160 to match `.yamllint.yaml`.

### Pre-commit hooks (optional, recommended)

Use pre-commit to run yamllint/actionlint locally before committing.

Recommended (pipx, keeps Python tools isolated):

```bash
# Install pipx if not already present (one-time)
python -m pip install --user pipx
python -m pipx ensurepath

# Install and enable hooks
pipx install pre-commit
pre-commit install

# Run on the entire repo
pre-commit run --all-files
```

Alternative (regular pip):

```bash
python -m pip install --user pre-commit
pre-commit install
pre-commit run --all-files
```

## License

This project is licensed under the terms of the license found in `LICENSE`.
