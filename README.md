# PowerPlatform

Power Platform ALM repository for exporting, unpacking, versioning, and releasing solutions with GitHub Actions.

This repo keeps your solutions as source (unpacked) under `solutions/` and automates exporting from DEV, branching via PR, releasing managed versions, syncing workflow dropdowns, and optionally pruning old solution folders.

## Status

![lint-yaml](https://github.com/PhillyUrbs/PowerPlatform/actions/workflows/lint-yaml.yml/badge.svg)
![lint-action](https://github.com/PhillyUrbs/PowerPlatform/actions/workflows/lint-action.yml/badge.svg)

## Repository layout

- `solutions/` — Unpacked solution folders tracked in git (e.g., `solutions/ALMLab`).
- `solutions.json` — Source of truth list of solution names used to populate workflow dropdowns.
- `scripts/` — Utility scripts for local maintenance (e.g., syncing dropdown options).
- `.github/workflows/` — CI workflows:
  - `export-solution-from-dev.yml`
  - `release-solution.yml` (reusable) & `release-action-call.yml` (orchestrator)
  - `sync-solution-choices.yml`
  - `delete-solution.yml`
  - `lint-yaml.yml` / `lint-action.yml`
- `.yamllint.yaml` — YAML lint rules (2-space indents, max 160 chars).
- `.editorconfig` — Consistent whitespace & newlines.
- `scripts/generate-manifest.sh` — Optional helper to output a lightweight `repo-manifest.json` (ignored by git) listing solution names + workflow files.
- `LICENSE`

## Required GitHub secrets

Add these repository secrets (Settings → Secrets and variables → Actions → New repository secret):

- `ENVIRONMENTURL_DEV` — URL of the DEV Dataverse environment (e.g., `https://org12345.crm.dynamics.com`).
- `POWERPLATFORM_APPID` — Azure AD app (service principal) Application (client) ID.
- `POWERPLATFORMSPN` — Client secret for the service principal.
- `TENANTID` — Azure AD tenant ID.

Other environments (e.g., TEST/PROD) may require analogous secrets referenced by the release workflows.

## Workflows

### Export and branch a solution

Workflow: `.github/workflows/export-solution-from-dev.yml`

Purpose: Export an unmanaged solution from DEV, unpack it, and open a PR with the changes.

Inputs (workflow_dispatch):

- `solution_name_choice` (choice) — Pick from `solutions.json`-backed dropdown.
- `solution_name_custom` (string, optional) — Provide a custom name (overrides dropdown).
- Staging folders: `solution_exported_folder`, `solution_folder`, `solution_target_folder` (use defaults unless you know you need to change them).

Behavior:

- Uses secrets listed above to authenticate.
- Exports the solution zip → unpacks into `solutions/<name>`.
- Ensures `solutions.json` contains `<name>` and opens a PR to add it if missing.
- Reads the solution version from `Other/Solution.xml` and creates a Git tag
  `solution/<name>@<version>` pointing at the latest `main` commit (skips if the
  tag already exists). You can later create a GitHub Release from this tag to
  drive the release workflow.

### Sync solution choices

Workflow: `.github/workflows/sync-solution-choices.yml`

Purpose: Regenerates the dropdown options blocks in workflows from `solutions.json` between the markers:

```yaml
# GENERATED-OPTIONS-START
- Name1
- Name2
# GENERATED-OPTIONS-END
```

Triggers on changes to `solutions.json` or affected workflow files, and can be run manually.

### Release process (automated or manual)

Workflow: `.github/workflows/release-action-call.yml`

Purpose: Orchestrates releases to PREPROD or PROD by calling the reusable workflow `release-solution.yml`.

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

- `lint-yaml.yml` — yamllint style validation.
- `lint-action.yml` — actionlint validation (no ignore flags required now).

Both use concurrency to cancel stale runs on the same branch.

## Contributing / local development

### Editor setup

- Install the Red Hat YAML extension for schema hints.
- EditorConfig support will auto-apply indentation and newline rules.
- Optional: set a 160‑col ruler.

### Typical workflow

1. Export from DEV using `export-solution-from-dev.yml` (manual dispatch) selecting or specifying the solution name.
2. Review PR with unpacked changes; merge.
3. Create a Git tag via the export workflow or manually: `solution/<name>@<version>`.
4. Create a GitHub Release from that tag (prerelease or full) to trigger deployment, or run the release workflow manually.

### Optional manifest helper

Generate a machine-readable summary (not required for CI):

```bash
bash scripts/generate-manifest.sh  # requires jq
```

Produces `repo-manifest.json` (ignored by git).

### PAT for workflow file updates (rare case)

If `sync-solution-choices.yml` needs to commit to workflow files and a 403 occurs, add secret `WORKFLOW_UPDATE_TOKEN` (classic PAT with repo + workflow scopes). The workflow auto-detects and uses it.

### Linting locally (optional)

CI enforces linting, so local runs are optional:

```bash
# actionlint (latest)
bash <(curl -s https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)
./actionlint -color

# yamllint
pip install --user yamllint
yamllint .
```
