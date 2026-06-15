# Connection Settings Polish

## Overview

Connection Settings Polish makes connection targets easier to understand and copy across managed and external server states.

This is a display and copy UX improvement. It does not change the inference path, does not add a proxy, and does not give MLX Server Manager ownership of external processes.

## Implementation Status

v1.9.0 implements the initial Current Target summary and expanded copy actions in Connection Settings.

- Managed, external detected, adopted external, and not-running states show distinct target summaries.
- Copy actions include Base URL, Model ID, API key placeholder, JSON client config, Hermes Agent config, readiness curl, OpenAI-compatible chat example, and all connection settings.
- The implementation remains display and copy UX only.
- Direct Mode and external process ownership boundaries are unchanged.

## Problem Statement

After External Server Detection and Adopt External Server, the app can represent more than one connection context:

- a managed `mlx_lm.server` process started by MLX Server Manager,
- an external OpenAI-compatible server detected on the selected host and port,
- an external server explicitly adopted as connection context,
- or no usable connection target.

Users should be able to see which target is current, whether it is managed by the app, and which values should be copied into Hermes Agent or another OpenAI-compatible client.

## Goals

- Introduce a clear "Current Connection Target" concept.
- Make Managed Server, External Server Detected, Adopted External Server, and Not Running states easy to distinguish.
- Keep Base URL, Model ID, API key placeholder, readiness status, and ownership notes visible.
- Improve copy actions for Hermes Agent and generic OpenAI-compatible clients.
- Keep copied examples clear that `/v1/chat/completions` is a client-side example only.
- Preserve Direct Mode and process ownership boundaries.
- Avoid including secrets in copied default settings.

## Non-goals

- No inference proxy.
- No Chat UI.
- No multi-backend routing.
- No model download or model deletion.
- No external process kill, stop, or restart.
- No automatic client configuration writes.
- No persistent external adoption unless separately designed.
- No change to the app's readiness or detection endpoint beyond `/v1/models`.

## Direct Mode Boundary

The inference path remains:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

MLX Server Manager stays outside the inference request path. It manages app-started server processes, displays status, and copies connection settings.

Connection Settings Polish must not make MLX Server Manager appear to be a request router, backend wrapper, or inference proxy.

## Current Connection Target Concept

The UI should present a compact summary that answers:

- What should the user connect to?
- Is that target managed by MLX Server Manager?
- Is the target ready?
- Which values should be copied into a client?

Suggested display fields:

- Target Type
- Base URL
- Model ID
- API Key placeholder
- Readiness status
- Ownership note

Target Type values:

- Managed Server
- External Server Detected
- Adopted External Server
- Not Running / Not Connected

## State-specific Connection Behavior

### Managed Server

A managed server is an app-started `mlx_lm.server` process.

- Stop and Restart are available.
- Memory display is available.
- Managed stdout and stderr logs are available.
- Base URL comes from the selected model profile host and port.
- Model ID comes from the selected model profile.
- Readiness uses `GET /v1/models`.
- Ownership note should say `Managed by MLX Server Manager`.

### External Server Detected

External Server Detected means the selected host and port responded to `GET /v1/models`, but the user has not adopted the endpoint.

- The target is not managed by MLX Server Manager.
- Stop and Restart are unavailable.
- Adopt External Server is available.
- Connection settings copy is still useful.
- Memory and external process logs are unavailable.
- The app must not assume the endpoint is `mlx_lm.server`.

Ownership note should say `Not managed by MLX Server Manager`.

### Adopted External Server

Adopted External Server means the user explicitly chose a detected endpoint as connection context.

- Adopt is connection context only.
- The target remains external.
- Stop and Restart are unavailable.
- Forget External Server is available.
- Memory remains unavailable for the external process.
- Logs remain app-side only and should not imply external stdout/stderr capture.
- Base URL comes from the selected host and port.
- Model ID comes from the selected model profile.

Ownership note should say `Connection context only. Not managed by MLX Server Manager.`

### Not Running / Not Connected

Not Running / Not Connected means there is no usable connection target.

- Users should Start a managed server or trigger external server detection.
- Copy actions may be disabled or may copy selected profile defaults with clear wording.
- The UI should avoid implying that an endpoint is currently ready.

### Error / Disconnected

Error or disconnected states should keep ownership clear.

- Managed errors may guide users toward logs, diagnostics, Stop, or Restart.
- External disconnected states should not offer Stop or Restart.
- Adopted external disconnection should offer Forget External Server and diagnostics or readiness retry.
- The app should not automatically start a managed server to replace a disappeared adopted external server.

## UI Design

Connection Settings should add a Current Target summary near the existing copy actions.

Recommended summary:

```text
Current Target: Adopted External Server
Base URL: http://127.0.0.1:8080/v1
Model ID: <selected modelID>
Readiness: Ready via /v1/models
Ownership: Connection context only. Not managed by MLX Server Manager.
```

Design principles:

- Make ownership visible, not only implied by disabled buttons.
- Use `Managed by MLX Server Manager` only for app-started processes.
- Use `Not managed by MLX Server Manager` for external detected and adopted targets.
- Show Forget, not Stop or Restart, for adopted external targets.
- Keep the panel text-based and practical.
- Do not add Chat UI or request execution controls.

## Copy Actions

Candidate copy actions:

- Copy Base URL
- Copy Model ID
- Copy API Key placeholder
- Copy JSON client config
- Copy Hermes Agent config
- Copy curl readiness check
- Copy OpenAI-compatible chat example
- Copy all connection settings

Copy actions should use the selected model profile for model ID and the current target host and port for Base URL.

Copied text should avoid secrets by default. The default API key placeholder should remain local and dummy, such as `not-required-local`.

## Hermes Agent Copy Behavior

Hermes Agent should be treated as an OpenAI-compatible client. The copied configuration should be generic enough to adapt to the user's Hermes Agent setup.

Suggested values:

- Base URL: selected host and port plus `/v1`
- Model: selected profile `modelID`
- API key: `not-required-local`
- Notes:
  - Direct Mode
  - local server
  - no proxy through MLX Server Manager
  - Qwen thinking control, when needed, should be sent by the client through supported request fields such as `chat_template_kwargs`

The app should not write Hermes Agent configuration automatically in v1.8.0.

## Generic OpenAI-compatible Client Copy Behavior

Generic client copy output should include:

- `base_url`
- `model`
- `api_key`
- readiness endpoint: `/v1/models`
- optional example `curl`

The output should not imply that MLX Server Manager sends inference requests.

Example JSON shape:

```json
{
  "base_url": "http://127.0.0.1:8080/v1",
  "api_key": "not-required-local",
  "model": "<selected modelID>"
}
```

## Managed Server Behavior

For managed servers, Connection Settings can show the strongest operational context:

- status is based on the managed runtime state,
- PID may be available elsewhere in the status panel,
- Stop and Restart are managed actions,
- memory is available for the managed PID,
- logs are app-captured managed process logs.

Copy actions still produce OpenAI-compatible client values. The client connects directly to `mlx_lm.server`.

## External Server Detected Behavior

For external detected servers:

- show the endpoint as detected but not adopted,
- keep Adopt External Server visible,
- keep Stop and Restart unavailable,
- allow connection copy actions,
- state that the app does not own the process,
- state that the server is OpenAI-compatible enough to respond to `/v1/models`, but do not assume it is `mlx_lm.server`.

## Adopted External Server Behavior

For adopted external servers:

- show the target as Adopted External Server,
- show Base URL and selected Model ID clearly,
- show `Connection context only`,
- show `Not managed by MLX Server Manager`,
- keep Forget External Server visible,
- keep Stop and Restart unavailable,
- keep memory as unavailable for external server,
- avoid treating app logs as external server logs.

Adoption should not persist automatically unless a future design explicitly covers persistence.

## Error / Disconnected Behavior

If an adopted external server stops responding:

- show a disconnected or not-ready message,
- retain enough target context for the user to understand what disappeared,
- offer Forget External Server,
- keep Stop and Restart unavailable,
- do not automatically launch a replacement managed server,
- keep readiness checks limited to `/v1/models`.

## Security Notes

- Default local use should prefer `127.0.0.1`.
- Do not expose local servers to LAN or WAN unless the user understands the network risk.
- The API key placeholder is local and dummy unless the external server requires a real key.
- Copy defaults should not include real secrets.
- Do not paste real API keys, tokens, personal paths, or secrets into issues or logs.
- Connection Settings should not write client config files automatically in this design.

## Testing Plan

- Managed server running shows Target Type: Managed Server.
- External server detected shows Target Type: External Server Detected.
- Adopted external server shows Target Type: Adopted External Server.
- Stopped state shows no usable current target.
- Base URL updates when selected host or port changes.
- Model ID updates when selected profile changes.
- Copy Base URL returns the current target Base URL.
- Copy Model ID returns the selected profile model ID.
- Copy JSON client config uses selected host, port, model ID, and dummy API key placeholder.
- Copy Hermes Agent config uses the selected profile model ID.
- Copy readiness check uses `/v1/models`.
- Copy chat-completions example is presented only as client-side helper text.
- The app does not call `/v1/chat/completions`.
- Stop and Restart remain enabled only for app-managed processes.
- Adopted external targets show Forget, not Stop or Restart.
- Copied default config contains no secrets.

## Future Work

- Implement Current Target summary in Connection Settings.
- Add Copy Hermes Agent Config.
- Add Copy OpenAI Client Example.
- Add Copy all connection settings.
- Consider optional current-target badges in the menu bar.
- Consider persistent external adoption only after a separate safety design.
- Keep Proxy mode, Chat UI, multi-backend routing, and automatic client configuration writes out of scope.
