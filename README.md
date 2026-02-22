# ZiggyRuntimeHooks

Wave-2 extraction module for ZiggySpiderweb runtime/hook layer.

## Current Scope

- `event_bus` extracted from ZiggySpiderweb runtime.
- `hook_primitives` extracted from ZiggySpiderweb hook pipeline:
  - `HookPhase`, `HookError`, `HookPriority`
  - `CorePrompt` / `Rom` and entries
  - `PendingTools`

## Planned Scope

- Hook pipeline primitives
- Runtime orchestration interfaces

## Build

- `zig build`
- `zig build test`
