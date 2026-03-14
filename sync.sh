#!/usr/bin/env bash
# sync.sh — 将各 AI 工具配置备份到当前仓库
# 用法: ./sync.sh [--dry-run]
#   交互式多选要备份的工具（依赖 fzf）

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[dry-run] 预览模式，不会写入任何文件"
fi

# 统一的 rsync 封装
rsync_cmd() {
  if $DRY_RUN; then
    rsync --dry-run -av --delete "$@"
  else
    rsync -av --delete "$@"
  fi
}

# 统一的 cp 封装
cp_cmd() {
  if $DRY_RUN; then
    echo "[dry-run] cp $*"
  else
    cp "$@"
  fi
}

# ── 工具列表 ──────────────────────────────────────────────────
TOOLS=(
  "claude    │ Claude Code  (~/.claude)"
  "codex     │ Codex        (~/.codex)"
  "gemini    │ Gemini CLI   (~/.gemini)"
  "opencode  │ OpenCode     (~/.config/opencode)"
  "snow      │ Snow         (~/.snow)"
  "cc-switch │ cc-switch    (~/.cc-switch)"
  "agents    │ AGENTS.md    (~/AGENTS.md)"
)

# ── 交互式选择 ────────────────────────────────────────────────
if ! command -v fzf &>/dev/null; then
  echo "错误：未找到 fzf，请先安装：brew install fzf"
  exit 1
fi

echo "请选择要备份的工具（Tab/空格 多选，Enter 确认，Ctrl-A 全选）："
SELECTED=$(printf '%s\n' "${TOOLS[@]}" | \
  fzf --multi \
      --prompt="备份 > " \
      --header="Tab/空格=选择  Ctrl-A=全选  Enter=确认" \
      --height=~50% \
      --layout=reverse \
      --border \
  | awk -F'│' '{gsub(/ /,"",$1); print $1}')

if [[ -z "$SELECTED" ]]; then
  echo "未选择任何工具，退出。"
  exit 0
fi

# ── 各工具同步函数 ────────────────────────────────────────────

sync_claude() {
  echo ""
  echo "==> 同步 ~/.claude"
  [[ -d ~/.claude ]] || { echo "  跳过：~/.claude 不存在"; return; }
  rsync_cmd \
    --exclude='backups/' \
    --exclude='cache/' \
    --exclude='file-history/' \
    --exclude='history.jsonl' \
    --exclude='ccline/ccline' \
    --exclude='homunculus/projects/' \
    --exclude='homunculus/projects.json' \
    --exclude='metrics/' \
    --exclude='paste-cache/' \
    --exclude='plans/' \
    --exclude='plugins/cache/' \
    --exclude='plugins/install-counts-cache.json' \
    --exclude='plugins/marketplaces/' \
    --exclude='projects/' \
    --exclude='session-env/' \
    --exclude='sessions/' \
    --exclude='shell-snapshots/' \
    --exclude='tasks/' \
    --exclude='telemetry/' \
    --exclude='.DS_Store' \
    ~/.claude/ "$REPO_DIR/claude/"
}

sync_codex() {
  echo ""
  echo "==> 同步 ~/.codex"
  [[ -d ~/.codex ]] || { echo "  跳过：~/.codex 不存在"; return; }
  rsync_cmd \
    --exclude='log/' \
    --exclude='logs_*.sqlite' \
    --exclude='*.sqlite-shm' \
    --exclude='*.sqlite-wal' \
    --exclude='memories/' \
    --exclude='sessions/' \
    --exclude='shell_snapshots/' \
    --exclude='skills/.system/' \
    --exclude='state_*.sqlite' \
    --exclude='tmp/' \
    --exclude='history.jsonl' \
    --exclude='.DS_Store' \
    ~/.codex/ "$REPO_DIR/codex/"
}

sync_gemini() {
  echo ""
  echo "==> 同步 ~/.gemini"
  [[ -d ~/.gemini ]] || { echo "  跳过：~/.gemini 不存在"; return; }
  rsync_cmd \
    --exclude='history/' \
    --exclude='tmp/' \
    --exclude='installation_id' \
    --exclude='projects.json' \
    --exclude='state.json' \
    --exclude='.DS_Store' \
    ~/.gemini/ "$REPO_DIR/gemini/"
}

sync_opencode() {
  echo ""
  echo "==> 同步 ~/.config/opencode"
  [[ -d ~/.config/opencode ]] || { echo "  跳过：~/.config/opencode 不存在"; return; }
  rsync_cmd \
    --exclude='node_modules/' \
    --exclude='bun.lock' \
    --exclude='.DS_Store' \
    ~/.config/opencode/ "$REPO_DIR/opencode/"
}

sync_snow() {
  echo ""
  echo "==> 同步 ~/.snow"
  [[ -d ~/.snow ]] || { echo "  跳过：~/.snow 不存在"; return; }
  rsync_cmd \
    --exclude='history/' \
    --exclude='log/' \
    --exclude='notebook/' \
    --exclude='sessions/' \
    --exclude='snapshots/' \
    --exclude='todos/' \
    --exclude='usage/' \
    --exclude='active-profile.json' \
    --exclude='codebase.json' \
    --exclude='command-usage.json' \
    --exclude='history.json' \
    --exclude='mcp-config.json.save' \
    --exclude='.DS_Store' \
    ~/.snow/ "$REPO_DIR/snow/"
}

sync_ccswitch() {
  echo ""
  echo "==> 同步 ~/.cc-switch"
  [[ -d ~/.cc-switch ]] || { echo "  跳过：~/.cc-switch 不存在"; return; }
  rsync_cmd \
    --exclude='backups/' \
    --exclude='logs/' \
    --exclude='cc-switch.db' \
    --exclude='.DS_Store' \
    ~/.cc-switch/ "$REPO_DIR/cc-switch/"
}

sync_agents() {
  echo ""
  echo "==> 同步 ~/AGENTS.md"
  [[ -f ~/AGENTS.md ]] || { echo "  跳过：~/AGENTS.md 不存在"; return; }
  cp_cmd ~/AGENTS.md "$REPO_DIR/AGENTS.md"
}

# ── 执行选中的工具 ────────────────────────────────────────────
while IFS= read -r tool; do
  case "$tool" in
    claude)    sync_claude    ;;
    codex)     sync_codex     ;;
    gemini)    sync_gemini    ;;
    opencode)  sync_opencode  ;;
    snow)      sync_snow      ;;
    cc-switch) sync_ccswitch  ;;
    agents)    sync_agents    ;;
  esac
done <<< "$SELECTED"

echo ""
if $DRY_RUN; then
  echo "预览完成。去掉 --dry-run 参数后重新执行即可正式同步。"
else
  echo "同步完成。"
fi

