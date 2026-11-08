#!/usr/bin/env bash
#
# Deploy a commit to the live worktree the app runs from.
#
#   personal/deploy.sh          # deploy branch "mine"
#   personal/deploy.sh <ref>    # any commit/tag (also how to roll back)
#
# Steps: refuse while the app runs → snapshot data → check out <ref>
# (detached) in ../learnharness-live → npm ci if the lockfile changed →
# next build → boot smoke on a scratch data dir → log. Any failure rolls
# the live worktree back to the previous commit and rebuilds it.
# Real learning data is never read or written by the build or smoke.

set -euo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$HERE/env.sh"
DEV="$(git -C "$HERE" rev-parse --show-toplevel)"
LIVE="${LH_LIVE_DIR:-$(dirname "$(git -C "$DEV" rev-parse --path-format=absolute --git-common-dir)")/../learnharness-live}"

REF="${1:-mine}"
SHA="$(git -C "$DEV" rev-parse --verify "$REF^{commit}")" || die "unknown ref: $REF"
lh_running && die "quit LearnHarness first"

"$HERE/backup.sh" "pre-deploy-${SHA:0:7}"

PREV=""
if [ -d "$LIVE" ]; then
	LIVE="$(cd "$LIVE" && pwd)"
	PREV="$(git -C "$LIVE" rev-parse HEAD)"
	# The live worktree is never edited by hand; build byproducts only.
	git -C "$LIVE" reset -q --hard
	git -C "$LIVE" checkout -q --detach "$SHA"
else
	git -C "$DEV" worktree add -q --detach "$LIVE" "$SHA"
	LIVE="$(cd "$LIVE" && pwd)"
fi

build() {
	local lockhash
	lockhash="$(shasum -a 256 "$LIVE/package-lock.json" | cut -d' ' -f1)"
	if [ "$(cat "$LIVE/node_modules/.lh-lockhash" 2>/dev/null)" != "$lockhash" ]; then
		# Explicit returns: set -e is off inside the `if !` that calls this.
		(cd "$LIVE" && npm ci) || return 1
		echo "$lockhash" >"$LIVE/node_modules/.lh-lockhash"
	fi
	(cd "$LIVE" && npm run build) || return 1
}

smoke() {
	local scratch port=3199 pid ok=1
	scratch="$(mktemp -d)"
	echo '{}' >"$scratch/auth.json"
	(cd "$LIVE" && LH_DATA_DIR="$scratch/data" LH_AUTH_FILE="$scratch/auth.json" LH_IGNORE_ENV_KEYS=1 \
		node_modules/.bin/next start -H 127.0.0.1 -p "$port" >"$scratch/server.log" 2>&1) &
	pid=$!
	for _ in $(seq 120); do
		if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/")" = "200" ]; then
			ok=0
			break
		fi
		sleep 0.5
	done
	kill "$pid" 2>/dev/null || true
	lsof -nP -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | xargs kill 2>/dev/null || true
	[ $ok -eq 0 ] || cat "$scratch/server.log" >&2
	rm -rf "$scratch"
	return $ok
}

if ! { build && smoke; }; then
	if [ -n "$PREV" ]; then
		echo "deploy of ${SHA:0:7} FAILED — rolling back to ${PREV:0:7}" >&2
		git -C "$LIVE" reset -q --hard
		git -C "$LIVE" checkout -q --detach "$PREV"
		build || die "rollback build failed too — the live worktree needs attention"
	fi
	die "deploy of ${SHA:0:7} failed"
fi

# Launchers: `lh` on PATH, and a Finder/Dock app.
mkdir -p "$HOME/.local/bin" "$HOME/Applications"
ln -sf "$LIVE/personal/lh" "$HOME/.local/bin/lh"
APP="$HOME/Applications/LearnHarness Mine.app"
if [ ! -d "$APP" ]; then
	osacompile -o "$APP" -e "do shell script quoted form of \"$HOME/.local/bin/lh\" & \" >/dev/null 2>&1 &\""
fi

mkdir -p "$LH_HOME"
echo "$(date '+%Y-%m-%d %H:%M:%S') ${SHA:0:12} $(git -C "$DEV" describe --tags --always "$SHA") (prev ${PREV:0:12})" >>"$LH_HOME/deployments.log"
echo "deployed ${SHA:0:7} → $LIVE"
