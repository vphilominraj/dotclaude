#!/usr/bin/env bash
# setup.sh — one-time setup for dotclaude
# Run once after cloning the tool repo.
# Creates your private backup repo, wires up the alias and cron.

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
echo "║         dotclaude — Setup            ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Detected shell: $SHELL_NAME (rc file: $RC_FILE)"
echo ""

# ── Backup repo location ──────────────────────────────────────────────────────
BACKUP_REPO=$(ask "Path where your private backup repo should live" "~/my-claude-config")
BACKUP_REPO=$(expand_path "$BACKUP_REPO")

# ── Create backup repo if needed ──────────────────────────────────────────────
GIT=$(command -v git || { echo "Error: git not found"; exit 1; })

if [ ! -d "$BACKUP_REPO" ]; then
  echo ""
  echo "Creating backup repo at $BACKUP_REPO..."
  mkdir -p "$BACKUP_REPO"
  cd "$BACKUP_REPO"
  $GIT init

  # Offer to create GitHub repo
  if command -v gh &>/dev/null; then
    echo ""
    REPO_NAME=$(ask "GitHub repo name for your backup" "my-claude-config")
    VISIBILITY=$(ask "Visibility (private/public)" "private")
    gh repo create "$REPO_NAME" "--$VISIBILITY" --source=. --remote=origin
    echo "GitHub repo created: $REPO_NAME ($VISIBILITY)"
  else
    echo "gh CLI not found — skipping GitHub repo creation."
    echo "You can create the remote manually and run: git remote add origin <url>"
  fi
else
  echo "Backup repo already exists at $BACKUP_REPO"
  cd "$BACKUP_REPO"
fi

# ── Create .gitignore in backup repo if missing ───────────────────────────────
GITIGNORE="$BACKUP_REPO/.gitignore"
if [ ! -f "$GITIGNORE" ]; then
  cat > "$GITIGNORE" <<'EOF'
# macOS
.DS_Store

# User project config — never commit this
config.local.sh

# Claude runtime/cache — not worth backing up
global/cache/
global/history.jsonl
global/projects/
global/shell-snapshots/
global/session-env/
global/paste-cache/
global/file-history/
global/stats-cache.json
global/statsig/
global/debug/
global/backups/
global/ide/

# Embedded git repos (plugins have their own .git)
global/plugins/
EOF
  echo "Created .gitignore in backup repo."
fi

# ── Create config.local.sh in backup repo if missing ─────────────────────────
LOCAL_CONFIG="$BACKUP_REPO/config.local.sh"
if [ ! -f "$LOCAL_CONFIG" ]; then
  cp "$TOOL_DIR/config.example.sh" "$LOCAL_CONFIG"
  echo ""
  echo "Created $LOCAL_CONFIG from example."
  echo "Edit it to add your project paths, then run 'claude-sync' to do your first sync."
fi

# ── Add alias to shell rc ─────────────────────────────────────────────────────
ALIAS_LINE="alias claude-sync='BACKUP_REPO=\"$BACKUP_REPO\" /usr/bin/env bash \"$SYNC_SCRIPT\"'"

if grep -q "claude-sync" "$RC_FILE" 2>/dev/null; then
  echo ""
  echo "Alias already exists in $RC_FILE — skipping."
else
  {
    echo ""
    echo "# Claude config backup"
    echo "$ALIAS_LINE"
  } >> "$RC_FILE"
  echo "Added 'claude-sync' alias to $RC_FILE"
fi

# ── Add cron job ──────────────────────────────────────────────────────────────
LOG_FILE="$BACKUP_REPO/sync.log"
CRON_CMD="0 * * * * BACKUP_REPO=\"$BACKUP_REPO\" /usr/bin/env bash \"$SYNC_SCRIPT\" >> \"$LOG_FILE\" 2>&1"

if crontab -l 2>/dev/null | grep -q "$SYNC_SCRIPT"; then
  echo "Cron job already exists — skipping."
else
  (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
  echo "Added hourly cron job (logs → $LOG_FILE)"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "✓ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit $LOCAL_CONFIG to add your projects"
echo "  2. Run: source $RC_FILE"
echo "  3. Run: claude-sync"
echo ""