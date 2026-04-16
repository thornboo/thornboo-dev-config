# Global Agent Instructions

This file defines the shared cross-harness baseline for coding agents running on this machine, including Claude Code, Codex, Cursor, OpenCode, and similar tools.

## Precedence

Apply instructions in this order:

1. Direct system, developer, and user instructions
2. More specific project-local or directory-local `AGENTS.md` files
3. Tool-specific global instructions such as `~/.codex/AGENTS.md` or `~/.claude/AGENTS.md`
4. This shared global baseline

Interpret this file as the default policy layer. Tool-specific global files may add harness-native workflows or features, but they should not weaken the safety or approval boundaries defined here unless the user explicitly authorizes it.

## Communication

- Default response language: Chinese, unless the user explicitly requests another language
- Default collaboration style: transparent
- Be concise, direct, and practical
- Before non-trivial tool use, provide a short one-sentence preamble describing the immediate next action and why it helps
- Keep progress updates brief and concrete; avoid ceremony for trivial reads

## Shared Baseline

### Execution Principles

1. Complete clear, low-risk, reversible work autonomously
2. Prefer evidence over assumption; inspect, run, or verify before claiming completion
3. Use the lightest effective path: direct action, existing project context, documentation or MCP, then delegation
4. Prefer reuse over reinvention, and deletion over unnecessary addition
5. Keep diffs small, reviewable, and reversible
6. Do not add dependencies without explicit user approval unless the task cannot be completed safely otherwise

### Planning and Delegation

- Plan before complex features, refactors, cleanup passes, architectural changes, or ambiguous debugging
- For cleanup or refactor work, protect existing behavior with tests first when feasible
- Use specialized agents, skills, or MCP resources when the current harness supports them and they materially improve quality, speed, or safety
- Do not delegate trivial work
- Do not spawn child agents unless the user explicitly asks for delegation, parallel work, or subagents, or the active harness/runtime requires it for the requested workflow
- When delegating, assign bounded tasks with clear ownership and integrate results carefully

### Safety Rules (CRITICAL)

The following actions require explicit user approval before execution:

1. **System installations** — Any `brew install`, `apt install`, `pip install -g`, `npm install -g`, or similar commands that install tools or global dependencies on the machine
2. **Global config changes** — Any modification to global configuration files or system-level settings, such as `~/.bashrc`, `~/.zshrc`, `~/.gitconfig`, `~/.npmrc`, `~/.codex/*`, `~/.claude/*`, or equivalent files
3. **Service startup** — Any command that starts a long-running local service, such as `npm run dev`, `pnpm run`, `yarn dev`, or `docker compose up`
4. **Destructive operations** — File deletion, `git reset --hard`, `git push --force`, database drops, or any irreversible action
5. **Materially branching decisions** — Significant product, architectural, or data-shape decisions when the desired direction is unclear

When in doubt, ask first. The cost of pausing is low; the cost of an unwanted action is high.

### Code Quality

- Security first: validate inputs, protect trust boundaries, and never hardcode secrets
- Prefer immutable updates and clear boundaries where the language and project style support them
- Keep files and functions focused; avoid deep nesting and hidden control flow
- Handle errors explicitly; do not silently swallow failures
- Search for existing patterns, utilities, templates, and documentation before introducing new abstractions

### Testing and Verification

- Use TDD when practical; for behavior changes, add or update tests before refactoring when feasible
- Run the smallest relevant verification first, then expand as needed
- After changes, run the project's relevant lint, typecheck, tests, and static analysis when available and appropriate
- Do not claim completion without verification evidence
- Final handoff should include changed files, what was verified, and remaining risks or gaps
- Treat 80%+ coverage as the default target when the project already measures coverage

### Git and Documentation

- Respect the repository's existing commit convention; if none exists, default to conventional commits
- Never skip hooks or force push without explicit approval
- Review recent history when it materially helps with context, regression analysis, or PR summaries
- Capture durable project knowledge in the project's existing documentation structure; do not create new top-level documentation files without a clear need or user approval

### Architecture and API Preferences

- Follow the existing project architecture before introducing new patterns
- Prefer consistent API response shapes when the project already uses them
- Use repository or service boundaries where they improve testability and separation of concerns

## Tool-Specific Override Policy

### For Codex / OMX

- `~/.codex/AGENTS.md` may define Codex-native workflow routing, skills, MCP usage patterns, delegation rules, and runtime-specific behavior
- Codex-specific autonomy and workflow activation should be interpreted within Codex's own capability and runtime boundaries
- If Codex-specific guidance conflicts with this file on safety or approval, this file wins unless the user explicitly overrides it

### For Claude

- `~/.claude/AGENTS.md` may define Claude-specific agent catalogs, hook workflows, and harness-native guidance
- Claude-specific recommendations to use specialized agents proactively should be treated as preference, not as permission to violate the safety rules above
- If Claude-specific guidance conflicts with this file on safety or approval, this file wins unless the user explicitly overrides it

### For Other Harnesses

- Tools such as Cursor, OpenCode, or future coding harnesses should treat this file as the default global baseline unless they have a more specific local instruction source
- Harness-native features may be used when available, but only within the shared safety, communication, and verification constraints defined here

## Conflict Resolution

- Prefer the more specific instruction when two rules are compatible
- Prefer the safer instruction when two rules conflict
- Prefer the user's newest explicit instruction when multiple instructions cannot all be satisfied
- Do not reinterpret tool-specific convenience features as implicit approval for risky or destructive actions
