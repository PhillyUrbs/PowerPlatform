# Copilot Instructions for this repo

Big picture
- This repo manages Microsoft Power Platform solutions as source under `solutions/`. GitHub Actions automate export/unpack, release (managed), dropdown sync, and deletion.
- `solutions.json` is the single source of truth for solution names. Workflows read it to populate dropdown inputs between special markers.

Key files and contracts
- `solutions/` — Unpacked solutions tracked in git (e.g., `solutions/ALMLab/`).
- `solutions.json` — Array of solution names. Edit this to update dropdowns.
- `.github/workflows/export-and-branch-solution.yml` — Export from DEV, unpack, PR. Inputs: `solution_name_choice` (+ optional `solution_name_custom`), computes final name via a resolve step (`steps.resolve.outputs.solution_name`).
- `.github/workflows/sync-solution-choices.yml` — Rewrites dropdown lists between markers in target workflows. Targets include:
  - `export-and-branch-solution.yml`, `release-action-call.yml`, `release-solution-to-prod.yml`, `delete-solution.yml`.
  - Markers to preserve: `# GENERATED-OPTIONS-START` and `# GENERATED-OPTIONS-END`. Only replace the list items between them.
- `.github/workflows/delete-solution.yml` — Dropdown-only input. Deletes `solutions/<name>` and removes it from `solutions.json`, then opens a PR.
- `.github/workflows/release-action-call.yml` — Orchestrates releases:
  - On Release events: resolves solution name from tag/title with patterns `solution/<name>@<ver>`, `<name>-v<ver>`, or single token; prereleases → PREPROD, full releases → PROD.
  - Manual: uses dropdown `solution_name` directly.
  - Calls `.github/workflows/release-solution-to-prod-with-inputs.yml` (reusable workflow).
- `.github/workflows/release-solution-to-prod-with-inputs.yml` — Reusable: pack unmanaged → import to BUILD → export managed → upload artifact → download → import to target env.

Secrets and environments (required names)
- Common: `POWERPLATFORM_APPID`, `TENANTID`, `POWERPLATFORMSPN`.
- Envs: `ENVIRONMENTURL_DEV` (export), `ENVIRONMENTURL_BUILD` (build/managed), `ENVIRONMENTURL_PREPROD` and `ENVIRONMENTURL_PROD` (targets). Release orchestrator passes these into the reusable workflow.

Authoring patterns to follow
- Use step outputs for computed values (e.g., `steps.resolve.outputs.solution_name`) when referenced later in the job.
- For new dropdowns in workflows, include markers and then add the file path to both arrays in `sync-solution-choices.yml`:
  - `on.push.paths` and `workflowPaths` within the script.
- To add a new solution, prefer editing `solutions.json` and let the sync workflow regenerate dropdowns, rather than hand-editing lists.

YAML conventions (linted in CI)
- 2-space indentation, indent sequences; max line length 160; final newline; no trailing spaces.
- Use block scalars for long text (e.g., PR bodies) to respect the 160-char rule.
- Workflows are linted by `yaml-lint` and `actionlint` (both run on PRs/push with concurrency to cancel stale runs).

Examples
- Marker block to keep intact:
  ```yaml
  options:
    # GENERATED-OPTIONS-START
    - ALMLab
    # GENERATED-OPTIONS-END
  ```
- Resolve final solution name (pattern used in export workflow): expose computed value via `$GITHUB_OUTPUT` and reference with `steps.<id>.outputs.solution_name`.
- Release tag formats accepted by the orchestrator: `solution/ALMLab@1.2.3`, `ALMLab-v1.2.3`.

Local dev tips
- Optional pre-commit hooks: `pre-commit install` then `pre-commit run --all-files` (uses `yamllint` and `actionlint`). Editor settings enforced via `.editorconfig`.

Don’ts
- Don’t edit outside/beyond the marker list boundaries. Don’t hardcode secret values. Don’t use tabs or exceed 160 chars per line.

Questions for maintainers
- If adding a new release environment, which secret names should be used? Should it be included in the orchestrator or the reusable workflow?
