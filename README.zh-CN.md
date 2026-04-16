# thornboo-dev-config

[English](README.md) | [中文](README.zh-CN.md)

我个人的 dotfiles 仓库，用来管理 AI 工具、终端环境和 agent 工作流相关的全局配置。

这个仓库现在已经不只是“几个 AI 配置文件的备份”，而更像是 **My personal dotfiles**：

- `backup/` 里放的是我个人机器上的全局配置快照
- 根目录放的是同步这些配置所需的脚本、测试和说明文档

这样可以更清楚地区分：哪些是“仓库本身的代码”，哪些是“我个人配置的备份内容”。


## 仓库结构

```text
thornboo-dev-config/
├── backup/                 # 备份出来的个人 dotfiles / 全局配置
│   ├── claude/             # ~/.claude/ 中可移植的部分
│   ├── codex/              # ~/.codex/ 中可移植的部分
│   ├── gemini/             # ~/.gemini/ 中可移植的部分
│   ├── home/AGENTS.md      # ~/AGENTS.md 的备份，不是本仓库开发说明
│   ├── kitty/              # Kitty 配置快照
│   ├── snow/               # ~/.snow/ 中可移植的部分
│   └── zsh/.zshrc          # ~/.zshrc 的备份
├── scripts/                # 同步、脱敏、合并脚本
├── tests/                  # 同步行为的回归测试
├── update                  # 从本机拉取配置到 backup/
├── use                     # 将 backup/ 中的配置应用回本机
├── sync.sh                 # 兼容入口，内部转发到 ./update
├── README.md               # 英文说明（默认）
├── README.zh-CN.md         # 中文说明
└── .gitignore
```

> `backup/home/AGENTS.md` 是我家目录里的全局文件备份，不是这个仓库本身的开发规范文档。

## 管理的目标

当前同步层支持这些全局目标：

- `claude` — Claude Code 全局配置
- `codex` — Codex 全局配置
- `gemini` — Gemini CLI 全局配置
- `zshrc` — Zsh 用户配置
- `kitty` — Kitty 终端配置
- `snow` — Snow 全局配置
- `agents` — 全局 `~/AGENTS.md`

## 常用命令

### 备份本机配置

```bash
# 备份全部
./update

# 备份指定目标
./update claude
./update codex kitty
./update zshrc

# 仅预览
./update --dry-run codex

# 输出纯文本日志
./update --no-emoji codex
```

### 将备份应用回本机

```bash
# 将指定目标应用回机器
./use claude
./use codex
./use zshrc
./use kitty

# 仅预览
./use --dry-run codex

# 输出纯文本日志
./use --no-emoji codex
```

说明：

- `use` 支持 `claude`、`codex`、`gemini`、`zshrc`、`kitty`、`snow`、`agents`
- `auth.json`、`.env` 这类敏感文件默认会跳过
- 如果仓库里的文件包含脱敏占位符，`use` 会尽量从本机已有文件中补回真实 secret

## 安全模型

这个仓库的目标是：**Git 中可审阅，但不泄露真实 secret，也不暴露本地隐私状态。**

### 同步层会做什么

- **自动脱敏**：处理 JSON、TOML、INI、shell env、URL query 等常见配置格式中的 secret
- **使用 `YOUR-API-KEY`** 作为脱敏后的可读占位符
- **本机回灌时合并 secret**：`use` 遇到 `YOUR-API-KEY` 时，会尝试从本机旧文件补回真实值
- **跳过敏感文件**：如 `auth.json`、`.env`、`credentials.json`、`tokens.json`
- **排除本地运行态**：如 sessions、logs、cache、sqlite、带有绝对路径的本机状态文件

### 明确不应入库的内容

例如：

- Claude 会话记录和 brainstorm 运行时文件
- 命令日志和 cost 日志
- Gemini 的 `trustedFolders.json`
- 本机 `.env`
- Codex 的 `auth.json`
- install-state 或机器绑定的状态数据库

仓库中的示例值会写成：

```bash
ANTHROPIC_AUTH_TOKEN=YOUR-API-KEY
```

意思是：这个配置文件本身是可移植的，但真实 secret 应该只存在于本机。

## 备份策略

只备份“可移植、可复用”的配置；运行时数据、日志、历史记录、缓存、本机绝对路径等默认排除。

| 目标 | 会备份 | 不会备份 |
|------|--------|----------|
| Claude Code | 全局配置、rules、skills、主题、插件元数据 | sessions、`session-data`、history、cache、brainstorm 运行时、日志、telemetry、install state |
| Codex | 全局配置、prompts、rules、skills、版本元数据 | `auth.json`、sessions、logs、sqlite 状态、临时目录 |
| Gemini | 非敏感全局配置 | `.env`、`trustedFolders.json`、history、临时状态 |
| Zsh | 脱敏后的 `.zshrc` | 无额外扫描 |
| Kitty | `kitty.conf` 及相关配置 | `.DS_Store`、`*.bak`、`*.backup` |
| Snow | 脱敏后的全局配置与 profiles | history、log、sessions、snapshots、notebook 等运行态 |
| AGENTS | `~/AGENTS.md` | 无 |

## 本机路径与仓库路径映射

| 目标 | 本机路径 | 仓库路径 |
|------|---------|---------|
| `claude` | `~/.claude/` | `backup/claude/` |
| `codex` | `~/.codex/` | `backup/codex/` |
| `gemini` | `~/.gemini/` | `backup/gemini/` |
| `zshrc` | `${ZDOTDIR:-$HOME}/.zshrc` | `backup/zsh/.zshrc` |
| `kitty` | `KITTY_CONFIG_DIRECTORY` 或平台默认 Kitty 配置目录 | `backup/kitty/` |
| `snow` | `~/.snow/` | `backup/snow/` |
| `agents` | `~/AGENTS.md` | `backup/home/AGENTS.md` |

## 运行记录

每次执行 `update` 或 `use`，都会在本地工作区写入审计记录到 `sync-records/`：

- `sync-records/latest.log`
- `sync-records/latest-summary.txt`
- `sync-records/history.log`
- `sync-records/history.jsonl`
- `sync-records/conflicts.log`

这些记录只保留在本地工作区，默认不会提交到 Git。

## 后续可以继续增强

- 给 `use` 增加 `--backup`，覆盖前先备份本机旧文件
- 给 `update` 增加 `--strict-audit`，在提交前做一轮隐私扫描
- 后续有新工具时继续补目标级规则
