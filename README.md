# thornboo-dev-config

个人 AI 开发工具配置备份仓库。这个仓库分成两层：根目录是同步工具本身，`backup/` 才是从本机全局配置备份出来的内容。

## 目录结构

```text
thornboo-dev-config/
├── backup/                 # 备份出来的个人配置快照
│   ├── claude/             # ~/.claude/ 的可备份配置
│   ├── codex/              # ~/.codex/ 的可备份配置
│   ├── gemini/             # ~/.gemini/ 的可备份配置
│   ├── home/AGENTS.md      # ~/AGENTS.md 的备份，不是本仓库开发指令
│   ├── kitty/              # Kitty 全局配置
│   ├── snow/               # ~/.snow/ 的可备份配置
│   └── zsh/.zshrc          # ~/.zshrc 的备份
├── scripts/                # 同步、脱敏、合并脚本
├── tests/                  # 同步与脱敏回归测试
├── update                  # 备份命令（无参数备份全部）
├── use                     # 应用命令（将仓库配置写回本机）
├── sync.sh                 # 兼容入口，内部转发到 update
├── README.md               # 本项目说明
└── .gitignore
```

> 说明：根目录不再放被备份的 `AGENTS.md`，避免误解成“本项目专用指令”。被备份的全局 agent 指令位于 `backup/home/AGENTS.md`。

## 支持的备份目标

当前默认备份以下全局配置：

- `claude` — Claude Code 全局配置
- `codex` — Codex 全局配置
- `gemini` — Gemini CLI 全局配置
- `zshrc` — Zsh 全局配置文件
- `kitty` — Kitty 终端全局配置
- `snow` — Snow 全局配置
- `agents` — 全局 `~/AGENTS.md`

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

# 关闭 emoji，输出纯文本日志
./update --no-emoji codex
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

# 关闭 emoji，输出纯文本日志
./use --no-emoji codex
```

说明：
- `use` 会处理 `claude`、`codex`、`gemini`、`zshrc`、`kitty`、`snow`、`agents`
- 敏感文件默认跳过，比如 `auth.json`、`.env`
- 对已脱敏的配置文件，会尽量保留你本机原有的 secret；无法安全恢复时会跳过并记录冲突

## 安全模型

这个仓库默认按“可公开审阅但不含真实 secret / 本地隐私路径”的方式备份配置：

- **会脱敏**：配置类文件中的常见 secret 字段，如 `api_key`、`token`、`secret`、`password`，以及 URL query 中的 key/token。
- **占位符**：脱敏后的 secret 使用 `YOUR-API-KEY`，表达“这里需要你自己的真实值”。
- **会跳过**：回灌时默认不覆盖 `auth.json`、`.env`、`credentials.json`、`tokens.json` 等敏感文件。
- **会合并**：仓库文件包含 `YOUR-API-KEY` 时，`use` 会尝试从本机旧文件补回真实 secret；补不回来就跳过并记录冲突。
- **会排除**：会话、历史、缓存、sqlite、临时目录、Claude inbox、Claude Superpowers brainstorm、命令/成本日志、Gemini trusted folders 等运行时或本地隐私文件不会进入仓库。
- **不会加密**：脚本只做脱敏和跳过，不负责加密保存 secret；真实 secret 仍应放在本机环境变量或工具自己的认证文件里。

示例：仓库里会写成 `ANTHROPIC_AUTH_TOKEN=YOUR-API-KEY`，本机实际使用时应由环境变量、工具认证文件或 `use` 的本机合并逻辑补回真实 token。

`sync-records/` 会留在本机仓库目录中便于审计，但默认被 `.gitignore` 忽略，不随 Git 提交。

## 冲突与备份记录

`update` 和 `use` 默认使用 emoji 状态标记，让日志更容易扫读：

- `✅ [OK]` — 成功
- `⏭️ [SKIP]` — 跳过
- `🔐 [MASK]` — 已脱敏
- `📦 [COPY]` — 已复制
- `🔀 [MERGE]` — 已合并脱敏配置
- `🎉 [DONE]` — 本次运行完成

如果需要纯文本日志，可以加 `--no-emoji`。

每次执行 `update` 或 `use`，都会在 `sync-records/` 下留下记录：

- `sync-records/latest.log` — 最近一次完整运行日志
- `sync-records/latest-summary.txt` — 最近一次摘要统计
- `sync-records/history.log` — 每次运行的文本历史摘要
- `sync-records/history.jsonl` — 每次运行的 JSONL 历史摘要，方便脚本和 `jq` 解析
- `sync-records/conflicts.log` — 冲突与跳过原因记录

当前冲突处理策略：

- `update`：以本机配置为准，写入 `backup/`，并对敏感内容脱敏
- `use` 普通文件：以 `backup/` 为准，覆盖本机
- `use` 敏感文件：默认跳过，不覆盖本机真实 secret
- `use` 脱敏文件：优先合并本机已有 secret；无法恢复就跳过，并写入 `sync-records/conflicts.log`

## 默认配置路径

下面这些路径优先按官方默认位置处理；脚本不会在你的 Home 下乱扫：

| 目标 | 本机来源/写回路径 | 仓库备份路径 |
|------|------------------|--------------|
| `claude` | `~/.claude/` | `backup/claude/` |
| `codex` | `~/.codex/` | `backup/codex/` |
| `gemini` | `~/.gemini/` | `backup/gemini/` |
| `zshrc` | `${ZDOTDIR:-$HOME}/.zshrc` | `backup/zsh/.zshrc` |
| `kitty` | `KITTY_CONFIG_DIRECTORY` 或平台默认 Kitty 配置目录 | `backup/kitty/` |
| `snow` | `~/.snow/` | `backup/snow/` |
| `agents` | `~/AGENTS.md` | `backup/home/AGENTS.md` |

## 备份策略

各工具只备份可复用配置文件，运行时数据、历史记录、缓存、日志、本机绝对路径等均排除在外：

| 目标 | 备份内容 | 排除内容 |
|------|---------|---------|
| Claude Code | 全局配置、rules、skills、主题、插件元数据 | sessions、session-data、history、cache、tasks、teams inbox、telemetry、Superpowers brainstorm、命令/成本日志、ECC install-state 等运行时或本机状态 |
| Codex | 全局配置、用户技能、版本信息 | `auth.json`、sessions、logs、sqlite、`.tmp`、`tmp`、运行时状态 |
| Gemini | 非敏感全局配置 | `.env`、`trustedFolders.json`、history、tmp、state、installation id |
| Zsh | `.zshrc`（脱敏后） | 无额外扫描 |
| Kitty | `kitty.conf` 及配置目录内文件 | `.DS_Store`、`*.bak`、`*.backup` |
| Snow | 全局配置、profiles（脱敏后） | history、log、sessions、snapshots、notebook 等运行时目录 |
| AGENTS | `~/AGENTS.md` | 无 |

另外：

- `update` 在备份 `claude`、`codex`、`gemini`、`zshrc`、`kitty`、`snow` 等配置文件时会自动脱敏常见 secret 字段
- `update` 无参数时会备份全部支持工具
- `sync.sh` 仍可用，但只是兼容转发到 `./update`

## 后续建议

如果你后面想继续增强，可以考虑：

- 给 `use` 增加 `--backup`，应用前先备份本机旧文件
- 给 `update` 增加 `--strict-audit`，提交前扫描绝对路径、日志文件和旧占位符
