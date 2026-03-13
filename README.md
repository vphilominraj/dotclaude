# dotclaude

Automated backup tool for your Claude Code configuration — global `~/.claude` and per-project `.claude` directories — synced to your own private git repo.

Works on **macOS** and **Linux**, with **zsh** and **bash**.

---

## How it works

Two repos, clear separation:

| Repo | Visibility | Purpose |
|---|---|---|
| `dotclaude` (this repo) | Public | Sync logic and setup script — reusable by anyone |
| your backup repo (e.g. `my-claude-config`) | Private | Your actual config files — never shared |

```
~/.claude/                        → my-claude-config/global/
~/workspace/my-project/.claude/   → my-claude-config/projects/my-project/
```

---

## Setup (one time)

```bash
git clone https://github.com/<you>/dotclaude.git
cd dotclaude
bash setup.sh
```

`setup.sh` will:
1. Ask where your backup repo should live (default: `~/my-claude-config`)
2. Create the directory and run `git init`
3. Optionally create the GitHub repo via `gh` CLI (private by default)
4. Copy `config.example.sh` → `my-claude-config/config.local.sh` for you to edit
5. Add a `claude-sync` alias to your `.zshrc` / `.bashrc`
6. Add an hourly cron job

---

## Add your projects

Edit `config.local.sh` in your backup repo:

```bash
PROJECTS=(
  "my-project:~/workspace/my-project"
  "another-project:/absolute/path/to/another-project"
)
```

Then run your first sync:

```bash
source ~/.zshrc   # or ~/.bashrc
claude-sync
```

---

## Usage

```bash
claude-sync          # manual sync from anywhere
```

Cron runs automatically every hour. Logs → `sync.log` in your backup repo.

---

## Adding a new project later

Add an entry to `config.local.sh` in your backup repo — nothing else to change.

---

## Requirements

- `git`
- `rsync`
- `gh` CLI (optional — for auto-creating the GitHub backup repo during setup)