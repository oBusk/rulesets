# rulesets

GitHub rulesets I import as defaults into my own repos.

## Repo types I'm targeting

- **Site repos** — Next.js apps deployed to Vercel directly from `main`.
- **Package repos** — Published to npm via a GitHub Actions workflow (with provenance), triggered either by a `v*` tag I push or by release-please, which tags monorepo packages as `pkg@v1.2.3` / `@scope/pkg@v1.2.3`.

Both share the same defaults (base + tag protection). The split exists only because GitHub rulesets can't target branches and tags in the same file.

## The rulesets

| File | What it does | Apply to |
| --- | --- | --- |
| [main-branch-base.json](main-branch-base.json) | On `main`: no force-push, no deletion, linear history and signed commits required. No admin bypass — applies to me too. | All repos |
| [tag-protection.json](tag-protection.json) | On release tags (`v*`, `pkg@*`, `@scope/pkg@*`): cannot be deleted, moved, or force-pushed, and must point at signed commits. Protects published releases from being rewritten. Dormant on repos without such tags, so safe to import everywhere. | All repos |
| [require-pr.json](require-pr.json) | Requires a PR into `main` (0 approvals needed), squash merge only. Admin bypass enabled so I can still push directly when I want to. | Opt-in only |

The base + tag rulesets together are the default for any repo. The PR-required ruleset is opt-in and has admin bypass — I don't want to force PRs on solo work.

A ruleset has a single `target` (branch *or* tag), so branch rules and tag rules can't be merged into one file — that's the only reason these are separate.

Rulesets only work on public repos, or private repos on GitHub Pro. On a free account, private repos reject them.

## Importing into a repo

An imported ruleset is a copy — changing the JSON here doesn't update repos it was imported into. [sync.sh](sync.sh) creates or updates rulesets by name, so rerun it after changing anything here. Needs `gh` and `jq`.

```sh
./sync.sh OWNER/REPO                  # base + tag protection, plus require-pr if the repo already has it
./sync.sh OWNER/REPO require-pr.json  # opt a repo in to require-pr
```

It also lists any `unmanaged` rulesets in the repo (e.g. older hand-made ones). Those keep applying alongside these, so review and delete them by hand.

In the GitHub UI:

1. Repo → **Settings → Rules → Rulesets**.
2. **New ruleset → Import a ruleset**.
3. Upload the JSON file.
4. Confirm enforcement is **Active**.

## Notes

- `~DEFAULT_BRANCH` targets whatever the repo's default branch is, so these work regardless of `main` vs `master`.
- Tag patterns use `fnmatch`, where `*` doesn't match `/`. That's why scoped package tags (`@scope/pkg@v1.2.3`) need their own `refs/tags/@*/*@*` pattern next to `refs/tags/*@*`. Adjust if your release tags look different.
- **Signed commits** cause the most friction. GitHub checks every commit on a PR's head branch, so a single unsigned commit blocks the merge, even a squash. There's no bypass, so either the author re-signs their commits, or I squash locally, sign, and push to `main` directly (allowed through the require-pr admin bypass). Dependabot, Copilot, Claude, and release-please commits all come out verified.
- `require-pr.json` only allows `squash`. Merge commits break linear history, and GitHub can't sign the commits it rewrites during **Rebase and merge**, so those get rejected by the signed-commits rule.
- Because force pushes are blocked with no bypass, renaming the default branch requires temporarily disabling **main branch base**.
- The tag ruleset also requires matching tags to look like versions (`v1.2.3`, `pkg@v1.2.3`, `@scope/pkg@1.2.3`). Name patterns are GitHub Enterprise only, so a personal account silently drops this rule on import. It's kept so the ruleset is complete if it ever lands somewhere that enforces it.
- Required status checks aren't included because check names differ per repo. Add them per repo before turning on auto-merge, otherwise auto-merge merges immediately.

## Recommended repo settings

Settings that complement the rulesets but can't be expressed in ruleset JSON.

**Settings → General → Pull Requests:**
- Uncheck **Allow merge commits** and **Allow rebase merging** — both get rejected by the base ruleset anyway (linear history, signed commits), but this removes them from the UI entirely
- Check **Automatically delete head branches**

**Settings → General → Releases:**
- Check **Enable release immutability** — once a release is published, its tag and assets can't be changed or deleted. Create releases as drafts, attach assets, then publish; workflows that upload assets to an already published release will fail.

**Settings → Security:**
- Enable **Secret scanning** + **Push protection** — catches committed credentials; push protection blocks them before they land
- Enable **Dependabot security alerts** + **Dependabot security updates** — low noise, automatically patches known vulnerabilities

**For public repos — Settings → Security → Private vulnerability reporting:**
- Enable **Private vulnerability reporting** — lets people report security issues without public disclosure
