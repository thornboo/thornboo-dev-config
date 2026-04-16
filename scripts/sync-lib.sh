#!/usr/bin/env bash

set -euo pipefail

readonly SYNC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd "$SYNC_LIB_DIR/.." && pwd)"
readonly REDACTED_PLACEHOLDER="<REDACTED>"
readonly RECORD_DIR_NAME="sync-records"

ACTION=""
DRY_RUN=false
USE_EMOJI=true
TARGETS=()
SUMMARY_OK=0
SUMMARY_SKIP=0
SUMMARY_FAIL=0
SUMMARY_MASKED=0
SUMMARY_COPIED=0
SUMMARY_MERGED=0
SUMMARY_CONFLICTS=0
LAST_SANITIZED_COUNT=0
RSYNC_EXCLUDES=()
RUN_TIMESTAMP=""
RUN_TARGETS=""
RECORD_DIR=""
LATEST_LOG_PATH=""
SUMMARY_PATH=""
HISTORY_PATH=""
HISTORY_JSONL_PATH=""
CONFLICTS_PATH=""
RECORDING_ACTIVE=false

emoji_for_status() {
  local status="$1"

  if ! $USE_EMOJI; then
    printf ''
    return 0
  fi

  case "$status" in
    INFO) printf 'ℹ️  ' ;;
    OK) printf '✅ ' ;;
    SKIP) printf '⏭️  ' ;;
    WARN) printf '⚠️  ' ;;
    ERROR) printf '❌ ' ;;
    MASK) printf '🔐 ' ;;
    COPY) printf '📦 ' ;;
    MERGE) printf '🔀 ' ;;
    DONE) printf '🎉 ' ;;
    RECORD) printf '📝 ' ;;
    *) printf '' ;;
  esac
}

log_line() {
  local stream="$1"
  local status="$2"
  local message="$3"
  local emoji="$(emoji_for_status "$status")"
  local line="  ${emoji}[$status] $message"

  if [[ "$stream" == "stderr" ]]; then
    printf '%s\n' "$line" >&2
  else
    printf '%s\n' "$line"
  fi

  if $RECORDING_ACTIVE; then
    printf '%s\n' "$line" >> "$LATEST_LOG_PATH"
  fi
}

log_section() {
  local line=""

  if $USE_EMOJI; then
    line="\n🚀 ==> $1"
  else
    line="\n==> $1"
  fi

  printf '%b\n' "$line"
  if $RECORDING_ACTIVE; then printf '%b\n' "$line" >> "$LATEST_LOG_PATH"; fi
}

log_info() {
  log_line stdout INFO "$1"
}

log_ok() {
  log_line stdout OK "$1"
}

log_skip() {
  log_line stdout SKIP "$1"
}

log_warn() {
  log_line stdout WARN "$1"
}

log_error() {
  log_line stderr ERROR "$1"
}

log_mask() {
  log_line stdout MASK "$1"
}

log_copy() {
  log_line stdout COPY "$1"
}

log_merge() {
  log_line stdout MERGE "$1"
}

log_done() {
  log_line stdout DONE "$1"
}

log_record() {
  log_line stdout RECORD "$1"
}

print_update_usage() {
  cat <<'EOF_USAGE'
Usage: ./update [--dry-run] [--no-emoji] [all|claude|codex|gemini|zshrc|kitty|snow|agents]...

Examples:
  ./update
  ./update claude
  ./update codex kitty
  ./update --dry-run zshrc
  ./update --no-emoji codex
EOF_USAGE
}

print_use_usage() {
  cat <<'EOF_USAGE'
Usage: ./use [--dry-run] [--no-emoji] [all|claude|codex|gemini|zshrc|kitty|snow|agents]...

Examples:
  ./use claude
  ./use codex kitty
  ./use --dry-run zshrc
  ./use --no-emoji codex
EOF_USAGE
}

all_update_targets() {
  printf '%s\n' claude codex gemini zshrc kitty snow agents
}

all_use_targets() {
  printf '%s\n' claude codex gemini zshrc kitty snow agents
}

append_unique_target() {
  local candidate="$1"
  local item=""

  for item in "${TARGETS[@]}"; do
    [[ "$item" == "$candidate" ]] && return 0
  done

  TARGETS+=("$candidate")
}

ensure_supported_target() {
  local action="$1"
  local target="$2"

  case "$action:$target" in
    update:claude|update:codex|update:gemini|update:zshrc|update:kitty|update:snow|update:agents) return 0 ;;
    use:claude|use:codex|use:gemini|use:zshrc|use:kitty|use:snow|use:agents) return 0 ;;
    *)
      log_error "Unsupported target for $action: $target"
      return 1
      ;;
  esac
}

add_all_targets() {
  local action="$1"
  local target=""

  if [[ "$action" == "update" ]]; then
    while IFS= read -r target; do
      append_unique_target "$target"
    done < <(all_update_targets)
    return 0
  fi

  while IFS= read -r target; do
    append_unique_target "$target"
  done < <(all_use_targets)
}

parse_targets() {
  local action="$1"
  shift

  ACTION="$action"
  DRY_RUN=false
  USE_EMOJI=true
  TARGETS=()
  SUMMARY_OK=0
  SUMMARY_SKIP=0
  SUMMARY_FAIL=0
  SUMMARY_MASKED=0
  SUMMARY_COPIED=0
  SUMMARY_MERGED=0
  SUMMARY_CONFLICTS=0

  local argument=""

  while (($# > 0)); do
    argument="$1"
    shift

    case "$argument" in
      --dry-run|-n)
        DRY_RUN=true
        ;;
      --no-emoji)
        USE_EMOJI=false
        ;;
      --help|-h)
        if [[ "$action" == "update" ]]; then
          print_update_usage
        else
          print_use_usage
        fi
        exit 0
        ;;
      all)
        add_all_targets "$action"
        ;;
      *)
        ensure_supported_target "$action" "$argument"
        append_unique_target "$argument"
        ;;
    esac
  done

  if [[ "$action" == "update" && ${#TARGETS[@]} -eq 0 ]]; then
    add_all_targets "$action"
  fi

  if [[ "$action" == "use" && ${#TARGETS[@]} -eq 0 ]]; then
    log_error "At least one target is required for use"
    print_use_usage
    exit 1
  fi

  RUN_TARGETS="$(IFS=,; printf '%s' "${TARGETS[*]}")"
}

resolve_kitty_config_dir() {
  if [[ -n "${KITTY_CONFIG_DIRECTORY:-}" ]]; then
    printf '%s' "$KITTY_CONFIG_DIRECTORY"
    return 0
  fi

  local xdg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
  local macos_dir="$HOME/Library/Preferences/kitty"
  local system_name="$(uname -s)"

  if [[ -d "$xdg_dir" || -f "$xdg_dir/kitty.conf" ]]; then
    printf '%s' "$xdg_dir"
    return 0
  fi

  if [[ "$system_name" == "Darwin" ]]; then
    if [[ -d "$macos_dir" || -f "$macos_dir/kitty.conf" ]]; then
      printf '%s' "$macos_dir"
      return 0
    fi

    printf '%s' "$macos_dir"
    return 0
  fi

  printf '%s' "$xdg_dir"
}

tool_home_path() {
  case "$1" in
    claude) printf '%s/.claude' "$HOME" ;;
    codex) printf '%s/.codex' "$HOME" ;;
    gemini) printf '%s/.gemini' "$HOME" ;;
    zshrc) printf '%s/.zshrc' "${ZDOTDIR:-$HOME}" ;;
    kitty) printf '%s' "$(resolve_kitty_config_dir)" ;;
    snow) printf '%s/.snow' "$HOME" ;;
    agents) printf '%s/AGENTS.md' "$HOME" ;;
  esac
}

tool_repo_path() {
  case "$1" in
    claude) printf '%s/claude' "$REPO_DIR" ;;
    codex) printf '%s/codex' "$REPO_DIR" ;;
    gemini) printf '%s/gemini' "$REPO_DIR" ;;
    zshrc) printf '%s/zsh/.zshrc' "$REPO_DIR" ;;
    kitty) printf '%s/kitty' "$REPO_DIR" ;;
    snow) printf '%s/snow' "$REPO_DIR" ;;
    agents) printf '%s/AGENTS.md' "$REPO_DIR" ;;
  esac
}

tool_is_file_tool() {
  case "$1" in
    zshrc|agents) return 0 ;;
    *) return 1 ;;
  esac
}

relative_to_repo() {
  printf '%s' "${1#"$REPO_DIR"/}"
}

tool_requires_redaction() {
  case "$1" in
    claude|codex|gemini|zshrc|kitty|snow) return 0 ;;
    *) return 1 ;;
  esac
}

build_rsync_excludes() {
  local tool="$1"

  RSYNC_EXCLUDES=()

  case "$tool" in
    claude)
      RSYNC_EXCLUDES=(
        --exclude=backups/
        --exclude=cache/
        --exclude=file-history/
        --exclude=history.jsonl
        --exclude=ccline/ccline
        --exclude=homunculus/projects/
        --exclude=homunculus/projects.json
        --exclude=metrics/
        --exclude=paste-cache/
        --exclude=plans/
        --exclude=plugins/cache/
        --exclude=plugins/install-counts-cache.json
        --exclude=plugins/marketplaces/
        --exclude=projects/
        --exclude=session-env/
        --exclude=sessions/
        --exclude=shell-snapshots/
        --exclude=tasks/
        --exclude=telemetry/
        --exclude=.DS_Store
      )
      ;;
    codex)
      RSYNC_EXCLUDES=(
        --exclude=.tmp/
        --exclude=installation_id
        --exclude=log/
        --exclude=logs_*.sqlite
        --exclude=*.sqlite-shm
        --exclude=*.sqlite-wal
        --exclude=memories/
        --exclude=sessions/
        --exclude=shell_snapshots/
        --exclude=skills/.system/
        --exclude=state_*.sqlite
        --exclude=tmp/
        --exclude=history.jsonl
        --exclude=.DS_Store
      )
      ;;
    gemini)
      RSYNC_EXCLUDES=(
        --exclude=history/
        --exclude=tmp/
        --exclude=installation_id
        --exclude=projects.json
        --exclude=state.json
        --exclude=.DS_Store
      )
      ;;
    kitty)
      RSYNC_EXCLUDES=(
        --exclude=.DS_Store
      )
      ;;
    snow)
      RSYNC_EXCLUDES=(
        --exclude=history/
        --exclude=log/
        --exclude=notebook/
        --exclude=sessions/
        --exclude=snapshots/
        --exclude=todos/
        --exclude=usage/
        --exclude=active-profile.json
        --exclude=codebase.json
        --exclude=command-usage.json
        --exclude=history.json
        --exclude=mcp-config.json.save
        --exclude=.DS_Store
      )
      ;;
  esac
}

is_excluded_path() {
  local tool="$1"
  local relative_path="$2"

  case "$tool" in
    claude)
      case "$relative_path" in
        backups|backups/*|cache|cache/*|file-history|file-history/*|history.jsonl|ccline/ccline|homunculus/projects|homunculus/projects/*|homunculus/projects.json|metrics|metrics/*|paste-cache|paste-cache/*|plans|plans/*|plugins/cache|plugins/cache/*|plugins/install-counts-cache.json|plugins/marketplaces|plugins/marketplaces/*|projects|projects/*|session-env|session-env/*|sessions|sessions/*|shell-snapshots|shell-snapshots/*|tasks|tasks/*|telemetry|telemetry/*|.DS_Store)
          return 0
          ;;
      esac
      ;;
    codex)
      case "$relative_path" in
        .tmp|.tmp/*|installation_id|log|log/*|logs_*.sqlite|*.sqlite-shm|*.sqlite-wal|memories|memories/*|sessions|sessions/*|shell_snapshots|shell_snapshots/*|skills/.system|skills/.system/*|state_*.sqlite|tmp|tmp/*|history.jsonl|.DS_Store)
          return 0
          ;;
      esac
      ;;
    gemini)
      case "$relative_path" in
        history|history/*|tmp|tmp/*|installation_id|projects.json|state.json|.DS_Store)
          return 0
          ;;
      esac
      ;;
    kitty)
      case "$relative_path" in
        .DS_Store)
          return 0
          ;;
      esac
      ;;
    snow)
      case "$relative_path" in
        history|history/*|log|log/*|notebook|notebook/*|sessions|sessions/*|snapshots|snapshots/*|todos|todos/*|usage|usage/*|active-profile.json|codebase.json|command-usage.json|history.json|mcp-config.json.save|.DS_Store)
          return 0
          ;;
      esac
      ;;
  esac

  return 1
}

is_sensitive_restore_path() {
  local relative_path="$1"

  case "$relative_path" in
    auth.json|*/auth.json|.env|*/.env|.env.*|*/.env.*|credentials.json|*/credentials.json|tokens.json|*/tokens.json)
      return 0
      ;;
  esac

  return 1
}

is_text_file() {
  local path="$1"

  if [[ ! -s "$path" ]]; then
    return 0
  fi

  LC_ALL=C grep -Iq . "$path"
}

is_redactable_path() {
  local path="$1"

  case "$path" in
    *.json|*.jsonc|*.toml|*.yaml|*.yml|*.ini|*.conf|*.cfg|*.properties|*.env|*/.env|.env|.env.*|*/.env.*|.zshrc|*/.zshrc|.zprofile|*/.zprofile|.zshenv|*/.zshenv|.zlogin|*/.zlogin)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

redact_file_in_place() {
  local path="$1"
  local result=""

  is_redactable_path "$path" || return 1
  is_text_file "$path" || return 1

  result="$(perl "$REPO_DIR/scripts/redact-sensitive.pl" "$path")"
  [[ "$result" == "changed" ]]
}

sanitize_tree() {
  local root_path="$1"
  local file_path=""
  local relative_path=""

  LAST_SANITIZED_COUNT=0

  if $DRY_RUN; then
    log_info "dry-run: skip writing redacted files"
    return 0
  fi

  while IFS= read -r file_path; do
    if redact_file_in_place "$file_path"; then
      LAST_SANITIZED_COUNT=$((LAST_SANITIZED_COUNT + 1))
      relative_path="$(relative_to_repo "$file_path")"
      log_mask "$relative_path"
    fi
  done < <(find "$root_path" -type f | sort)
}

sanitize_file() {
  local path="$1"
  local relative_path=""

  LAST_SANITIZED_COUNT=0

  if $DRY_RUN; then
    log_info "dry-run: skip writing redacted file"
    return 0
  fi

  if redact_file_in_place "$path"; then
    LAST_SANITIZED_COUNT=1
    relative_path="$(relative_to_repo "$path")"
    log_mask "$relative_path"
  fi
}

file_contains_placeholder() {
  local path="$1"

  grep -Fq "$REDACTED_PLACEHOLDER" "$path"
}

copy_file() {
  local source_path="$1"
  local destination_path="$2"

  if $DRY_RUN; then
    return 0
  fi

  mkdir -p "$(dirname "$destination_path")"
  cp -p "$source_path" "$destination_path"
}

merge_redacted_file() {
  local source_path="$1"
  local destination_path="$2"
  local output_path="$3"

  perl "$REPO_DIR/scripts/merge-redacted.pl" "$source_path" "$destination_path" "$output_path"
}

record_conflict() {
  local tool="$1"
  local relative_path="$2"
  local detail="$3"

  SUMMARY_CONFLICTS=$((SUMMARY_CONFLICTS + 1))
  printf '%s action=%s tool=%s path=%s detail=%s\n' \
    "$RUN_TIMESTAMP" "$ACTION" "$tool" "$relative_path" "$detail" >> "$CONFLICTS_PATH"
}

setup_run_recording() {
  RUN_TIMESTAMP="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  RECORD_DIR="$REPO_DIR/$RECORD_DIR_NAME"
  LATEST_LOG_PATH="$RECORD_DIR/latest.log"
  SUMMARY_PATH="$RECORD_DIR/latest-summary.txt"
  HISTORY_PATH="$RECORD_DIR/history.log"
  HISTORY_JSONL_PATH="$RECORD_DIR/history.jsonl"
  CONFLICTS_PATH="$RECORD_DIR/conflicts.log"

  mkdir -p "$RECORD_DIR"
  : > "$LATEST_LOG_PATH"
  touch "$HISTORY_PATH" "$HISTORY_JSONL_PATH" "$CONFLICTS_PATH"

  RECORDING_ACTIVE=true

  log_record "records: $RECORD_DIR"
  log_info "targets: $RUN_TARGETS"
  log_info "dry-run: $DRY_RUN"
}

print_run_summary() {
  local action_name="$1"

  printf '\n'
  log_info "summary for $action_name"
  log_ok "succeeded: $SUMMARY_OK"

  if [[ "$SUMMARY_SKIP" -gt 0 ]]; then
    log_skip "skipped: $SUMMARY_SKIP"
  else
    log_info "skipped: 0"
  fi

  if [[ "$SUMMARY_FAIL" -gt 0 ]]; then
    log_error "failed: $SUMMARY_FAIL"
  else
    log_info "failed: 0"
  fi

  if [[ "$SUMMARY_MASKED" -gt 0 ]]; then
    log_mask "redacted files: $SUMMARY_MASKED"
  else
    log_info "redacted files: 0"
  fi

  if [[ "$SUMMARY_COPIED" -gt 0 ]]; then
    log_copy "copied files: $SUMMARY_COPIED"
  else
    log_info "copied files: 0"
  fi

  if [[ "$SUMMARY_MERGED" -gt 0 ]]; then
    log_merge "merged files: $SUMMARY_MERGED"
  else
    log_info "merged files: 0"
  fi

  if [[ "$SUMMARY_CONFLICTS" -gt 0 ]]; then
    log_warn "conflicts: $SUMMARY_CONFLICTS (see $CONFLICTS_PATH)"
  else
    log_ok "conflicts: 0"
  fi

  log_record "latest log: $LATEST_LOG_PATH"
  log_record "summary: $SUMMARY_PATH"
  log_record "history jsonl: $HISTORY_JSONL_PATH"
}

json_escape() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"

  printf '%s' "$value"
}

json_targets_array() {
  local index=0
  local target=""

  printf '['
  for target in "${TARGETS[@]}"; do
    if [[ "$index" -gt 0 ]]; then
      printf ','
    fi
    printf '"%s"' "$(json_escape "$target")"
    index=$((index + 1))
  done
  printf ']'
}

write_run_summary() {
  local json_targets="$(json_targets_array)"

  cat > "$SUMMARY_PATH" <<EOF_SUMMARY
timestamp=$RUN_TIMESTAMP
action=$ACTION
targets=$RUN_TARGETS
dry_run=$DRY_RUN
ok=$SUMMARY_OK
skipped=$SUMMARY_SKIP
failed=$SUMMARY_FAIL
redacted=$SUMMARY_MASKED
copied=$SUMMARY_COPIED
merged=$SUMMARY_MERGED
conflicts=$SUMMARY_CONFLICTS
EOF_SUMMARY

  printf '%s action=%s targets=%s dry_run=%s ok=%s skipped=%s failed=%s redacted=%s copied=%s merged=%s conflicts=%s\n' \
    "$RUN_TIMESTAMP" "$ACTION" "$RUN_TARGETS" "$DRY_RUN" "$SUMMARY_OK" "$SUMMARY_SKIP" "$SUMMARY_FAIL" "$SUMMARY_MASKED" "$SUMMARY_COPIED" "$SUMMARY_MERGED" "$SUMMARY_CONFLICTS" >> "$HISTORY_PATH"

  printf '{"timestamp":"%s","action":"%s","targets":%s,"dry_run":%s,"ok":%s,"skipped":%s,"failed":%s,"redacted":%s,"copied":%s,"merged":%s,"conflicts":%s}\n' \
    "$(json_escape "$RUN_TIMESTAMP")" \
    "$(json_escape "$ACTION")" \
    "$json_targets" \
    "$DRY_RUN" \
    "$SUMMARY_OK" \
    "$SUMMARY_SKIP" \
    "$SUMMARY_FAIL" \
    "$SUMMARY_MASKED" \
    "$SUMMARY_COPIED" \
    "$SUMMARY_MERGED" \
    "$SUMMARY_CONFLICTS" >> "$HISTORY_JSONL_PATH"
}

run_update_tree() {
  local tool="$1"
  local source_path="$(tool_home_path "$tool")"
  local destination_path="$(tool_repo_path "$tool")"

  log_section "update $tool"
  log_info "from: $source_path"
  log_info "to:   $destination_path"

  if [[ ! -d "$source_path" ]]; then
    SUMMARY_SKIP=$((SUMMARY_SKIP + 1))
    log_skip "$tool source not found"
    return 0
  fi

  build_rsync_excludes "$tool"

  if $DRY_RUN; then
    rsync -an --delete --delete-excluded "${RSYNC_EXCLUDES[@]}" "$source_path/" "$destination_path/"
  else
    mkdir -p "$destination_path"
    rsync -a --delete --delete-excluded "${RSYNC_EXCLUDES[@]}" "$source_path/" "$destination_path/"
  fi

  if tool_requires_redaction "$tool"; then
    sanitize_tree "$destination_path"
    SUMMARY_MASKED=$((SUMMARY_MASKED + LAST_SANITIZED_COUNT))
    log_ok "update $tool (redacted $LAST_SANITIZED_COUNT files)"
  else
    log_ok "update $tool"
  fi

  SUMMARY_OK=$((SUMMARY_OK + 1))
}

run_update_file() {
  local tool="$1"
  local source_path="$(tool_home_path "$tool")"
  local destination_path="$(tool_repo_path "$tool")"

  log_section "update $tool"
  log_info "from: $source_path"
  log_info "to:   $destination_path"

  if [[ ! -f "$source_path" ]]; then
    SUMMARY_SKIP=$((SUMMARY_SKIP + 1))
    log_skip "$tool source not found"
    return 0
  fi

  if $DRY_RUN; then
    log_info "$tool dry-run: would copy file"
  else
    mkdir -p "$(dirname "$destination_path")"
    cp "$source_path" "$destination_path"
  fi

  if tool_requires_redaction "$tool"; then
    sanitize_file "$destination_path"
    SUMMARY_MASKED=$((SUMMARY_MASKED + LAST_SANITIZED_COUNT))
    log_ok "update $tool (redacted $LAST_SANITIZED_COUNT files)"
  else
    log_ok "update $tool"
  fi

  SUMMARY_OK=$((SUMMARY_OK + 1))
}

run_update_target() {
  local tool="$1"

  if tool_is_file_tool "$tool"; then
    run_update_file "$tool"
    return 0
  fi

  run_update_tree "$tool"
}

run_use_tree() {
  local tool="$1"
  local source_root="$(tool_repo_path "$tool")"
  local destination_root="$(tool_home_path "$tool")"
  local source_path=""
  local relative_path=""
  local destination_path=""
  local copied_count=0
  local merged_count=0
  local skipped_count=0
  local temp_path=""

  log_section "use $tool"
  log_info "from: $source_root"
  log_info "to:   $destination_root"

  if [[ ! -d "$source_root" ]]; then
    SUMMARY_SKIP=$((SUMMARY_SKIP + 1))
    log_skip "$tool backup not found"
    return 0
  fi

  while IFS= read -r source_path; do
    relative_path="${source_path#"$source_root"/}"

    if is_excluded_path "$tool" "$relative_path"; then
      skipped_count=$((skipped_count + 1))
      log_skip "$tool $relative_path (runtime path)"
      continue
    fi

    if is_sensitive_restore_path "$relative_path"; then
      skipped_count=$((skipped_count + 1))
      log_skip "$tool $relative_path (sensitive file)"
      record_conflict "$tool" "$relative_path" "sensitive file skipped"
      continue
    fi

    destination_path="$destination_root/$relative_path"

    if file_contains_placeholder "$source_path"; then
      if [[ ! -f "$destination_path" ]]; then
        skipped_count=$((skipped_count + 1))
        log_skip "$tool $relative_path (needs local secret values)"
        record_conflict "$tool" "$relative_path" "missing local file for redacted values"
        continue
      fi

      temp_path="$(mktemp)"
      merge_redacted_file "$source_path" "$destination_path" "$temp_path"

      if file_contains_placeholder "$temp_path"; then
        rm -f "$temp_path"
        skipped_count=$((skipped_count + 1))
        log_skip "$tool $relative_path (unresolved redacted values)"
        record_conflict "$tool" "$relative_path" "unresolved redacted values"
        continue
      fi

      copy_file "$temp_path" "$destination_path"
      rm -f "$temp_path"
      merged_count=$((merged_count + 1))
      SUMMARY_MERGED=$((SUMMARY_MERGED + 1))
      log_merge "$tool $relative_path"
      continue
    fi

    copy_file "$source_path" "$destination_path"
    copied_count=$((copied_count + 1))
    SUMMARY_COPIED=$((SUMMARY_COPIED + 1))
    log_copy "$tool $relative_path"
  done < <(find "$source_root" -type f | sort)

  SUMMARY_OK=$((SUMMARY_OK + 1))
  log_ok "use $tool (copied $copied_count, merged $merged_count, skipped $skipped_count)"
}

run_use_file() {
  local tool="$1"
  local source_path="$(tool_repo_path "$tool")"
  local destination_path="$(tool_home_path "$tool")"
  local relative_path="$(relative_to_repo "$source_path")"
  local temp_path=""

  log_section "use $tool"
  log_info "from: $source_path"
  log_info "to:   $destination_path"

  if [[ ! -f "$source_path" ]]; then
    SUMMARY_SKIP=$((SUMMARY_SKIP + 1))
    log_skip "$tool backup not found"
    return 0
  fi

  if file_contains_placeholder "$source_path"; then
    if [[ ! -f "$destination_path" ]]; then
      SUMMARY_SKIP=$((SUMMARY_SKIP + 1))
      log_skip "$tool ${relative_path##*/} (needs local secret values)"
      record_conflict "$tool" "$relative_path" "missing local file for redacted values"
      return 0
    fi

    temp_path="$(mktemp)"
    merge_redacted_file "$source_path" "$destination_path" "$temp_path"

    if file_contains_placeholder "$temp_path"; then
      rm -f "$temp_path"
      SUMMARY_SKIP=$((SUMMARY_SKIP + 1))
      log_skip "$tool ${relative_path##*/} (unresolved redacted values)"
      record_conflict "$tool" "$relative_path" "unresolved redacted values"
      return 0
    fi

    copy_file "$temp_path" "$destination_path"
    rm -f "$temp_path"
    SUMMARY_MERGED=$((SUMMARY_MERGED + 1))
    SUMMARY_OK=$((SUMMARY_OK + 1))
    log_merge "$tool ${relative_path##*/}"
    log_ok "use $tool"
    return 0
  fi

  copy_file "$source_path" "$destination_path"
  SUMMARY_COPIED=$((SUMMARY_COPIED + 1))
  SUMMARY_OK=$((SUMMARY_OK + 1))
  log_copy "$tool ${relative_path##*/}"
  log_ok "use $tool"
}

run_use_target() {
  local tool="$1"

  if tool_is_file_tool "$tool"; then
    run_use_file "$tool"
    return 0
  fi

  run_use_tree "$tool"
}

run_update_main() {
  parse_targets update "$@"
  setup_run_recording

  local tool=""
  for tool in "${TARGETS[@]}"; do
    run_update_target "$tool"
  done

  log_done "update finished"
  print_run_summary update
  write_run_summary
}

run_use_main() {
  parse_targets use "$@"
  setup_run_recording

  local tool=""
  for tool in "${TARGETS[@]}"; do
    run_use_target "$tool"
  done

  log_done "use finished"
  print_run_summary use
  write_run_summary
}
