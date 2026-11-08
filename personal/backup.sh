#!/usr/bin/env bash
#
# Snapshot the learning data: ~/LearnHarnessData/data → backups/<time>-<label>.tgz
#
#   personal/backup.sh               # label "manual"
#   personal/backup.sh pre-change    # any label
#
# "auto" snapshots (taken by every launch) are rotated, newest 30 kept.
# Every other label is kept forever. auth.json is NOT included — keys
# are re-enterable, and backups should not multiply copies of secrets.

set -euo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$HERE/env.sh"

LABEL="${1:-manual}"
[[ "$LABEL" =~ ^[A-Za-z0-9._-]+$ ]] || die "label must be [A-Za-z0-9._-]"

if [ ! -d "$LH_DATA_DIR" ] || [ -z "$(ls -A "$LH_DATA_DIR")" ]; then
	echo "backup: no data yet — nothing to snapshot"
	exit 0
fi
if [ "$LABEL" != "auto" ] && lh_running; then
	echo "warning: the app is running; the snapshot may catch a write in progress" >&2
fi

mkdir -p "$LH_HOME/backups"
chmod 700 "$LH_HOME/backups"
OUT="$LH_HOME/backups/$(date +%Y%m%d-%H%M%S)-$LABEL.tgz"
tar czf "$OUT.tmp" -C "$LH_HOME" data
chmod 600 "$OUT.tmp"
mv "$OUT.tmp" "$OUT"

if [ "$LABEL" = "auto" ]; then
	ls -1t "$LH_HOME"/backups/*-auto.tgz 2>/dev/null | tail -n +31 | while read -r old; do rm -f "$old"; done
fi
echo "backup: $OUT"
