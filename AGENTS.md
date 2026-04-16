# Agent Instructions

This file is read by Claude Code, Cursor, Codex, and OpenCode.

## Communication

- Always respond in Chinese (中文) unless the user explicitly requests another language
- Be concise and direct, avoid unnecessary verbosity

## Safety Rules (CRITICAL)

The following actions require explicit user approval before execution:

1. **System installations** — Any `brew install`, `apt install`, `pip install -g`, `npm install -g`, or similar commands that install tools or global dependencies on the user's machine
2. **Global config changes** — Never modify global configuration files (e.g., `~/.bashrc`, `~/.zshrc`, `~/.gitconfig`, `~/.npmrc`, system-level settings) without user consent
3. **Service startup** — Never run `npm run`, `pnpm run`, `yarn dev`, `docker compose up`, or any command that starts a long-running service unless the user explicitly agrees
4. **Destructive operations** — File deletion, `git reset --hard`, `git push --force`, dropping databases, or any irreversible action

When in doubt, ask first. The cost of pausing is low; the cost of an unwanted action is high.

## Core Principles

1. **Plan Before Execute** — Plan complex features before writing code
2. **Test-Driven** — Write tests before implementation, 80%+ coverage required
3. **Security-First** — Never compromise on security; validate all inputs
4. **Immutability** — Always create new objects, never mutate existing ones
5. **Research & Reuse** — Search for existing solutions before writing new code

## Coding Style

- **Immutability:** Always return new copies, never mutate in place
- **Small files:** 200-400 lines typical, 800 max. Organize by feature/domain
- **Small functions:** <50 lines, no deep nesting (>4 levels)
- **Error handling:** Handle at every level, never silently swallow
- **Input validation:** Validate at system boundaries, fail fast with clear messages
- **No hardcoded secrets:** Use environment variables or secret managers

## Testing

- Minimum 80% coverage
- TDD workflow: write test (RED) → implement (GREEN) → refactor (IMPROVE)
- Unit, integration, and E2E tests all required

## Git Workflow

- Commit format: `<type>: <description>` (feat, fix, refactor, docs, test, chore, perf, ci)
- Never skip hooks or force push without explicit approval
- Analyze full commit history when creating PRs

## API & Architecture Patterns

- Consistent API response envelope: success indicator, data, error, pagination metadata
- Repository pattern for data access: abstract interface over storage details
