# thornboo-dev-config

个人 AI 开发工具配置备份仓库，统一管理 Claude Code、Codex、Gemini、Zsh、Kitty、Snow 与全局 `AGENTS.md`。

## 目录结构

```text
thornboo-dev-config/
├── claude/              # Claude Code 全局配置
├── codex/               # Codex 全局配置
├── gemini/              # Gemini CLI 全局配置
├── kitty/               # Kitty 全局配置
├── snow/                # Snow 全局配置
├── zsh/                 # Zsh 全局配置
├── sync-records/        # 最近一次运行日志、摘要、冲突记录、历史记录
├── AGENTS.md            # 全局 Agent 指令 (~/AGENTS.md)
├── update               # 备份命令（无参数备份全部）
├── use                  # 应用命令（将仓库配置写回本机）
├── sync.sh              # 兼容入口，内部转发到 update
└── .gitignore
```

## 支持的备份目标

当前默认备份以下全局配置：

- `claude` — Claude Code 全局配置
- `codex` — Codex 全局配置
- `gemini` — Gemini CLI 全局配置
- `zshrc` — Zsh 全局配置文件
- `kitty` — Kitty 终端全局配置
- `snow` — Snow 全局配置
- `agents` — 全局 `AGENTS.md`

## 使用方法

### 备份配置

```bash
# 备份全部支持的工具
./update

# 只备份某一个工具
./update claude
./update kitty
./update zshrc

# 一次备份多个工具
./update claude codex kitty

# 预览模式（不会写入任何文件）
./update --dry-run codex
```

### 应用配置（写回本机）

```bash
# 将仓库里的配置应用到本机
./use claude
./use codex
./use zshrc
./use kitty

# 预览模式
./use --dry-run codex
```

说明：
- `use` 会处理 `claude`、`codex`、`gemini`、`zshrc`、`kitty`、`snow`、`agents`
- 敏感文件默认跳过，比如 `auth.json`、`.env`
- 对已脱敏的配置文件，会尽量保留你本机原有的 secret；无法安全恢复时会跳过并记录冲突

## 冲突与备份记录

每次执行 `update` 或 `use`，都会在 `sync-records/` 下留下记录：

- `sync-records/latest.log` — 最近一次完整运行日志
- `sync-records/latest-summary.txt` — 最近一次摘要统计
- `sync-records/history.log` — 每次运行的历史摘要
- `sync-records/conflicts.log` — 冲突与跳过原因记录

当前冲突处理策略：

- `update`：以本机配置为准，写入仓库，并对敏感内容脱敏
- `use` 普通文件：以仓库为准，覆盖本机
- `use` 敏感文件：默认跳过，不覆盖本机真实 secret
- `use` 脱敏文件：优先合并本机已有 secret；无法恢复就跳过，并写入 `sync-records/conflicts.log`

## 默认配置路径

下面这些路径优先按官方默认位置处理；脚本不会在你的 Home 下乱扫：

- `claude` → `~/.claude/`
- `codex` → `~/.codex/`
- `gemini` → `~/.gemini/`
- `zshrc` → `${ZDOTDIR:-$HOME}/.zshrc`
- `kitty` → 优先 `KITTY_CONFIG_DIRECTORY`；否则 Linux/通用走 `${XDG_CONFIG_HOME:-$HOME/.config}/kitty/`；macOS 默认走 `~/Library/Preferences/kitty/`
- `snow` → `~/.snow/`
- `agents` → `~/AGENTS.md`

## 官方路径依据说明

本次实现按官方/约定俗成的默认配置位置设计：

- Zsh 使用 `${ZDOTDIR:-$HOME}` 作为 dotfiles 根目录，`~/.zshrc` 是标准用户级配置文件
- Kitty 支持 `KITTY_CONFIG_DIRECTORY`，否则使用平台默认配置目录
- Codex、Gemini、Claude、Snow 采用各自 CLI 约定的用户级配置目录

当前运行环境无法直接联网抓取官方文档原文，所以 README 里先写明了采用的“官方默认路径约定”和脚本解析逻辑。后续如果你愿意，我可以在可联网环境下继续补上具体官方文档链接与引用说明。

## 备份策略

各工具只备份配置文件，运行时数据、历史记录、缓存等均排除在外：

| 目标 | 备份内容 | 排除内容 |
|------|---------|---------|
| Claude Code | 全局配置、rules、skills、主题、插件元数据 | sessions、history、cache、tasks、telemetry、运行时目录 |
| Codex | 全局配置、用户技能、版本信息 | sessions、logs、sqlite、`.tmp`、`tmp`、运行时状态 |
| Gemini | 全局配置、trusted folders、`.env` | history、tmp、state、installation id |
| Zsh | `.zshrc` | 无额外扫描 |
| Kitty | `kitty.conf` 及配置目录内文件 | 仅排除 `.DS_Store` |
| Snow | 全局配置、profiles | history、log、sessions、snapshots、notebook 等运行时目录 |
| AGENTS | `~/AGENTS.md` | 无 |

另外：

- `update` 在备份 `claude`、`codex`、`gemini`、`zshrc`、`snow` 等配置文件时会自动脱敏常见 secret 字段
- `update` 无参数时会备份全部支持工具
- `sync.sh` 仍可用，但只是兼容转发到 `./update`

## 后续建议

如果你后面想继续增强，可以考虑：

- 给 `use` 增加 `--backup`，应用前先备份本机旧文件
- 给 `sync-records/history.log` 增加 JSON 格式输出，方便机器解析
- 在可联网环境下补全官方文档链接与脚本路径来源说明
