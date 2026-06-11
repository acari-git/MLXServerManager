# Port Check Contract

## Scope

Defines how the app determines whether the configured `mlx_lm.server` port is available.

## Inputs

- Host
- Port
- Optional managed process identifier

## Output States

- Available
- Occupied by managed process
- Occupied by another process
- Invalid host or port
- Check failed

## Required Behavior

- Check port availability before Start.
- Do not launch when the port is occupied by another process.
- Surface a clear error state to the UI.
- Avoid killing or modifying other processes.

## Notes

The implementation may use socket binding checks, system process inspection, or platform APIs. The contract is the observable result, not the specific mechanism.

