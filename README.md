# thornboo-dev-config

个人 AI 开发工具配置备份仓库，统一管理 Claude Code、Codex、Gemini、OpenCode、Snow、cc-switch 等工具的配置文件。

## 目录结构

```
thornboo-dev-config/
├── claude/          # Claude Code (~/.claude/)
├── codex/           # Codex (~/.codex/)
├── gemini/          # Gemini CLI (~/.gemini/)
├── opencode/        # OpenCode (~/.config/opencode/)
├── snow/            # Snow (~/.snow/)
├── cc-switch/       # cc-switch (~/.cc-switch/)
├── AGENTS.md        # 跨工具通用 Agent 指令 (~/AGENTS.md)
├── sync.sh          # 一键同步备份脚本
└── .gitignore
```

## 使用方法

### 备份配置

```bash
# 预览将要同步的内容（不会写入任何文件）
./sync.sh --dry-run

# 正式执行同步
./sync.sh
```

同步完成后手动 commit 并 push：

```bash
git add .
git commit -m "chore: sync configs"
git push
```

### 恢复配置（新机器）

克隆仓库后，将各目录内容复制回对应位置：

```bash
cp -r claude/ ~/.claude/
cp -r codex/ ~/.codex/
cp -r gemini/ ~/.gemini/
cp -r opencode/ ~/.config/opencode/
cp -r snow/ ~/.snow/
cp -r cc-switch/ ~/.cc-switch/
cp AGENTS.md ~/AGENTS.md
```

## 备份策略

各工具只备份配置文件，运行时数据、历史记录、缓存等均排除在外：

| 工具 | 备份内容 | 排除内容 |
|------|---------|---------|
| Claude Code | agents、rules、settings、plugins 元数据、ccline、skills | sessions、history、cache、backups、telemetry |
| Codex | config.toml、skills、auth.json | sessions、logs、sqlite 数据库、tmp |
| Gemini | settings.json | history、tmp、state、trustedFolders |
| OpenCode | opencode.json、package.json | node_modules、bun.lock |
| Snow | commands、hooks、profiles、各类配置 json | history、log、sessions、snapshots、notebook |
| cc-switch | settings.json、skills | backups、logs、cc-switch.db |

## 相关工具

- [Claude Code](https://claude.ai/code) — Anthropic 官方 CLI
- [everything-claude-code](https://github.com/affaan-m/everything-claude-code) — Claude Code 整合配置包（已安装 v1.8.0）
- [Codex](https://github.com/openai/codex) — OpenAI CLI
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) — Google Gemini CLI
- [OpenCode](https://opencode.ai) — 开源 AI 编码工具
