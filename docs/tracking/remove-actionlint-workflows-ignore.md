# Tracking: Remove temporary actionlint workaround for `workflows` permission

Status: OPEN  
Created: 2025-08-22  
Owner: (Unassigned – pick up once actionlint supports the `workflows` permission scope)

## Context

The repository currently uses the new GitHub Actions permission scope `workflows: write` in
`sync-solution-choices.yml` so it can commit modifications to other workflow files. The released
version of actionlint (<= 1.7.7 at the time of writing) does not yet recognize this permission
scope and reports:

```text
unknown permission scope "workflows"
```

To keep CI green while retaining strict linting for everything else we introduced two temporary mitigations:

1. In `lint-action.yml` we invoke the latest downloaded actionlint with: `./actionlint -color -ignore 'unknown permission scope "workflows"'` (narrow ignore pattern targeting only this diagnostic)
2. A `.actionlintignore` file lists `./.github/workflows/sync-solution-choices.yml` to protect local / older tool versions.

Once actionlint adds native support for the `workflows` permission, these workarounds should be removed to restore full lint coverage.

## Acceptance Criteria

- Running the latest actionlint *without* the `-ignore` flag produces no errors for the `workflows` permission.
- `.actionlintignore` no longer contains an entry for `sync-solution-choices.yml` (file may be deleted if empty).
- The ignore flag is removed from the actionlint invocation in `lint-action.yml`.
- Comments referencing the temporary workaround are deleted or updated.
- CI passes with the stricter configuration.

## Steps to Resolve

1. Manually run (or let CI run) a newer actionlint release once available:

   ```bash
   bash <(curl -s https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)
   ./actionlint -color
   ```
   
2. If no error for `workflows` appears, edit `lint-action.yml`:
   - Remove the `-ignore 'unknown permission scope "workflows"'` argument.
3. Remove the line referencing `sync-solution-choices.yml` from `.actionlintignore`.
4. Delete any obsolete explanatory comments in both workflow files.
5. Commit and open a PR titled: `chore: remove actionlint workflows permission workaround`.
6. Ensure the lint job passes without ignores.

## Risks / Notes

- Removing the ignore too early will fail CI; confirm with a local run first.
- If additional diagnostics appear after upgrading actionlint, address them rather than re-adding broad ignores.

## Clean-up Checklist

- [ ] Ignore flag removed
- [ ] `.actionlintignore` entry removed
- [ ] Comments updated/removed
- [ ] CI green
- [ ] PR merged

## Automation

A scheduled workflow `monitor-actionlint-permission.yml` runs weekly (and on manual dispatch) to probe the latest
actionlint without the ignore flag. When the diagnostic about the unknown `workflows` permission disappears, it
automatically opens (or updates) an issue titled:

`chore: remove actionlint workflows permission workaround`

That issue's body restates the clean-up steps so the workaround can be removed promptly.

## References

- `./.github/workflows/lint-action.yml`
- `./.github/workflows/sync-solution-choices.yml`
- `.actionlintignore`
- actionlint upstream: <https://github.com/rhysd/actionlint>
