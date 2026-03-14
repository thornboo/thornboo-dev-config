# Codex Global Agent Instructions

## Core Principles

1. **Plan Before Execute** — Break down complex tasks, clarify dependencies before coding
2. **Test-Driven** — Write tests before implementation, 80%+ coverage required
3. **Security-First** — Validate all inputs, never hardcode secrets
4. **Immutability** — Always create new objects, never mutate existing ones
5. **Small Commits** — Commit after each independent unit of work

## Coding Style

**Immutability (CRITICAL):** Always return new objects. Never modify in place.

**File organization:** Many small files over few large ones. 200-400 lines typical, 800 max. Organize by feature/domain, not by type. High cohesion, low coupling.

**Error handling:** Handle errors at every level. User-friendly messages in UI code. Detailed context logged server-side. Never silently swallow errors.

**Input validation:** Validate all external data at system boundaries. Use schema-based validation. Fail fast with clear messages. Never trust external data.

**Code quality:**
- Functions small (<50 lines), files focused (<800 lines)
- No deep nesting (>4 levels)
- No hardcoded values, no unhandled errors
- Readable, well-named identifiers

## Testing Requirements

**Minimum coverage: 80%**

Test types (all required):
1. **Unit tests** — Functions, utilities, components
2. **Integration tests** — API endpoints, database operations
3. **E2E tests** — Critical user flows

**TDD workflow (mandatory):**
1. Write test first (RED) — test should FAIL
2. Write minimal implementation (GREEN) — test should PASS
3. Refactor (IMPROVE) — verify coverage 80%+

## Security Guidelines

**Before ANY commit:**
- No hardcoded secrets (API keys, passwords, tokens)
- All user inputs validated
- SQL injection prevention (parameterized queries)
- XSS prevention (sanitized HTML output)
- CSRF protection enabled
- Authentication/authorization verified
- Rate limiting on all endpoints
- Error messages don't leak sensitive data

**If security issue found:** STOP → fix CRITICAL issues → rotate exposed secrets → review codebase for similar issues.

## Development Workflow

1. **Research & Reuse** — GitHub search first, then official docs, then write from scratch
2. **Plan** — Break down tasks, identify dependencies and risks, work in phases
3. **TDD** — Write tests first, implement, refactor
4. **Review** — Address CRITICAL/HIGH issues before moving on
5. **Commit** — Conventional commits format

## Git Workflow

**Commit format:** `<type>: <description>`
Types: feat, fix, refactor, docs, test, chore, perf, ci

**PR workflow:** Analyze full commit history → draft comprehensive summary → include test plan → push with `-u` flag.

## Architecture Patterns

**API response format:** Consistent envelope with success indicator, data payload, error message, and pagination metadata.

**Repository pattern:** Encapsulate data access behind standard interface (findAll, findById, create, update, delete). Business logic depends on abstract interface, not storage mechanism.

## Performance

**Context management:** Avoid last 20% of context window for large refactoring and multi-file features. Single-file edits, docs, and simple fixes tolerate higher utilization.

## Success Metrics

- All tests pass with 80%+ coverage
- No security vulnerabilities
- Code is readable and maintainable
- Performance is acceptable
- User requirements are met
