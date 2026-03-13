#!/usr/bin/env bash
# sync.sh — syncs ~/.claude and project .claude dirs to a backup git repo
# Usage: BACKUP_REPO=/path/to/backup-repo bash sync.sh
#        bash sync.sh /path/to/backup-repo

set -euo pipefail

# ── Resolve backup repo path ─────────────────────────────────────────────────
BACKUP_REPO="${BACKUP_REPO:-${1:-}}"
if [ -z "$BACKUP_REPO" ]; then
  echo "Error: BACKUP_REPO not set."
  echo "Usage: BACKUP_REPO=/path/to/backup bash sync.sh"
  exit 1
fi

# Expand tilde if present
BACKUP_REPO="${BACKUP_REPO/#\~/$HOME}"

if [ ! -d "$BACKUP_REPO" ]; then
  echo "Error: $BACKUP_REPO does not exist."
  exit 1
fi

# ── Load user project config ──────────────────────────────────────────────────
CONFIG="$BACKUP_REPO/config.local.sh"
if [ ! -f "$CONFIG" ]; then
  echo "Error: config.local.sh not found in $BACKUP_REPO"
  echo "Copy config.example.sh from the tool repo to $BACKUP_REPO/config.local.sh and edit it."
  exit 1
fi
# shellcheck source=/dev/null
source "$CONFIG"

# ── Resolve tools ─────────────────────────────────────────────────────────────
GIT=$(command -v git || { echo "Error: git not found"; exit 1; })
RSYNC=$(command -v rsync || { echo "Error: rsync not found"; exit 1; })

# ── Sync global ~/.claude ────────────────────────────────────────────────────
if [ -d "$HOME/.claude" ]; then
  $RSYNC -a --delete "$HOME/.claude/" "$BACKUP_REPO/global/"
  echo "Synced ~/.claude"
else
  echo "Warning: ~/.claude not found, skipping global sync."
fi

# ── Sync project .claude dirs ─────────────────────────────────────────────────
for entry in "${PROJECTS[@]:-}"; do
  name="${entry%%:*}"
  path="${entry##*:}"
  path="${path/#\~/$HOME}"

  if [ -d "$path/.claude" ]; then
    mkdir -p "$BACKUP_REPO/projects/$name"
    $RSYNC -a --delete "$path/.claude/" "$BACKUP_REPO/projects/$name/"
    echo "Synced $name"
  else
    echo "Warning: .claude not found at $path — skipping $name"
  fi
done

# ── Git commit and push ───────────────────────────────────────────────────────
cd "$BACKUP_REPO"
$GIT add -A

if $GIT diff --cached --quiet; then
  echo "Nothing changed, skipping commit."
else
  BRANCH=$($GIT rev-parse --abbrev-ref HEAD)
  $GIT commit -m "sync $(date '+%Y-%m-%d %H:%M')"
  $GIT push --set-upstream origin "$BRANCH"
  echo "Synced and pushed to $BRANCH."
fi