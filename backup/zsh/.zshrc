
### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk

# =================================================================
# 1. 启动 Starship 和 工具链
# =================================================================
eval "$(starship init zsh)"
eval "$(mise activate zsh)"
eval "$(zoxide init zsh)"
source <(fzf --zsh)

# =================================================================
# 2. 加载 OMZ 的基础功能 (为了使用历史记录和快捷键)
#    使用 snippet 方式加载，不拖慢速度
# =================================================================
# 历史记录配置：设置历史记录文件大小、格式，以及防止记录重复命令
zinit snippet OMZ::lib/history.zsh

# 按键绑定：让你的 Home/End/Delete 键以及上下箭头键符合日常操作直觉
zinit snippet OMZ::lib/key-bindings.zsh

# 目录导航增强：配置 pushd/popd，并设置 ls 命令的颜色别名
zinit snippet OMZ::lib/directories.zsh

# 主题与外观：设置 LS_COLORS 颜色变量，为 grep/ls 等命令开启高亮支持
zinit snippet OMZ::lib/theme-and-appearance.zsh

# 彩色 Man 手册：让 man 命令的帮助文档变成彩色，阅读体验更好
zinit snippet OMZ::plugins/colored-man-pages

# Git 插件：提供大量 Git 命令缩写（例如：gst=git status, gp=git push 等）
zinit snippet OMZ::plugins/git

# 快速 Sudo：连按两下 ESC 键，自动在当前命令行头部加上 sudo（再次按两下取消）
zinit snippet OMZ::plugins/sudo

# 万能解压：提供 'x' 命令，自动根据后缀识别并解压 zip, tar, rar 等各种格式
zinit snippet OMZ::plugins/extract

# =================================================================
# 3. 加载核心插件
# =================================================================

# --- 补全库 ---
# blockf: 优化加载性能
zinit wait lucid blockf for \
    zsh-users/zsh-completions

# --- FZF-Tab (交互式补全) ---
# 必须在补全库之后
zinit wait lucid for \
    Aloxaf/fzf-tab

# --- 自动建议 (Autosuggestions) ---
zinit wait lucid for \
 atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions

# --- 语法高亮 ---
# 放在最后加载，确保不覆盖补全
# 使用 wait lucid (异步加载) 避免启动卡顿
# atinit"..." 确保补全系统正确初始化
zinit wait lucid for \
 atinit"zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting

# =================================================================
# 4. 个人设置
# =================================================================
alias cls="clear"
alias cat="bat"
alias ls="eza --icons --group-directories-first"
alias ll="eza -alF --icons --group-directories-first"
export LANG=en_US.UTF-8
export PATH="$HOME/.local/bin:$PATH"

# FZF-Tab 样式修正 (让它不是黑白的)
## 补全菜单的颜色和 ls 命令显示的颜色保持一致
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
## 使用 cd 命令进行补全时，开启右侧预览窗口，并列出该目录下的内容
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'

# =================================================================
# 5. 环境变量 & API Keys
# =================================================================

# pnpm
export PNPM_HOME="/Users/thornboo/Library/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac

# Github Server MCP API Keys
export GITHUB_PAT_TOKEN=YOUR-API-KEY

# =================================================================
# 6. Claude Code 快捷启动函数配置区
# =================================================================

# 启动 claude-official 实例
function claude-official() {
    local -a env_vars=(
        "ANTHROPIC_BASE_URL=http://127.0.0.1:8080"
        "ANTHROPIC_AUTH_TOKEN=YOUR-API-KEY"
        "ANTHROPIC_MODEL=claude-sonnet-4-6"
        "ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5"
        "ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6"
        "ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6"
        "ANTHROPIC_REASONING_MODEL=claude-opus-4-6"
        "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
    )
    env "${env_vars[@]}" claude "$@"
}

# 启动 Qwen3.6-Plus 实例
function claude-qwen() {
    local -a env_vars=(
        "ANTHROPIC_BASE_URL=https://www.packyapi.com"
        "ANTHROPIC_AUTH_TOKEN=YOUR-API-KEY"
        "ANTHROPIC_MODEL=qwen3.6-plus"
        "ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3.6-plus"
        "ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3.6-plus"
        "ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3.6-plus"
        "ANTHROPIC_REASONING_MODEL=qwen3.6-plus"
        "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
    )
    env "${env_vars[@]}" claude "$@"
}

# 启动 Kimi 2.5 实例
function claude-kimi() {
    local -a env_vars=(
        "ANTHROPIC_BASE_URL=https://api.siliconflow.cn"
        "ANTHROPIC_AUTH_TOKEN=YOUR-API-KEY"
        "ANTHROPIC_MODEL=Pro/moonshotai/Kimi-K2.5"
        "ANTHROPIC_DEFAULT_HAIKU_MODEL=Pro/moonshotai/Kimi-K2.5"
        "ANTHROPIC_DEFAULT_SONNET_MODEL=Pro/moonshotai/Kimi-K2.5"
        "ANTHROPIC_DEFAULT_OPUS_MODEL=Pro/moonshotai/Kimi-K2.5"
        "ANTHROPIC_REASONING_MODEL=Pro/moonshotai/Kimi-K2.5"
        "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
    )
    env "${env_vars[@]}" claude "$@"
}

# 启动 Kimi 2.5 实例
function claude-glm() {
    local -a env_vars=(
        "ANTHROPIC_BASE_URL=https://api.siliconflow.cn"
        "ANTHROPIC_AUTH_TOKEN=YOUR-API-KEY"
        "ANTHROPIC_MODEL=Pro/zai-org/GLM-5.1"
        "ANTHROPIC_DEFAULT_HAIKU_MODEL=Pro/zai-org/GLM-5.1"
        "ANTHROPIC_DEFAULT_SONNET_MODEL=Pro/zai-org/GLM-5.1"
        "ANTHROPIC_DEFAULT_OPUS_MODEL=Pro/zai-org/GLM-5.1"
        "ANTHROPIC_REASONING_MODEL=Pro/zai-org/GLM-5.1"
        "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
    )
    env "${env_vars[@]}" claude "$@"
}
