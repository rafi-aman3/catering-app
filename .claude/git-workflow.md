# Git Workflow

How we use git on this project. Keep this short — when in doubt, follow it; when the rule clearly doesn't fit, ask before improvising.

---

## Branching

- `main` is always deployable. No direct commits.
- Work happens on short-lived feature branches off `main`.
- Branch names use a type prefix and kebab-case:
  - `feat/...` — new feature
  - `fix/...` — bug fix
  - `chore/...` — tooling, deps, configs
  - `refactor/...` — no behavior change
  - `docs/...` — docs only
  - `test/...` — tests only
- Examples: `feat/daily-poll-cutoff`, `fix/billing-pdf-currency`, `chore/eslint-flat-config`.
- One concern per branch. If the diff grows two heads, split it.
- Delete the branch (locally and on remote) once the PR is merged.

## Commits

- Conventional Commits style: `type(scope): subject`.
  - Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`, `build`, `ci`.
  - Scope is optional but encouraged: `feat(billing): add monthly PDF export`.
- Subject in the imperative mood, lowercase, no trailing period, under 72 chars.
- Body (optional) explains *why*, not *what*. Wrap at 100 chars.
- Reference an issue in the footer if relevant: `Refs #42`, `Closes #42`.
- Never amend or force-push a branch that someone else might have pulled.
- Never use `--no-verify` to skip hooks. If a hook fails, fix the cause.

### Examples

```
feat(poll): enforce 10am cutoff and auto-skip unmarked members

The cron job now writes a 'skip' entry for any member without a response
once the workspace cutoff passes, then locks the meal_day. Recurring
schedules (added in M5) will override this default.

Refs #18
```

```
fix(billing): preserve BDT thousands separator in PDF export
```

## Pull Requests

- Open early as a draft if you want feedback before the work is done.
- Title matches the merge commit you'd want — Conventional Commits style.
- Description includes:
  - **Summary** — 1–3 bullets of *what* and *why*.
  - **Test plan** — checklist of how it was verified (unit tests, manual mobile viewport check, etc.). UI changes need a manual exercise note per `AGENTS.md`.
  - **Screenshots** for UI changes (mobile + desktop if both apply).
  - **Spec impact** — link to the section of `SPEC.md` and update the spec in the same PR if the behavior diverges.
- Keep PRs small. Aim for under ~400 lines of diff. Big migrations get a "split-up plan" note in the description.
- Self-review the diff before requesting review.
- CI must be green before merge.
- Merge style: **squash and merge**. The PR title becomes the squashed commit subject.
- Resolve review threads with a reply ("done", "wontfix because…"), don't just dismiss.

## Rebase vs. Merge

- Update a feature branch by **rebasing onto `main`**, not merging `main` in.
- Resolve conflicts on the feature branch; never with merge commits inside the feature branch.
- After rebase, force-push with `--force-with-lease` (never `--force`).

## Database Migrations

- One Supabase migration file per logical change.
- Migration filenames are timestamped and descriptive: `20260503_add_recurring_schedules.sql`.
- **Never edit a committed migration.** Add a new one to fix or extend.
- Each migration must:
  - Be idempotent where reasonable (`if not exists`).
  - Include the matching RLS policy changes for any new workspace-scoped table.
  - Be tested locally against a fresh DB before the PR.

## Secrets & .env

- `.env.local` is git-ignored. Never commit it.
- Update `.env.example` whenever a new env var is introduced. Use a placeholder value, never a real secret.
- Service-role keys only on the server (Vercel env). Never `NEXT_PUBLIC_*`.
- If a secret leaks: rotate first, then squash/force-push history only with explicit approval — and assume the leaked value is already compromised.

## Releases & Deploys

- Vercel auto-deploys `main` to production and PR branches to preview URLs.
- Tag releases as `vMAJOR.MINOR.PATCH` once the MVP ships (semver from then on).
- Keep `CHANGELOG.md` (added when the first release is cut) human-readable, grouped by Added / Changed / Fixed / Removed.

## Things to Never Do Without Explicit Approval

- Force-push to `main`.
- `git reset --hard` on a branch with unpushed work that isn't yours.
- Delete a remote branch you didn't create.
- Skip pre-commit hooks (`--no-verify`).
- Commit `.env.local`, service-role keys, customer data, or generated `.next/` artifacts.
- Push directly to `main`.

## Quick Reference

```bash
# start a feature
git checkout main && git pull --rebase
git checkout -b feat/poll-cutoff

# keep up to date with main
git fetch origin
git rebase origin/main
# resolve, then:
git push --force-with-lease

# open a PR
gh pr create --draft --title "feat(poll): enforce 10am cutoff" --body-file .github/pr-body.md

# clean up after merge
git checkout main && git pull --rebase
git branch -d feat/poll-cutoff
git push origin --delete feat/poll-cutoff
```
