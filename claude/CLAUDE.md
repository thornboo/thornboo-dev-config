# Global Claude Code Configuration

This file provides high-level guidance to Claude Code. Detailed rules are in `~/.claude/rules/`.

## Core Principles

1. **Agent-First** — Delegate to specialized agents for domain tasks
2. **Test-Driven** — Write tests before implementation, 80%+ coverage required
3. **Security-First** — Never compromise on security; validate all inputs
4. **Immutability** — Always create new objects, never mutate existing ones
5. **Plan Before Execute** — Plan complex features before writing code

## Agent Team PUA Configuration

**All teammates MUST load the pua skill before starting work.**

**Failure Reporting:**
- Teammates send a `[PUA-REPORT]` to the Leader after 2+ consecutive failures
- Report includes: failure count, root cause, attempted solutions, current pressure level

**Leader Responsibilities:**
- Manage global pressure levels (dynamically adjust based on teammate reports)
- Propagate failure lessons across teammates (prevent repeated mistakes)
- Decide whether to escalate PUA intensity or reassign the teammate

## Key Commands

- `/tdd` - Test-driven development workflow
- `/plan` - Create implementation plan
- `/code-review` - Review code quality (PR-level, via code-review plugin)
- `/build-fix` - Fix build errors
- `/e2e` - Generate and run E2E tests
- `/learn` - Extract patterns from sessions
- `/skill-create` - Generate skills from git history
