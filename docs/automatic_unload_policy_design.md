# Automatic Unload Policy Design

## Release

- Added in `v6.29.0`.
- Docs-only design for possible future automatic unload policies.
- No Swift source, timers, background monitors, request observers, network hooks, lifecycle changes, tests, app binary, or release asset is added in this release.

## Purpose

`v6.29.0` defines the safety boundary for a possible future automatic unload feature before implementation starts.

Automatic unload should be a conservative app-managed server lifecycle policy. It must not inspect inference traffic, proxy requests, monitor prompts or responses, or stop external servers that are not owned by MLX Server Manager.

Direct Mode remains unchanged:

```text
OpenAI-compatible client -> mlx_lm.server
```

The app may only use app-owned lifecycle state, readiness state, explicit user settings, and safe local timing signals.

## Current State

Current project state:

- Automatic unload is not implemented.
- The app can start, stop, and restart an app-managed `mlx_lm.server` process.
- The app can distinguish app-managed and external/adopted targets.
- The app does not proxy inference traffic.
- The app does not inspect client requests.
- The app does not observe prompts or completions.
- The app does not stop external servers.

## Design Goals

A future automatic unload feature should:

- be disabled by default;
- require explicit user opt-in;
- apply only to the app-managed server process;
- never stop an external or adopted server;
- use clear idle policy wording;
- show the active policy in the desktop app;
- provide a visible cancel or disable path;
- preserve manual Stop and Restart behavior;
- avoid telemetry, analytics, and request inspection;
- avoid background network activity;
- keep logs bounded and copy-safe.

## Non-Goals

`v6.29.0` does not approve:

- inference request inspection;
- prompt or response monitoring;
- proxy-mode traffic tracking;
- `/v1/chat/completions` calls;
- automatic model deletion;
- cache cleanup;
- Hugging Face download cancellation;
- remote unload through LAN Web UI;
- unload of external/adopted servers;
- multiple concurrent server lifecycle management;
- telemetry;
- analytics;
- cloud reporting;
- release automation.

## Policy Scope

Automatic unload should be scoped to one app-managed process at a time.

Allowed future signals:

- app-managed server running state;
- readiness state;
- user-configured idle duration;
- last app-side lifecycle action time;
- app foreground or background state if explicitly documented;
- optional memory-pressure state if implemented as a local summary only.

Disallowed signals:

- inference request contents;
- prompt text;
- model response text;
- client request bodies;
- traffic inspection;
- external process ownership claims;
- hidden background polling of inference endpoints;
- telemetry events.

## Initial Policy Candidate

A safe first policy is:

```text
Stop the app-managed server after N minutes of app-observed idle time.
```

Initial constraints:

- off by default;
- selected duration must be explicit;
- minimum duration should avoid surprise shutdowns;
- pending unload should be visible before it happens;
- manual Start resets the idle timer;
- manual Stop cancels the policy countdown;
- Restart resets the idle timer;
- external/adopted targets are ignored.

## Idle Definition

Because the app is not an inference proxy, it cannot safely know true client request activity.

Use conservative wording:

```text
App-observed idle time
```

Do not claim:

```text
No clients are using the model
```

or:

```text
No inference requests are running
```

A future implementation may define app-observed idle as time since the latest app-owned lifecycle or readiness event, but it must not pretend to observe real inference usage unless a separate, explicit, non-Direct-Mode design exists.

## UI Requirements

A future UI should show:

- automatic unload enabled or disabled;
- selected idle duration;
- whether the policy applies to the current server;
- next unload estimate if safe to compute;
- reason the policy is inactive;
- clear disable action;
- clear explanation that external servers are not stopped.

Example wording:

```text
Automatic unload is off.
```

```text
Automatic unload applies only to the app-managed server.
```

```text
External servers are not managed or stopped by MLX Server Manager.
```

```text
Idle time is app-observed and does not inspect inference requests.
```

## Persistence

If implemented later, settings may include:

- enabled flag;
- idle duration;
- optional warning threshold;
- optional reset-on-app-foreground behavior.

Do not persist:

- request history;
- prompt history;
- response history;
- client identifiers;
- generated client configuration;
- secrets;
- telemetry identifiers.

## Logging

Logs should remain app-side and bounded.

Allowed log summaries:

```text
Automatic unload policy enabled.
Automatic unload skipped: current target is external.
Automatic unload stopped app-managed server after configured idle duration.
Automatic unload cancelled by manual Stop.
```

Do not log:

- prompts;
- responses;
- request bodies;
- tokens;
- full local paths;
- private URLs;
- environment variables.

## External Server Boundary

Automatic unload must not stop external or adopted servers.

For external/adopted targets, use wording such as:

```text
Automatic unload is unavailable for external servers.
```

```text
This target is connection context only and is not managed by MLX Server Manager.
```

No exception should allow stopping a process the app did not start.

## Relationship To LAN Web UI

Automatic unload should not depend on LAN Web UI.

A future LAN Web UI may display read-only policy status if a separate implementation allows it, but remote unload controls should remain out of scope until explicitly reviewed.

## Relationship To App Intents

Automatic unload should not require App Intents.

A future App Intent may query status or disable the policy only after separate review. Start, Stop, Restart, and policy mutation through App Intents should remain separate implementation scopes.

## Verification Expectations

A future implementation should verify:

- default state is off;
- enabling requires explicit user action;
- policy applies only to app-managed processes;
- external/adopted servers are never stopped;
- manual Stop cancels pending unload;
- Restart resets idle timing;
- displayed status matches internal policy state;
- logs remain copy-safe;
- no request bodies, prompts, responses, secrets, tokens, or full local paths are stored;
- no inference endpoint is called to determine idle state;
- Direct Mode remains direct.

## Implementation Entry Criteria

Start implementation only when:

- idle definition is finalized;
- UI placement is selected;
- default-off behavior is preserved;
- external server skip behavior is defined;
- persistence fields are reviewed;
- tests can run without real model servers or client traffic;
- release notes can accurately state that no request inspection or inference proxying is added.

## Release Acceptance

`v6.29.0` is acceptable if:

- this design document is added;
- README references the design;
- `docs/tasks.md` records the completed docs-only work;
- no Swift source files change;
- no tests change;
- no timers are added;
- no background monitors are added;
- no request observers are added;
- no network hooks are added;
- no lifecycle behavior changes;
- no app binary zip is produced;
- Direct Mode remains unchanged.
