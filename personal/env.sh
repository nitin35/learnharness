# Shared settings for the personal/ scripts — sourced, not executed.
#
# Layout (see personal/MAINTAINING.md):
#   ~/LearnHarnessData/          LH_HOME — everything that must survive
#     data/                      LH_DATA_DIR — lessons, graph, settings, prompt overrides
#     auth.json                  LH_AUTH_FILE — keys (plaintext, 0600)
#     backups/                   tar snapshots of data/
#     logs/                      server/electron logs
#     deployments.log            one line per deploy
#   <repo>/../learnharness-live  the deployed worktree the app runs from

LH_HOME="${LH_HOME:-$HOME/LearnHarnessData}"
LH_PORT="${LH_PORT:-3100}"
LH_DATA_DIR="$LH_HOME/data"
LH_AUTH_FILE="$LH_HOME/auth.json"
LH_PIDFILE="$LH_HOME/run/lh.pid"

# Finder/Dock launches get a minimal PATH; node lives in Homebrew.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

die() {
	echo "error: $*" >&2
	exit 1
}

# True when the app (launcher or its server) is up — nothing may touch
# data/ or the live build while it is.
lh_running() {
	if [ -f "$LH_PIDFILE" ] && kill -0 "$(cat "$LH_PIDFILE")" 2>/dev/null; then
		return 0
	fi
	lsof -nP -iTCP:"$LH_PORT" -sTCP:LISTEN >/dev/null 2>&1
}
