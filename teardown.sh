#!/usr/bin/env bash
# teardown.sh — undoes everything setup.sh did
# Usage: bash teardown.sh

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_SCRIPT="$TOOL_DIR/sync.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────
ask() {
  local prompt="$1" default="${2:-}" answer
  if [ -n "$default" ]; then
    read -rp "$prompt [$default]: " answer
    echo "${answer:-$default}"
  else
    read -rp "$prompt: " answer
    echo "$answer"
  fi
}

expand_path() {
  echo "${1/#\~/$HOME}"
}

confirm() {
  local prompt="$1" answer
  read -rp "$prompt [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# ── Detect shell ──────────────────────────────────────────────────────────────
SHELL_NAME=$(basename "$SHELL")
case "$SHELL_NAME" in
  zsh)  RC_FILE="$HOME/.zshrc"  ;;
  bash) RC_FILE="$HOME/.bashrc" ;;
  *)
    echo "Unsupported shell: $SHELL_NAME. Set RC_FILE manually and re-run."
    exit 1
    ;;
esac

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       dotclaude — Teardown           ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "This will undo everything setup.sh did."
echo ""

# ── Backup repo location ──────────────────────────────────────────────────────
BACKUP_REPO=$(ask "Path to your backup repo" "~/my-claude-config")
BACKUP_REPO=$(expand_path "$BACKUP_REPO")

# ── Remove cron job ───────────────────────────────────────────────────────────
if crontab -l 2>/dev/null | grep -q "$SYNC_SCRIPT"; then
  crontab -l 2>/dev/null | grep -v "$SYNC_SCRIPT" | crontab -
  echo "Removed cron job."
else
  echo "No cron job found — skipping."
fi

# ── Remove alias from shell rc ────────────────────────────────────────────────
if grep -q "claude-sync" "$RC_FILE" 2>/dev/null; then
  # Remove the alias line and the comment above it
  grep -v "claude-sync" "$RC_FILE" > "$RC_FILE.tmp" || true
  grep -v "# Claude config backup" "$RC_FILE.tmp" > "$RC_FILE.tmp2" || true
  mv "$RC_FILE.tmp2" "$RC_FILE"
  rm -f "$RC_FILE.tmp"
  echo "Removed 'claude-sync' alias from $RC_FILE."
else
  echo "No alias found in $RC_FILE — skipping."
fi

# ── GitHub repo ───────────────────────────────────────────────────────────────
if [ -d "$BACKUP_REPO/.git" ]; then
  REMOTE_URL=$(git -C "$BACKUP_REPO" remote get-url origin 2>/dev/null || true)
  if [ -n "$REMOTE_URL" ]; then
    echo ""
    echo "NOTE: GitHub repo remote detected: $REMOTE_URL"
    echo "      Delete it manually at: https://github.com → repo Settings → Danger Zone → Delete repository"
  fi
fi

# ── Delete local backup repo ──────────────────────────────────────────────────
echo ""
if [ -d "$BACKUP_REPO" ]; then
  if confirm "Delete local backup repo at $BACKUP_REPO?"; then
    rm -rf "$BACKUP_REPO"
    echo "Deleted $BACKUP_REPO."
  else
    echo "Skipping local repo deletion."
  fi
else
  echo "Backup repo not found at $BACKUP_REPO — skipping."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "Teardown complete."
echo "Run: source $RC_FILE  to apply shell changes."
echo ""
