# Maintaining this personal LearnHarness

This fork (`github.com/nitin35/learnharness`) is the owner's working copy of
upstream `amosblomqvist/learnharness`, maintained by Claude. Three jobs:
deploy it, update it from upstream **when the owner asks** (not per commit),
and make the changes the owner requests. **The overriding rule: never lose
or damage the learning data.**

## Layout

| What | Where |
| --- | --- |
| Dev checkout (edit, test, rebase here) | `~/work/learn_harness/learnharness`, branch `mine` |
| Live worktree (the app runs from it; never edit by hand) | `~/work/learn_harness/learnharness-live`, detached at the deployed commit |
| Learning data | `~/LearnHarnessData/data/` (`LH_DATA_DIR`) |
| Keys | `~/LearnHarnessData/auth.json` (`LH_AUTH_FILE`) |
| Snapshots | `~/LearnHarnessData/backups/*.tgz` |
| Logs, deploy history | `~/LearnHarnessData/logs/`, `~/LearnHarnessData/deployments.log` |
| Launchers | `lh` (`~/.local/bin`) and `~/Applications/LearnHarness Mine.app` |

Git: `origin` = the fork, `upstream` = amosblomqvist (push disabled).
`main` mirrors upstream untouched; every personal change is a commit on
`mine`. All personal tooling lives in `personal/` so rebases don't conflict.

## Data-safety rules

1. **Only the live app touches `~/LearnHarnessData/data`.** Dev servers,
   tests, smokes and experiments use scratch data: `npm run dev:fresh`
   (port 3005, wiped) / `npm run dev:fresh -- --keep`, or
   `LH_DATA_DIR=$(mktemp -d) LH_AUTH_FILE=… npm run dev -- --port 3001`.
   Never set `LH_DATA_DIR` to the real data from the dev checkout.
2. **One server per data dir.** `deploy.sh`/`restore.sh` refuse while the
   app runs; ask the owner to quit it (Cmd-Q) first.
3. **Snapshot before anything risky.** Every launch takes an `auto`
   snapshot (newest 30 kept); every deploy takes a permanent
   `pre-deploy-<sha>` one. Manual: `personal/backup.sh <label>`.
4. **Format upgrades are one-way.** Chats/graph files carry version stamps
   and older code refuses newer stamps. So a code rollback after a data
   format bump also needs `personal/restore.sh <pre-deploy snapshot>`
   (it moves the current data aside, never deletes). Read upstream
   changes to `src/store/`, `src/core/` and golden fixtures before deploying.
5. Never commit `data/`, `auth.json`, credentials, or anything from
   `~/LearnHarnessData`. Never delete backups or `data.before-restore-*`
   without the owner's say-so.

## Updating from upstream (when the owner asks)

```sh
cd ~/work/learn_harness/learnharness
git fetch upstream --tags
git log --oneline mine..upstream/main          # what's coming; read storage/format changes
git checkout main && git merge --ff-only upstream/main && git push origin main
git checkout mine && git rebase main           # resolve conflicts; keep personal commits small
npm ci && npm run typecheck && npm run lint && npm test   # all offline, fake providers
# optional: npm run dev:fresh  → poke the UI on scratch data
git push --force-with-lease origin mine
personal/deploy.sh                              # owner must have quit the app
```

Prefer a release tag (`git rebase v0.6.0` instead of `main`) when the owner
wants stability over latest. If upstream rewrites history, stop and tell the
owner. Report what changed in plain words (features, anything affecting
their lessons) after deploying.

## Making a requested change

1. Read the relevant docs/code first (`docs/architecture.md`,
   `src/agent/prompts/README.md`, and `AGENTS.md`: ask rather than guess
   on design decisions).
2. Prefer no-code routes: Settings, or prompt overrides
   (`~/LearnHarnessData/data/prompts/` + the `agent.prompts` switch in
   Settings). These need no deploy and never conflict on update.
3. Otherwise: one focused commit on `mine`, tests for it where the suite
   covers that area, full checks, try it on scratch data, push, deploy.
4. Changes touching storage formats need extra care: they can rewrite the
   owner's files. Take a labelled snapshot and confirm with the owner.

## Rollback

```sh
tail ~/LearnHarnessData/deployments.log        # previous deployed commit
personal/deploy.sh <previous-sha>
# only if the data was upgraded by the bad version:
personal/restore.sh ~/LearnHarnessData/backups/<…>-pre-deploy-<bad-sha>.tgz
```

## How the app runs

`lh` starts `next start` (production build) on `127.0.0.1:3100` with the
data/auth env vars, then opens the Electron shell with
`LH_DEV_URL=http://127.0.0.1:3100`. It is deliberately not a packaged app:
a packaged build auto-updates from the official releases and would replace
this fork. Consequences: Electron's own ChatGPT sign-in is off, while the
server's web sign-ins (ChatGPT/Copilot/Grok), API keys, Claude Code, and
custom endpoints all work. Subscription credential files live beside
`auth.json`. The Electron profile (window state, localStorage) is
`~/Library/Application Support/LearnHarness-dev`, which `npm run desktop:dev`
in the dev checkout would also use, so don't run both at once.
Logs: `~/LearnHarnessData/logs/{server,electron}.log`.
