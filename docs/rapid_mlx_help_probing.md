# Rapid-MLX Help Probing

This document describes how MLX Server Manager reads the supported launch flags of a configured runtime executable, and why Rapid-MLX needs one extra probe.

It documents existing behavior of the Runtime Compatibility Matrix and Start preflight. It does not change Direct Mode, process ownership, or any lifecycle behavior.

## Why Rapid-MLX needs `serve --help`

Rapid-MLX is launched as a subcommand:

```
rapid-mlx serve <model> --host <host> --port <port> [options]
```

Options that apply only to `serve`, such as `--no-thinking`, are listed by `rapid-mlx serve --help`. The top-level `rapid-mlx --help` lists only the top-level options.

Reading only the top-level help made Start preflight report a false error for a supported option:

```
This Rapid-MLX executable does not support the configured launch options: --no-thinking.
```

## What is probed

The app runs short-lived, bounded invocations of the configured executable and parses the `--flag` names from their combined standard output and standard error.

| Backend | Invocations |
| --- | --- |
| `mlx_lm.server` | `<executable> --help` |
| Rapid-MLX | `<executable> --help`, then `<executable> serve --help` |

Rules:

- The flags from all invocations are merged into one set.
- Each invocation has its own timeout (5 seconds by default) and a captured-output limit.
- If one invocation fails or times out, the flags from the other are still used. A failing `serve --help` never discards the top-level flags.
- If no flags can be detected at all, support is reported as unknown, which does not block Start.
- `--version` is read separately for the version display and is not part of flag detection.

## When it runs

Probing happens on demand, never on a timer or in the background. For example:

- When Start preflight checks the configured launch options of a profile.
- When the Runtime Compatibility Matrix is checked.

Capability results used by Start preflight are cached per executable path and backend, and are invalidated when the executable's size or modification date changes. A cached result for one backend is never reused for the other backend with the same path.

## What it never does

- Does not start a server or load a model.
- Does not send network requests or generate model output.
- Does not install, repair, or modify the runtime.
- Does not run any command other than `--help` and `serve --help` for flag detection.

## Checking by hand

From a terminal, using the executable path configured in Settings:

```
/path/to/rapid-mlx --help | grep -e '--no-thinking'
/path/to/rapid-mlx serve --help | grep -e '--no-thinking'
```

The first command normally prints nothing and the second prints the option. If the second command prints nothing, the installed Rapid-MLX version does not provide the option and the app's report is correct.

If the app still reports the option as unsupported while `serve --help` lists it, check that the executable path in Settings is the one you tested, then run the Runtime Compatibility Matrix again.

## Test coverage

`MLXServerManagerTests/RapidMLXServeHelpProbeTests.swift` runs a fake executable that lists `--no-thinking` only under `serve --help`, matching Rapid-MLX's layout. It covers:

- Rapid-MLX probing merges `serve --help` flags with top-level flags.
- mlx-lm probing never runs `serve --help`.
- A failing `serve --help` keeps the top-level flags.
- Cached results are kept per backend and reused for repeated probes.
- A missing executable is unavailable.
- The Runtime Compatibility Matrix reports reasoning control as supported for Rapid-MLX.
