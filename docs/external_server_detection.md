# External Server Detection

## Overview

External Server Detection is a Direct Mode improvement for cases where an OpenAI-compatible server is already running on the selected host and port before MLX Server Manager starts its own managed `mlx_lm.server` process.

The first implementation should be detect-only. It should help users understand why a port is busy and whether the existing service appears usable as an OpenAI-compatible endpoint, without taking ownership of that process.

## Implementation Status

v1.5.0 implements the initial detect-only behavior.

- When Start sees the selected host and port are occupied, it checks `GET /v1/models` before reporting a plain port conflict.
- If `/v1/models` returns HTTP 200, the app shows External Server Detected.
- The app does not launch a managed process in that case.
- The app does not collect external server logs.
- The app does not monitor external server memory usage.
- Stop and Restart remain unavailable for external servers.
- Connection Settings remain available and continue to use the selected model profile.
- Adopt External Server is implemented separately as explicit connection context.

Adopt External Server is documented separately in [adopt_external_server.md](adopt_external_server.md). Detection remains conservative and does not imply process ownership.

## Problem Statement

Today, a busy port blocks Start. That is safe, but it does not explain whether the busy port is caused by:

- an unrelated service,
- a user-started `mlx_lm.server`,
- another OpenAI-compatible local server, or
- a stale configuration pointing at the wrong host or port.

Users should be able to see when an OpenAI-compatible server appears to be available on the selected host and port, and they should be able to copy connection settings for it. The app must not assume ownership of that external process.

## Goals

- Detect when the selected host and port are busy before Start.
- If the port is busy, check `GET /v1/models` on the selected host and port.
- If `/v1/models` returns HTTP 200, show that an OpenAI-compatible server appears to be running.
- Present model-list information when available, without overclaiming server identity.
- Allow users to copy Base URL, JSON config, and `curl /v1/models` for the selected host and port.
- Keep Stop and Restart limited to app-managed processes.
- Make process ownership clear in the UI.

## Non-goals

- Do not stop, restart, or signal external processes.
- Do not assume every OpenAI-compatible server is `mlx_lm.server`.
- Do not proxy inference requests.
- Do not add a Chat UI.
- Do not add multi-backend routing.
- Do not inspect process tables to take ownership automatically.
- Do not use inference requests for detection.

## Direct Mode Boundary

The inference path remains:

```text
OpenAI-compatible client -> mlx_lm.server or another OpenAI-compatible local server -> model
```

MLX Server Manager stays outside the inference request path. External Server Detection only improves local status visibility and connection-setting copy behavior.

## Managed Server vs External Server

### Managed Server

A managed server is started by MLX Server Manager.

- The app has a `Process` reference.
- The app knows the managed PID.
- Stop and Restart are allowed.
- stdout and stderr can be captured into Logs.
- Memory usage can be monitored for the managed PID.
- Start, Stop, Restart, Ready Check, Port Check, and memory display use the existing managed-process design.

### External Server

An external server is already running outside MLX Server Manager.

- The app does not have a `Process` reference.
- The app does not own the PID.
- Stop and Restart are not allowed.
- stdout and stderr are not available to the app.
- Memory usage is not monitored.
- Ready status may be checked through `GET /v1/models`.
- Connection settings may be copied for use by OpenAI-compatible clients.

The UI should use wording like:

```text
An OpenAI-compatible server appears to be running on this host/port.
```

It should not say that the server is definitely `mlx_lm.server` unless future evidence supports that safely.

## Detection Strategy

1. User presses Start.
2. The existing Port Checker runs against the selected host and port.
3. If the port is available, normal managed Start continues.
4. If the port is busy, the app does not start a new process.
5. The app runs the existing Ready Checker against `GET /v1/models` on the same host and port.
6. If `/v1/models` returns HTTP 200, set external-server-detected state.
7. If `/v1/models` fails, keep the port-conflict state and explain that another process may be using the port.

Detection should be conservative. A successful `/v1/models` response means the endpoint appears OpenAI-compatible enough for connection settings and readiness display. It does not mean the app owns the process.

## UI States

The UI should distinguish these states:

- `stopped`: no managed server attached and selected port appears available.
- `checking port`: the app is checking whether the selected port can be used.
- `port conflict`: the selected port is busy and no compatible `/v1/models` response was confirmed.
- `external server detected`: the selected port is busy and `/v1/models` returned HTTP 200.
- `managed server running`: the app has a managed `Process` reference and PID.
- `ready`: the current managed or external-compatible endpoint passed `/v1/models`.
- `error`: a check or operation failed.

For an external server, the UI should clearly show:

- External server detected.
- Not managed by MLX Server Manager.
- Stop and Restart are unavailable for this server.
- Connection settings can still be copied.

## Adopt External Server Design

The initial design should be detect-only. A future explicit Adopt External Server action may be considered, but it must be conservative.

Potential future adopt behavior:

- User explicitly chooses Adopt External Server.
- App stores the selected host, port, and model ID as a connection target.
- App marks the process as external, not managed.
- Stop and Restart remain unavailable unless a future safe ownership model is designed.
- Logs and memory display remain unavailable unless a safe, explicit source exists.

Adopt should never happen automatically. Detection is not ownership.

## Safety Boundaries

- Do not automatically terminate or restart external processes.
- Do not use process-name based termination.
- Do not assume a busy port belongs to `mlx_lm.server`.
- Do not assume every OpenAI-compatible endpoint is safe to manage.
- Do not add Proxy mode.
- Do not add Chat UI.
- Do not send inference requests for detection.
- Use `/v1/models` only for external readiness detection.
- Keep Direct Mode.
- Keep Start, Stop, Restart, logs, and memory monitoring scoped to managed processes.

## Process Ownership Policy

Process ownership is determined by whether MLX Server Manager created the process and retained its `Process` reference.

- Created by app: managed.
- Not created by app: external.
- PID unknown or discovered indirectly: external.
- Port busy with compatible response: external-compatible endpoint.

The app may present external endpoint status, but it must not present external-process controls as if the process were managed.

## Readiness Behavior

Managed and external servers can both use `GET /v1/models` for readiness display.

For managed servers:

- Start updates status through starting, loading, and ready.
- Ready success confirms the managed endpoint is serving.

For external servers:

- Ready success confirms only that the selected host and port respond to `/v1/models`.
- The app should show external ready status separately from managed ready status.
- Ready failure should not imply that the external process should be stopped.

## Memory and Log Limitations

External servers have limited visibility:

- No captured stdout or stderr.
- No managed PID memory monitoring.
- No Stop or Restart.
- No process lifecycle events.

Logs should include only app-side checks, such as:

- port busy,
- external `/v1/models` check started,
- external server detected,
- external readiness failed,
- connection settings copied.

The UI should show memory as Not available for external servers rather than Not running.

## User Flows

### Start When No Server Is Running

1. User selects a model profile.
2. User presses Start.
3. Port is available.
4. App starts managed `mlx_lm.server`.
5. App stores managed PID.
6. Ready Check succeeds.
7. Status becomes ready.

### Start When Compatible External Server Is Running

1. User selects host and port.
2. User presses Start.
3. Port is busy.
4. App checks `/v1/models`.
5. `/v1/models` returns HTTP 200.
6. UI shows external server detected.
7. Stop and Restart remain unavailable for the external server.
8. Connection Settings remain available.

### Start When Non-compatible Process Uses the Port

1. User presses Start.
2. Port is busy.
3. `/v1/models` fails.
4. UI shows port conflict.
5. App does not start a managed server.
6. App does not stop the external process.

### Stop With External Server Detected

Stop should not target external servers. If no managed process is attached, Logs should say that no managed server is running.

### Restart With External Server Detected

Restart should not target external servers. If no managed process is attached, the UI should either disable Restart or explain that Restart is only available for app-managed processes.

## Testing Plan

- No server running: Start creates a managed process normally.
- Managed server running: Stop and Restart affect only the managed process.
- External OpenAI-compatible server on selected port: detection shows external server detected after `/v1/models` returns HTTP 200.
- Non-OpenAI service on selected port: detection shows port conflict and does not claim compatibility.
- Busy port with failing `/v1/models`: no external-compatible state is shown.
- External server detected, then port changes: external state is cleared or rechecked.
- Connection Settings copy works for the selected external host and port.
- Stop does not terminate an external server.
- Restart is unavailable or clearly blocked for external servers.
- Logs distinguish managed server events from external detection checks.
- Memory display shows Not available for external servers.

## Future Work

- Optional explicit Adopt External Server state for connection-setting convenience.
- Safer UI language for external endpoint identity and ownership.
- External model-list display if `/v1/models` returns useful model data.
- Better troubleshooting text for port conflicts.
- Optional manual refresh for external readiness.
- Tests for state transitions between stopped, port conflict, external detected, and managed running.
