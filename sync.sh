#!/usr/bin/env bash
# sync.sh — 将各 AI 工具配置备份到当前仓库
# 用法: ./sync.sh [--dry-run]

set -euo pipefail

# 脚本所在目录即仓库根目录
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[dry-run] 预览模式，不会写入任何文件"
fi

# 统一的 rsync 封装，dry-run 时加 --dry-run 参数
rsync_cmd() {
  if $DRY_RUN; then
    rsync --dry-run -av --delete "$@"
  else
    rsync -av --delete "$@"
  fi
}

# ── Claude Code ──────────────────────────────────────────────
# 排除：运行时数据、历史记录、缓存、插件缓存、遥测等
echo ""
echo "==> 同步 ~/.claude"
rsync_cmd \
  --exclude='backups/' \
  --exclude='cache/' \
  --exclude='file-history/' \
  --exclude='history.jsonl' \
  --exclude='metrics/' \
  --exclude='plans/' \
  --exclude='plugins/cache/' \
  --exclude='projects/' \
  --exclude='session-env/' \
  --exclude='sessions/' \
  --exclude='shell-snapshots/' \
  --exclude='telemetry/' \
  --exclude='.DS_Store' \
  ~/.claude/ "$REPO_DIR/claude/"

# ── Codex ────────────────────────────────────────────────────
# 排除：日志、数据库状态文件、会话、临时文件、历史记录
echo ""
echo "==> 同步 ~/.codex"
rsync_cmd \
  --exclude='log/' \
  --exclude='logs_*.sqlite' \
  --exclude='memories/' \
  --exclude='sessions/' \
  --exclude='shell_snapshots/' \
  --exclude='state_*.sqlite' \
  --exclude='tmp/' \
  --exclude='history.jsonl' \
  --exclude='version.json' \
  --exclude='.DS_Store' \
  ~/.codex/ "$REPO_DIR/codex/"

# ── Gemini ───────────────────────────────────────────────────
# 排除：历史记录、临时文件、运行时状态、本机路径信任列表
echo ""
echo "==> 同步 ~/.gemini"
rsync_cmd \
  --exclude='history/' \
  --exclude='tmp/' \
  --exclude='installation_id' \
  --exclude='projects.json' \
  --exclude='state.json' \
  --exclude='trustedFolders.json' \
  --exclude='.DS_Store' \
  ~/.gemini/ "$REPO_DIR/gemini/"

# ── OpenCode ─────────────────────────────────────────────────
# 排除：node_modules 依赖目录、bun 锁文件（可重新安装）
echo ""
echo "==> 同步 ~/.config/opencode"
rsync_cmd \
  --exclude='node_modules/' \
  --exclude='bun.lock' \
  --exclude='.DS_Store' \
  ~/.config/opencode/ "$REPO_DIR/opencode/"

# ── Snow ─────────────────────────────────────────────────────
# 排除：历史记录、日志、会话、快照、笔记本、待办、用量统计等运行时数据
echo ""
echo "==> 同步 ~/.snow"
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
  --exclude='.DS_Store' \
  ~/.snow/ "$REPO_DIR/snow/"

# ── cc-switch ────────────────────────────────────────────────
# 排除：自动备份目录、日志、SQLite 数据库文件
echo ""
echo "==> 同步 ~/.cc-switch"
rsync_cmd \
  --exclude='backups/' \
  --exclude='logs/' \
  --exclude='cc-switch.db' \
  --exclude='.DS_Store' \
  ~/.cc-switch/ "$REPO_DIR/cc-switch/"

# ── AGENTS.md ────────────────────────────────────────────────
# 跨工具通用 agent 指令文件，放在用户根目录
echo ""
echo "==> 同步 ~/AGENTS.md"
if $DRY_RUN; then
  echo "[dry-run] 将复制 ~/AGENTS.md -> $REPO_DIR/AGENTS.md"
else
  cp ~/AGENTS.md "$REPO_DIR/AGENTS.md"
fi

echo ""
if $DRY_RUN; then
  echo "预览完成。去掉 --dry-run 参数后重新执行即可正式同步。"
else
  echo "同步完成。"
fi
