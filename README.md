# ZiggyRuntimeHooks

Wave-2 extraction module for ZiggySpiderweb runtime/hook layer.

## Current Scope

- `event_bus` extracted from ZiggySpiderweb runtime.
- `hook_primitives` extracted from ZiggySpiderweb hook pipeline:
  - `HookPhase`, `HookError`, `HookPriority`
  - `CorePrompt` / `Rom` and entries
  - `PendingTools`
- `hook_registry_engine` generic priority-ordered hook execution engine.
- Compatibility re-exports for:
  - `run_engine`
  - `run_orchestration_helpers`
  from `ziggy-run-orchestrator`.

## Planned Scope

- Hook pipeline primitives
- Runtime orchestration interfaces

## Development Checkout

This development line tracks first-party dependencies as git submodules.
Use a recursive checkout instead of a source archive:

```bash
git clone --recursive https://github.com/DeanoC/ZiggyRuntimeHooks.git
```

If you already cloned the repo, initialize submodules with:

```bash
git submodule update --init --recursive
```

Source archive installs are not supported for the current development branch.

## Build

- `zig build`
- `zig build test`
