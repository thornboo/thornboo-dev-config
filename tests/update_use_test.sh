#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}

trap cleanup EXIT

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"

  [[ -f "$path" ]] || fail "Expected file to exist: $path"
}

assert_not_exists() {
  local path="$1"

  [[ ! -e "$path" ]] || fail "Expected path to be absent: $path"
}

assert_contains() {
  local path="$1"
  local expected="$2"

  rg -F --quiet "$expected" "$path" || fail "Expected '$expected' in $path"
}

assert_not_contains() {
  local path="$1"
  local unexpected="$2"

  if rg -F --quiet "$unexpected" "$path"; then
    fail "Did not expect '$unexpected' in $path"
  fi
}

copy_repo() {
  local destination="$1"

  mkdir -p "$destination"
  rsync -a \
    --exclude='.git/' \
    --exclude='.serena/' \
    "$REPO_ROOT/" "$destination/"
}


assert_history_jsonl_contains() {
  local repo_dir="$1"
  local expected_action="$2"

  python3 - "$repo_dir/sync-records/history.jsonl" "$expected_action" <<'PY_JSON'
import json
import sys
from pathlib import Path

history_path = Path(sys.argv[1])
expected_action = sys.argv[2]

if not history_path.exists():
    raise SystemExit(f"Missing history jsonl: {history_path}")

records = [json.loads(line) for line in history_path.read_text().splitlines() if line.strip()]
if not records:
    raise SystemExit("No JSON records found")

latest = records[-1]
required_keys = {
    "timestamp",
    "action",
    "targets",
    "dry_run",
    "ok",
    "skipped",
    "failed",
    "redacted",
    "copied",
    "merged",
    "conflicts",
}
missing = required_keys - latest.keys()
if missing:
    raise SystemExit(f"Missing keys: {sorted(missing)}")

if latest["action"] != expected_action:
    raise SystemExit(f"Expected action {expected_action}, got {latest['action']}")

if not isinstance(latest["targets"], list):
    raise SystemExit("targets must be a list")

for key in ["dry_run"]:
    if not isinstance(latest[key], bool):
        raise SystemExit(f"{key} must be boolean")

for key in ["ok", "skipped", "failed", "redacted", "copied", "merged", "conflicts"]:
    if not isinstance(latest[key], int):
        raise SystemExit(f"{key} must be integer")
PY_JSON
}

assert_summary_contains() {
  local repo_dir="$1"
  local expected="$2"

  assert_contains "$repo_dir/sync-records/latest-summary.txt" "$expected"
}

run_update_claude_case() {
  local case_dir="$TMP_ROOT/update-claude"
  local repo_dir="$case_dir/repo"
  local home_dir="$case_dir/home"
  local log_path="$case_dir/output.log"

  copy_repo "$repo_dir"

  mkdir -p "$home_dir/.claude/ccline" "$home_dir/.claude/sessions" "$home_dir/.claude/file-history" "$home_dir/.claude/rules/golang"
  cat <<'EOF_DATA' > "$home_dir/.claude/settings.json"
{"apiKey":"sk-live-123","theme":"dark","nested":{"access_token":"token-456"}}
EOF_DATA
  cat <<'EOF_DATA' > "$home_dir/.claude/ccline/config.toml"
api_key = "top-secret"
model = "claude-sonnet"
EOF_DATA
  cat <<'EOF_DATA' > "$home_dir/.claude/rules/golang/security.md"
Use api_key examples in docs, but do not replace this text.
EOF_DATA
  echo "session-data" > "$home_dir/.claude/sessions/keep.txt"
  echo "recent-file" > "$home_dir/.claude/file-history/recent.txt"
  echo "history-entry" > "$home_dir/.claude/history.jsonl"

  (
    cd "$repo_dir"
    HOME="$home_dir" bash ./update claude > "$log_path"
  )

  assert_file_exists "$repo_dir/claude/settings.json"
  assert_file_exists "$repo_dir/claude/ccline/config.toml"
  assert_contains "$repo_dir/claude/settings.json" "<REDACTED>"
  assert_not_contains "$repo_dir/claude/settings.json" "sk-live-123"
  assert_contains "$repo_dir/claude/ccline/config.toml" "<REDACTED>"
  assert_not_contains "$repo_dir/claude/ccline/config.toml" "top-secret"
  assert_not_exists "$repo_dir/claude/sessions"
  assert_not_exists "$repo_dir/claude/file-history"
  assert_not_exists "$repo_dir/claude/history.jsonl"
  assert_contains "$repo_dir/claude/rules/golang/security.md" "api_key examples"
  assert_not_contains "$repo_dir/claude/rules/golang/security.md" "<REDACTED>"
  assert_contains "$log_path" "✅ [OK] update claude"
  assert_contains "$repo_dir/sync-records/latest.log" "✅ [OK] update claude"
  assert_summary_contains "$repo_dir" "action=update"
  assert_summary_contains "$repo_dir" "targets=claude"
  assert_history_jsonl_contains "$repo_dir" "update"
}

run_update_all_case() {
  local case_dir="$TMP_ROOT/update-all"
  local repo_dir="$case_dir/repo"
  local home_dir="$case_dir/home"
  local log_path="$case_dir/output.log"

  copy_repo "$repo_dir"

  mkdir -p "$home_dir/.claude" "$home_dir/.codex" "$home_dir/.gemini" "$home_dir/.snow" "$home_dir/Library/Preferences/kitty"
  cat <<'EOF_DATA' > "$home_dir/.claude/settings.json"
{"theme":"dark"}
EOF_DATA
  cat <<'EOF_DATA' > "$home_dir/.codex/config.toml"
model = "gpt-5.4"
EOF_DATA
  cat <<'EOF_DATA' > "$home_dir/.gemini/settings.json"
{"theme":"dark"}
EOF_DATA
  cat <<'EOF_DATA' > "$home_dir/.snow/settings.json"
{"lang":"zh-CN"}
EOF_DATA
  cat <<'EOF_DATA' > "$home_dir/.zshrc"
export OPENAI_API_KEY="shell-secret"
alias ll='ls -la'
EOF_DATA
  cat <<'EOF_DATA' > "$home_dir/Library/Preferences/kitty/kitty.conf"
map ctrl+a send_text all api_key=kitty-secret
font_size 16
EOF_DATA
  cat <<'EOF_DATA' > "$home_dir/AGENTS.md"
# Home AGENTS
EOF_DATA

  (
    cd "$repo_dir"
    HOME="$home_dir" bash ./update > "$log_path"
  )

  assert_file_exists "$repo_dir/claude/settings.json"
  assert_file_exists "$repo_dir/codex/config.toml"
  assert_file_exists "$repo_dir/gemini/settings.json"
  assert_file_exists "$repo_dir/snow/settings.json"
  assert_file_exists "$repo_dir/zsh/.zshrc"
  assert_file_exists "$repo_dir/kitty/kitty.conf"
  assert_contains "$repo_dir/AGENTS.md" "# Home AGENTS"
  assert_contains "$repo_dir/zsh/.zshrc" "<REDACTED>"
  assert_contains "$repo_dir/kitty/kitty.conf" "kitty-secret"
  assert_contains "$log_path" "🎉 [DONE] update finished"
  assert_contains "$log_path" "summary for update"
  assert_summary_contains "$repo_dir" "targets=claude,codex,gemini,zshrc,kitty,snow,agents"
}

run_update_codex_excludes_case() {
  local case_dir="$TMP_ROOT/update-codex-excludes"
  local repo_dir="$case_dir/repo"
  local home_dir="$case_dir/home"
  local log_path="$case_dir/output.log"

  copy_repo "$repo_dir"

  mkdir -p "$home_dir/.codex/.tmp/plugins" "$home_dir/.codex"
  cat <<'EOF_DATA' > "$home_dir/.codex/config.toml"
api_key = "codex-secret"
EOF_DATA
  echo "temp plugin data" > "$home_dir/.codex/.tmp/plugins/readme.md"
  echo "machine-id" > "$home_dir/.codex/installation_id"

  (
    cd "$repo_dir"
    HOME="$home_dir" bash ./update codex > "$log_path"
  )

  assert_file_exists "$repo_dir/codex/config.toml"
  assert_contains "$repo_dir/codex/config.toml" "<REDACTED>"
  assert_not_exists "$repo_dir/codex/.tmp"
  assert_not_exists "$repo_dir/codex/installation_id"
  assert_not_contains "$log_path" ".tmp/plugins/readme.md"
}

run_use_codex_case() {
  local case_dir="$TMP_ROOT/use-codex"
  local repo_dir="$case_dir/repo"
  local home_dir="$case_dir/home"
  local log_path="$case_dir/output.log"

  copy_repo "$repo_dir"

  mkdir -p "$repo_dir/codex" "$home_dir/.codex"
  cat <<'EOF_DATA' > "$repo_dir/codex/config.toml"
model = "gpt-5.5"
url = "https://mcp.exa.ai/mcp?exaApiKey=<REDACTED>"
EOF_DATA
  cat <<'EOF_DATA' > "$repo_dir/codex/auth.json"
{"api_key":"<REDACTED>"}
EOF_DATA
  cat <<'EOF_DATA' > "$home_dir/.codex/config.toml"
model = "old-model"
url = "https://mcp.exa.ai/mcp?exaApiKey=live-local-key"
EOF_DATA
  cat <<'EOF_DATA' > "$home_dir/.codex/auth.json"
{"api_key":"real-secret"}
EOF_DATA

  (
    cd "$repo_dir"
    HOME="$home_dir" bash ./use codex > "$log_path"
  )

  assert_contains "$home_dir/.codex/config.toml" "gpt-5.5"
  assert_contains "$home_dir/.codex/config.toml" "exaApiKey=live-local-key"
  assert_not_contains "$home_dir/.codex/config.toml" "<REDACTED>"
  assert_contains "$home_dir/.codex/auth.json" "real-secret"
  assert_not_contains "$home_dir/.codex/auth.json" "<REDACTED>"
  assert_contains "$log_path" "⏭️  [SKIP] codex auth.json"
  assert_contains "$log_path" "🔀 [MERGE] codex config.toml"
  assert_summary_contains "$repo_dir" "action=use"
  assert_summary_contains "$repo_dir" "conflicts=1"
  assert_history_jsonl_contains "$repo_dir" "use"
  assert_contains "$repo_dir/sync-records/conflicts.log" "sensitive file skipped"
}

run_use_zshrc_case() {
  local case_dir="$TMP_ROOT/use-zshrc"
  local repo_dir="$case_dir/repo"
  local home_dir="$case_dir/home"
  local log_path="$case_dir/output.log"

  copy_repo "$repo_dir"

  mkdir -p "$repo_dir/zsh" "$home_dir"
  cat <<'EOF_DATA' > "$repo_dir/zsh/.zshrc"
export OPENAI_API_KEY="<REDACTED>"
alias gs='git status'
EOF_DATA
  cat <<'EOF_DATA' > "$home_dir/.zshrc"
export OPENAI_API_KEY="live-shell-secret"
alias ll='ls -la'
EOF_DATA

  (
    cd "$repo_dir"
    HOME="$home_dir" bash ./use zshrc > "$log_path"
  )

  assert_contains "$home_dir/.zshrc" "OPENAI_API_KEY=\"live-shell-secret\""
  assert_contains "$home_dir/.zshrc" "alias gs='git status'"
  assert_not_contains "$home_dir/.zshrc" "<REDACTED>"
  assert_contains "$log_path" "🔀 [MERGE] zshrc .zshrc"
}


run_no_emoji_case() {
  local case_dir="$TMP_ROOT/no-emoji"
  local repo_dir="$case_dir/repo"
  local home_dir="$case_dir/home"
  local log_path="$case_dir/output.log"

  copy_repo "$repo_dir"

  mkdir -p "$home_dir/.codex"
  cat <<'EOF_DATA' > "$home_dir/.codex/config.toml"
model = "gpt-5.4"
EOF_DATA

  (
    cd "$repo_dir"
    HOME="$home_dir" bash ./update --no-emoji codex > "$log_path"
  )

  assert_contains "$log_path" "[OK] update codex"
  assert_contains "$log_path" "[DONE] update finished"
  assert_not_contains "$log_path" "✅"
  assert_not_contains "$repo_dir/sync-records/latest.log" "✅"
}

run_update_claude_case
run_update_all_case
run_update_codex_excludes_case
run_no_emoji_case
run_use_codex_case
run_use_zshrc_case

echo "[PASS] update/use integration tests"
