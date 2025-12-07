# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Self Teaching

Update this file with useful lessons learned at the end of changes.

## Philosophy

**Minimal Intervention**: Surgical changes, not broad refactoring. Smallest change that fulfills requirements.

## Elixir Gotchas

- No `list[i]` - use `Enum.at/2`
- No `else if` - use `cond` or `case`
- Rebind in if: `socket = if cond, do: assign(socket, :val, val)`
- Never `struct[:field]` - use `struct.field`
- Never `String.to_atom/1` on user input

## Coding Standards

- Self-alias modules instead of `__MODULE__`
- Magic numbers → `SafekeeperLife.Core.Constants`
- GenServers: `Application.compile_env!/3` for constants, override via `opts`

## Test Guidelines

- `@tag :unit` for pure functions, `@moduletag :slow` for integration
- `async: true` unless: Application env, global state, GenServers, FSM
- `@moduletag :distributed, async: false` for distributed tests

## Project Overview

SecondLife is an Elixir OTP application for archiving downloaded files and duplicating them to NAS storage. It provides a workflow that archives files from a source directory, moves them to a target location, and optionally duplicates archives to network storage.

## Common Commands

```bash
# Development
mix deps.get              # Install dependencies
mix format                # Format code (uses Styler plugin)
mix test                  # Run tests
mix test --max-failures=1 # Run tests, fail fast

# Quality checks (run automatically via git hooks)
mix credo --strict        # Code quality analysis
mix dialyzer              # Type checking
mix sobelow               # Security analysis
mix deps.audit            # Dependency vulnerability audit
mix hex.audit             # Hex package audit

# Build release
mix release               # Build binary release
rel/overlays/archive.sh   # Execute release workflow
```

## Architecture

**Task-Based OTP Design:**
- `SecondLife.Application` starts a `Task.Supervisor` for async task execution
- `SecondLife.Release.run/0` orchestrates the full workflow from CLI arguments
- Tasks are located in `lib/second_life/tasks/`:
  - `ArchiveAndMove` - Archives source directory to zip, moves to target, cleans source
  - `DuplicateArchivesToNas` - Copies archives to NAS with size validation

**File Operations:**
- Archive creation uses Erlang `:zip` module with Base32-encoded names
- Large file copying uses 1MB stream blocks for memory efficiency
- All paths are expanded to absolute paths via `Path.expand()`

**Error Handling:**
- Pipeline-based with `with` expressions
- Returns `{:ok, value}` or `{:error, reason}` tuples

## Code Conventions

- Max line length: 125 characters
- All modules require `@moduledoc` documentation
- Type specs (`@spec`) expected for public APIs
- FIXME comments fail the build; TODO comments are allowed
- Copyright headers required: `Copyright © QixSoft Limited 2002-2025` and `Copyright © octowombat 2021-2025`

## Git Workflow

- Branch naming: `^\d{1,4}-[\w-]*` (e.g., "123-feature-name")
- Direct commits to main are blocked
- Pre-commit hooks: format check, security audit, dependency audit, credo
- Pre-push hooks: dialyzer, tests

## Testing

- Tests in `test/` directory using ExUnit
- Test fixtures in `priv/fixtures/`
- Use `on_exit/1` callbacks for cleanup
