#!/usr/bin/env bash
#
# Restore data/ from a snapshot. Never deletes: the current data/ is moved
# aside to data.before-restore-<time>/ first.
#
#   personal/restore.sh ~/LearnHarnessData/backups/20261108-120000-pre-deploy-abc1234.tgz

set -euo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$HERE/env.sh"

[ $# -eq 1 ] || die "usage: personal/restore.sh <backup.tgz>"
SNAPSHOT="$1"
[ -f "$SNAPSHOT" ] || die "no such file: $SNAPSHOT"
lh_running && die "quit LearnHarness first"
tar tzf "$SNAPSHOT" | grep -q '^data/' || die "$SNAPSHOT does not contain data/"

if [ -d "$LH_DATA_DIR" ]; then
	ASIDE="$LH_HOME/data.before-restore-$(date +%Y%m%d-%H%M%S)"
	mv "$LH_DATA_DIR" "$ASIDE"
	echo "restore: current data moved to $ASIDE"
fi
tar xzf "$SNAPSHOT" -C "$LH_HOME"
echo "restore: data/ restored from $SNAPSHOT"
