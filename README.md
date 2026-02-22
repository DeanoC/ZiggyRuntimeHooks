# ZiggyRuntimeHooks

Wave-2 extraction module for ZiggySpiderweb runtime/hook layer.

## Current Scope

- `event_bus` extracted from ZiggySpiderweb runtime.
- `hook_primitives` extracted from ZiggySpiderweb hook pipeline:
  - `HookPhase`, `HookError`, `HookPriority`
  - `CorePrompt` / `Rom` and entries
  - `PendingTools`
- `hook_registry_engine` generic priority-ordered hook execution engine.
- `run_engine` lifecycle state machine and persistence-backed run/event orchestration.

## Planned Scope

- Hook pipeline primitives
- Runtime orchestration interfaces

## Build

- `zig build`
- `zig build test`
