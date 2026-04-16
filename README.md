# thornboo-dev-config

My personal dotfiles repository for AI tooling, terminal setup, and agent workflows.

This repo is not just a backup of a few AI app configs. It is the home for my personal machine-level dotfiles and global tooling preferences, with a small sync layer that keeps portable config in Git and keeps local secrets, logs, sessions, and machine-specific state out of the repo.

中文说明见 `README.zh-CN.md`.

## Overview

The repository is intentionally split into two layers:

- `backup/` contains the checked-in, portable snapshots of my personal global config
- the repo root contains the sync scripts, tests, and documentation for managing those snapshots

That separation makes it easier to understand what is **project code** versus what is **backed-up personal dotfiles**.

## Structure

```text
thornboo-dev-config/
├── backup/                 # Backed-up personal dotfiles and global config
│   ├── claude/             # Portable subset of ~/.claude/
│   ├── codex/              # Portable subset of ~/.codex/
│   ├── gemini/             # Portable subset of ~/.gemini/
│   ├── home/AGENTS.md      # Backup of ~/AGENTS.md, not this repo's dev guide
│   ├── kitty/              # Kitty config snapshot
│   ├── snow/               # Portable subset of ~/.snow/
│   └── zsh/.zshrc          # Backup of ~/.zshrc
├── scripts/                # Sync, redaction, and merge logic
├── tests/                  # Regression tests for sync behavior
├── update                  # Pull local config into backup/
├── use                     # Apply backup/ config back to the local machine
├── sync.sh                 # Compatibility entrypoint, forwards to ./update
├── README.md               # English overview
├── README.zh-CN.md         # Chinese overview
└── .gitignore
```

> `backup/home/AGENTS.md` is a backed-up global file from my home directory. It is not the development instructions for this repository.

## Managed Targets

The sync layer currently manages these global targets:

- `claude` — Claude Code global config
- `codex` — Codex global config
- `gemini` — Gemini CLI global config
- `zshrc` — Zsh user config
- `kitty` — Kitty terminal config
- `snow` — Snow global config
- `agents` — global `~/AGENTS.md`

## Commands

### Update backups

```bash
# Backup everything
./update

# Backup selected targets
./update claude
./update codex kitty
./update zshrc

# Preview only
./update --dry-run codex

# Plain-text logs
./update --no-emoji codex
```

### Apply backups locally

```bash
# Apply selected targets back to the machine
./use claude
./use codex
./use zshrc
./use kitty

# Preview only
./use --dry-run codex

# Plain-text logs
./use --no-emoji codex
```

Notes:

- `use` supports `claude`, `codex`, `gemini`, `zshrc`, `kitty`, `snow`, and `agents`
- sensitive files such as `auth.json` and `.env` are skipped by default
- when a checked-in file contains a sanitized placeholder, `use` tries to merge local secret values back from the existing machine file

## Security Model

This repository is designed to be reviewable in Git without exposing real secrets or local privacy-sensitive state.

### What the sync layer does

- **Redacts secrets** in config-like files such as JSON, TOML, INI, shell env assignments, and URL query params
- **Uses `YOUR-API-KEY`** as the visible placeholder for redacted secret values
- **Merges local secrets back** during `use` when the checked-in file contains `YOUR-API-KEY`
- **Skips sensitive files** such as `auth.json`, `.env`, `credentials.json`, and `tokens.json` during restore
- **Excludes local runtime state** such as sessions, logs, caches, sqlite files, and machine-specific path registries

### What is intentionally excluded

Examples of files that should not be tracked in this repo:

- Claude session transcripts and brainstorm runtime data
- command logs and cost logs
- Gemini `trustedFolders.json`
- local `.env` files
- Codex `auth.json`
- install-state or machine-bound runtime databases

Example checked-in value:

```bash
ANTHROPIC_AUTH_TOKEN=YOUR-API-KEY
```

That means “this file is portable, but the real secret belongs on the local machine”.

## Backup Policy

Only portable, reusable config is backed up. Runtime data, local history, logs, caches, and private path metadata are excluded.

| Target | Included | Excluded |
|------|---------|---------|
| Claude Code | global config, rules, skills, themes, plugin metadata | sessions, `session-data`, history, caches, brainstorm runtime data, logs, telemetry, install state |
| Codex | global config, prompts, rules, user skills, versioned metadata | `auth.json`, sessions, logs, sqlite state, temp dirs |
| Gemini | non-sensitive global config | `.env`, `trustedFolders.json`, history, temp state |
| Zsh | `.zshrc` with secrets redacted | no extra scanning |
| Kitty | `kitty.conf` and related config files | `.DS_Store`, `*.bak`, `*.backup` |
| Snow | global config and profiles with secrets redacted | history, logs, sessions, snapshots, notebook/runtime state |
| AGENTS | `~/AGENTS.md` | none |

## Local ↔ Repo Mapping

| Target | Local path | Repo path |
|------|-----------|-----------|
| `claude` | `~/.claude/` | `backup/claude/` |
| `codex` | `~/.codex/` | `backup/codex/` |
| `gemini` | `~/.gemini/` | `backup/gemini/` |
| `zshrc` | `${ZDOTDIR:-$HOME}/.zshrc` | `backup/zsh/.zshrc` |
| `kitty` | `KITTY_CONFIG_DIRECTORY` or platform default Kitty config dir | `backup/kitty/` |
| `snow` | `~/.snow/` | `backup/snow/` |
| `agents` | `~/AGENTS.md` | `backup/home/AGENTS.md` |

## Run Records

Each `update` or `use` run writes local audit records under `sync-records/`:

- `sync-records/latest.log`
- `sync-records/latest-summary.txt`
- `sync-records/history.log`
- `sync-records/history.jsonl`
- `sync-records/conflicts.log`

These records stay local to the working copy and are ignored by Git.

## Future Improvements

Possible next steps:

- add `--backup` to `use` so local files are snapshotted before overwrite
- add `--strict-audit` to `update` for a pre-commit privacy scan
- add more target-specific rules as new local tools are adopted
