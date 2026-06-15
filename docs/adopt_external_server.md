# Adopt External Server

## Overview

Adopt External Server explicitly uses a detected external OpenAI-compatible server as a connection context in MLX Server Manager.

Adopt does not mean process ownership. It means the user has chosen to track and use a detected external endpoint for status display and connection-setting copy behavior.

The initial v1.5.0 External Server Detection feature remains detect-only. v1.7.0 adds explicit Adopt and Forget actions for connection context without process ownership.

## Implementation Status

v1.7.0 implements the initial Adopt External Server behavior.

- Adopt is available only after an external OpenAI-compatible server is detected.
- Adopt changes UI state to Adopted External Server.
- Adopt does not launch a process.
- Adopt does not store a PID.
- Adopt does not start memory monitoring.
- Adopt does not collect external process logs.
- Forget External Server clears only the app-side connection context.
- Stop and Restart remain unavailable for external servers.
- Connection Settings remain available and continue to use the selected model profile.

Connection Settings polish is tracked separately in [connection_settings_polish.md](connection_settings_polish.md). That design focuses on making managed, detected external, and adopted external targets easier to understand and copy without changing the process ownership boundary.

## Problem Statement

External Server Detection can identify that the selected host and port respond to `GET /v1/models`, but the UI still treats that state as transient detection. Users may want a clearer way to say:

- this is the external endpoint I intend to use,
- show it as my current connection target,
- keep connection settings easy to copy,
- continue readiness checks,
- and do not manage the external process.

The challenge is to improve clarity without blurring the ownership boundary between app-managed processes and external processes.

## Goals

- Let users explicitly adopt a detected external server as a connection context.
- Keep adopted external servers separate from managed servers.
- Improve UI state, status wording, and connection settings for adopted external endpoints.
- Continue using readiness checks through `GET /v1/models`.
- Provide a clear Forget External Server flow.
- Preserve Direct Mode and avoid inference proxy behavior.
- Keep Stop and Restart scoped to app-managed processes.

## Non-goals

- Do not convert an external server into a managed process.
- Do not infer PID ownership for external servers.
- Do not stop, restart, or terminate external processes.
- Do not collect external server stdout or stderr.
- Do not monitor external server memory in the initial design.
- Do not add Proxy mode.
- Do not add Chat UI.
- Do not add multi-backend routing.
- Do not use inference requests for adoption or readiness.

## Direct Mode Boundary

The inference path remains:

```text
OpenAI-compatible client -> external server or mlx_lm.server -> MLX model
```

MLX Server Manager stays outside the inference request path. Adopt External Server only improves local UI state and connection-setting behavior.

## Terminology

### Managed Server

A managed server is a process launched by MLX Server Manager.

- The app has the `Process` reference.
- The app knows the managed PID.
- Stop and Restart are available.
- Memory monitoring is available.
- stdout and stderr can be captured in Logs.

### External Server Detected

An external server detected state means:

- the selected host and port are occupied,
- `GET /v1/models` returned HTTP 200,
- the app did not launch the process,
- the app does not own the process,
- Stop and Restart are unavailable,
- memory monitoring and process logs are unavailable.

### Adopted External Server

An adopted external server is a detected external server that the user explicitly chooses as a connection context.

- It remains external.
- It is not a managed process.
- It is not owned by MLX Server Manager.
- It is adopted for connection context only.
- Readiness and connection settings can be shown more prominently.

Recommended UI wording:

```text
This server is adopted for connection context only.
```

## What "Adopt" Means

Adopt means:

- use this host and port as the current external connection target,
- show the endpoint as Adopted External Server,
- keep Base URL and config copy actions available,
- keep readiness checks available,
- optionally show model IDs returned by `/v1/models` as informational data,
- remember that this server is not managed by the app.

Adopt is a user-facing tracking action. It is not process control.

## What "Adopt" Does Not Mean

Adopt does not mean:

- MLX Server Manager launched the server,
- MLX Server Manager owns the PID,
- Stop can stop the external server,
- Restart can restart the external server,
- memory monitoring is available,
- external server logs are available,
- the endpoint is definitely `mlx_lm.server`,
- the app may proxy inference requests.

## Ownership Model

Process ownership remains binary:

- Created by MLX Server Manager: managed.
- Not created by MLX Server Manager: external.

Adopted external servers remain in the external category. The app may hold endpoint context, but it does not hold process ownership.

The ownership model should be visible in the UI. Users should not have to infer it from button availability alone.

## UI Design

External Server Detected state may show:

- External server detected.
- Host and port.
- Base URL.
- Not managed by MLX Server Manager.
- Adopt External Server button.
- Use Connection Settings action.

After adoption, the UI may show:

- Adopted External Server badge.
- Base URL.
- Selected profile model ID.
- Readiness state from `/v1/models`.
- "This server is adopted for connection context only."
- "Not managed by MLX Server Manager."
- Forget External Server button.

Stop and Restart should not be shown as active actions for adopted external servers. If visible for layout consistency, they should be disabled with explanatory text.

The UI should avoid dangerous wording such as "take over", "attach", or "control" because those imply process ownership.

## State Model

Candidate states:

- `stopped`
- `checking port`
- `port busy`
- `external server detected`
- `adopted external server`
- `managed server running`
- `ready`
- `error`

The adopted external state should keep enough context to render:

- host,
- port,
- base URL,
- selected model profile ID,
- readiness message,
- optional model IDs returned by `/v1/models`.

It should not store a PID as an ownership claim.

## User Flows

### Detect and Adopt

1. User presses Start or runs a check on a busy selected port.
2. The app checks `GET /v1/models`.
3. HTTP 200 confirms an OpenAI-compatible endpoint appears to be present.
4. UI shows External Server Detected.
5. User presses Adopt External Server.
6. UI changes to Adopted External Server.
7. Connection Settings remain available.

### Adopted Then Forget

1. User is in Adopted External Server state.
2. User presses Forget External Server.
3. App clears the adopted context.
4. App returns to stopped or external detected state, depending on current check behavior.
5. External process is not affected.

### Adopted Server Disappears

1. User has adopted an external server.
2. A readiness check fails.
3. UI shows disconnected, not ready, or error state.
4. App does not start a replacement managed server automatically.
5. User can forget the external server or change configuration.

### Selected Host or Port Changes

1. User changes the selected host or port.
2. Adopted context is cleared or rechecked.
3. UI makes clear that the previous adopted endpoint no longer matches the current profile.

### Selected Model Changes

1. User selects a different model profile.
2. If the host and port stay the same, connection settings can update to the selected profile.
3. If the host or port changes, adopted context should be cleared or rechecked.
4. The app should not assume the external server actually serves the selected model ID.

### App Relaunch

Initial design should not persist adoption by default. A future design may consider explicit persistence, but relaunch must not accidentally claim process ownership.

## Connection Settings Behavior

Connection Settings should remain based on the selected host and port.

- Base URL points to the adopted external endpoint.
- Model ID may use the selected profile model ID.
- API key remains the local placeholder unless the client requires another dummy value.
- Model IDs from `/v1/models`, if available, are informational only.
- The UI must not assume the external server is `mlx_lm.server`.

The app should continue to provide copy actions for:

- Base URL,
- Model ID,
- OpenAI-compatible config,
- models endpoint curl.

## Stop / Restart Behavior

Stop and Restart remain app-managed-process controls.

For adopted external servers:

- Stop is unavailable.
- Restart is unavailable.
- Forget External Server or Disconnect is the appropriate action.
- Forget does not affect the external process.

Managed server controls remain unchanged for processes launched by MLX Server Manager.

## Memory / Logs Behavior

Initial adopted external server design should not add memory monitoring or external process log collection.

For adopted external servers:

- Memory should show Not available.
- Logs should include app-side checks and user actions only.
- stdout and stderr from the external process are not available.
- Readiness check results may be logged.

## Safety Boundaries

- Adopt requires explicit user action.
- Adopt is connection context, not process ownership.
- Do not automatically stop external processes.
- Do not automatically restart external processes.
- Do not use broad process-name termination commands.
- Do not claim PID ownership for external servers.
- Do not proxy inference requests.
- Do not add Chat UI.
- Do not add multi-backend routing.
- Do not assume all OpenAI-compatible servers are `mlx_lm.server`.
- Do not use chat completions endpoint for detection or readiness.

## Validation and Readiness Behavior

Adopt should require a current or recent successful `GET /v1/models` check for the selected host and port.

Readiness behavior:

- Use `/v1/models` only.
- Treat HTTP 200 as compatible endpoint ready.
- Treat non-200 responses as not ready.
- Treat timeout or connection failure as disconnected or error.
- Do not automatically launch a managed server when adopted readiness fails.

Validation should verify:

- host is not empty,
- port is in range,
- base URL can be built,
- selected model profile still exists,
- adopted endpoint still matches selected host and port.

## Testing Plan

- Detect external server, adopt it, and verify adopted state.
- Forget adopted external server and verify external process is unaffected.
- Adopted server remains ready through `/v1/models`.
- Adopted server disappears and UI shows disconnected or not ready.
- Selected host changes and adoption is cleared or rechecked.
- Selected port changes and adoption is cleared or rechecked.
- Selected model changes and connection settings update without assuming model availability.
- Stop and Restart remain unavailable for adopted external server.
- Normal managed Start, Stop, Restart behavior remains unchanged.
- App relaunch does not accidentally claim ownership of an external server.
- Detection and readiness use `/v1/models` only.

## Future Work

- Decide whether adopted external context should ever be persisted.
- Add optional display of model IDs returned by `/v1/models`.
- Add clearer badges for managed versus external versus adopted external states.
- Add manual refresh for adopted external readiness.
- Add tests for adopted state transitions.
- Consider a safer name than Adopt if user testing shows ownership confusion.
