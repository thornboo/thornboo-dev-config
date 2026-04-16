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

run_redact() {
  local path="$1"

  perl "$REPO_ROOT/scripts/redact-sensitive.pl" "$path" >/dev/null
}

json_case() {
  local path="$TMP_ROOT/settings.json"

  cat <<'DATA' > "$path"
{"apiKey":"test-secret-value","token":"plain-token","theme":"dark"}
DATA

  run_redact "$path"
  assert_contains "$path" '"apiKey":"YOUR-API-KEY"'
  assert_contains "$path" '"token":"YOUR-API-KEY"'
  assert_contains "$path" '"theme":"dark"'
  assert_not_contains "$path" 'test-secret-value'
}

toml_url_case() {
  local path="$TMP_ROOT/config.toml"

  cat <<'DATA' > "$path"
bearer_token_env_var = "GITHUB_PAT_TOKEN"
url = "https://mcp.exa.ai/mcp?exaApiKey=real-url-secret&mode=stdio"
DATA

  run_redact "$path"
  assert_contains "$path" 'bearer_token_env_var = "GITHUB_PAT_TOKEN"'
  assert_contains "$path" 'exaApiKey=YOUR-API-KEY'
  assert_contains "$path" 'mode=stdio'
  assert_not_contains "$path" 'real-url-secret'
}

zsh_case() {
  local path="$TMP_ROOT/.zshrc"

  cat <<'DATA' > "$path"
export GITHUB_PAT_TOKEN="github-token-test-value"
local -a env_vars=(
  "ANTHROPIC_AUTH_TOKEN=anthropic-test-secret"
  "ANTHROPIC_BASE_URL=http://127.0.0.1:8080"
)
DATA

  run_redact "$path"
  assert_contains "$path" 'export GITHUB_PAT_TOKEN=YOUR-API-KEY'
  assert_contains "$path" '"ANTHROPIC_AUTH_TOKEN=YOUR-API-KEY"'
  assert_contains "$path" '"ANTHROPIC_BASE_URL=http://127.0.0.1:8080"'
  assert_not_contains "$path" 'github-token-test-value'
  assert_not_contains "$path" 'anthropic-test-secret'
}

literal_case() {
  local path="$TMP_ROOT/plain.conf"

  cat <<'DATA' > "$path"
endpoint=https://example.com/?token=secret-token-value
note=keep-this
DATA

  run_redact "$path"
  assert_contains "$path" 'token=YOUR-API-KEY'
  assert_contains "$path" 'note=keep-this'
  assert_not_contains "$path" 'secret-token-value'
}

json_case
toml_url_case
zsh_case
literal_case

echo "[PASS] redact-sensitive tests"
