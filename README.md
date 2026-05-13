# rulesets

GitHub rulesets I import as defaults into my own repos.

## Repo types I'm targeting

- **Site repos** — Next.js apps deployed to Vercel directly from `main`.
- **Package repos** — Published to npm via a GitHub Actions workflow triggered on `v*` tags (with provenance).

Both share the same defaults (base + tag protection). The split exists only because GitHub rulesets can't target branches and tags in the same file.

## The rulesets

| File | What it does | Apply to |
| --- | --- | --- |
| [main-branch-base.json](main-branch-base.json) | On `main`: no force-push, no deletion, linear history required. No admin bypass — applies to me too. | All repos |
| [tag-protection.json](tag-protection.json) | On `v*` tags: cannot be deleted, moved, or force-pushed. Protects published releases from being rewritten. Dormant on repos that don't use `v*` tags, so safe to import everywhere. | All repos |
| [require-pr.json](require-pr.json) | Requires a PR into `main` (0 approvals needed). Admin bypass enabled so I can still push directly when I want to. | Opt-in only |

The base + tag rulesets together are the default for any repo. The PR-required ruleset is opt-in and has admin bypass — I don't want to force PRs on solo work.

A ruleset has a single `target` (branch *or* tag), so branch rules and tag rules can't be merged into one file — that's the only reason these are separate.

## Importing into a repo

In the GitHub UI:

1. Repo → **Settings → Rules → Rulesets**.
2. **New ruleset → Import a ruleset**.
3. Upload the JSON file.
4. Confirm enforcement is **Active**.

Via `gh`:

```sh
gh api -X POST /repos/OWNER/REPO/rulesets --input main-branch-base.json
```

## Notes

- `~DEFAULT_BRANCH` targets whatever the repo's default branch is, so these work regardless of `main` vs `master`.
- The tag ruleset matches `refs/tags/v*` — adjust if your release tags use a different prefix.
- `require-pr.json` keeps `allowed_merge_methods` to `squash` and `rebase` only, since the base ruleset enforces linear history (merge commits would be rejected anyway).
