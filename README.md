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

## Onboarding a new environment

Follow the detailed guide in `docs/ENVIRONMENT-ONBOARDING.md` to:

- Create / reuse the Azure AD app registration (service principal)
- Assign roles in each Dataverse environment
- Configure required GitHub environment variables & secrets
- Add an extra stage (optional) and extend workflows

Quick reference of required names (details in the guide): `POWERPLATFORMAPPID`, `POWERPLATFORMAPPSECRET`, `TENANTID`, `ENVIRONMENTURL_DEV`, `ENVIRONMENTURL_BUILD`, `ENVIRONMENTURL_QA`, `ENVIRONMENTURL_PROD`.

## Required GitHub environments and secrets/variables

Configure these GitHub environments (Settings → Environments) with appropriate secrets and variables:

**Shared Environment Secrets/Variables**

- Environment secret: `POWERPLATFORMAPPID` — Azure AD app (service principal) Application (client) ID
- Environment secret: `POWERPLATFORMAPPSECRET` — Client secret for the service principal
- Environment secret: `TENANTID` — Azure AD tenant ID

**DEV Environment:**

- Environment variable: `ENVIRONMENTURL_DEV` — URL of the DEV Dataverse environment (e.g., `https://org12345.crm.dynamics.com`)

**QA Environment:**

- Environment variable: `ENVIRONMENTURL_QA` — URL of the QA Dataverse environment

**PROD Environment:**

- Environment variable: `ENVIRONMENTURL_PROD` — URL of the PROD Dataverse environment

**BUILD Environment**

- Environment variable: `ENVIRONMENTURL_BUILD` — URL of the BUILD Dataverse environment for solution conversion

**Repository secrets (not environment-specific):**

- `WORKFLOW_UPDATE_TOKEN` — Personal access token for updating workflow files (classic PAT with repo + workflow scopes)

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

Purpose: Orchestrates releases to QA or PROD by calling the reusable workflow `release-solution.yml`.

Current mode: Automatic release event triggers are disabled (only manual dispatch). Re‑enable by uncommenting the `release:` trigger block inside the workflow.

Triggers (when fully enabled):

- GitHub Release events: `prereleased` (deploy to QA) and `released` (deploy to PROD).
- Manual: `workflow_dispatch` with a solution dropdown + target stage.

How the solution name is resolved:

- For Release events, the workflow inspects the tag and the release title to extract the solution name using these patterns (in order):
  - `solution/<name>@<version>` (e.g., `solution/ALMLab@1.2.3`)
  - `<name>-v<version>` or `<name>-<version>` (e.g., `ALMLab-v1.2.3`)
  - Fallback: a single token without spaces.
  - If none match, the workflow fails with guidance to include one of the above patterns.
- For Manual runs, it uses the `solution_name` dropdown input directly.

Environment handling:

- A single GitHub environment input (`environment_name`) now supplies all required secrets/variables (APP ID, SECRET, TENANT, and all `ENVIRONMENTURL_*` values).
- Stage routing depends solely on which URL is selected: prerelease → `ENVIRONMENTURL_QA`, release → `ENVIRONMENTURL_PROD`, manual path picks based on the chosen dropdown (QA/PROD).
- `ENVIRONMENTURL_BUILD` is always used for the conversion (pack/import/export managed cycle).

Required environment secrets/variables for release (all reside in the same GitHub environment):

- `POWERPLATFORMAPPID` (secret)
- `POWERPLATFORMAPPSECRET` (secret)
- `TENANTID` (secret)
- `ENVIRONMENTURL_BUILD` (variable)
- `ENVIRONMENTURL_QA` (variable)
- `ENVIRONMENTURL_PROD` (variable)
- (Optional) `ENVIRONMENTURL_DEV` if also used by export workflow in that environment

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
