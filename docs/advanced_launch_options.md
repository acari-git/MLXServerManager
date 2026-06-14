# Advanced Launch Options

This document defines the planned v1.1 design direction for optional Advanced Launch Options in MLX Server Manager.

## Implementation Status

- v1.1.0 documented the design only.
- v1.2 adds the initial implementation for optional per-profile Advanced Launch Options.
- The default simple launch remains unchanged when advanced fields are empty.
- Empty advanced values are omitted from `mlx_lm.server` arguments.
- Advanced options remain workload-dependent and are not enabled by default.
- v1.2.1 adds Copy Preview, Clear Advanced Options, and clearer validation messages.

## Overview

Advanced Launch Options are optional user-tunable settings for constructing `mlx_lm.server` launch arguments. They are intended for users who understand their workload and want to experiment with server-side launch configuration.

They must not change the default simple launch behavior.

## Goals

- Keep the current simple launch path as the default.
- Add optional model-profile-level launch settings in a future implementation step.
- Make advanced values explicit, visible, and reviewable before launch.
- Omit empty advanced values from `mlx_lm.server` arguments.
- Keep argument construction outside SwiftUI views.
- Provide validation before launching.
- Support benchmark-driven experimentation without enabling aggressive defaults.

## Non-goals

- Do not add Proxy mode.
- Do not add Chat UI.
- Do not add multi-backend wrapper behavior.
- Do not route inference requests through MLX Server Manager.
- Do not enable aggressive tuning defaults.
- Do not automatically tune values without user intent and benchmark evidence.
- Do not send `/v1/chat/completions` from the app.

## Direct Mode Boundary

MLX Server Manager remains Direct Mode:

```text
OpenAI-compatible client -> mlx_lm.server -> MLX model
```

The app may build and preview the command used to start `mlx_lm.server`, but it must not enter the inference request path.

## Why Advanced Launch Options Should Be Optional

Recent benchmark work showed that pure `mlx_lm.server` can be strong for long-context, prompt-cache-style, and streaming TTFT workloads. It also showed that performance depends on workload, and earlier aggressive advanced launch option tests did not show clear improvement.

Therefore:

- Advanced settings may be valuable for specific users and workloads.
- Advanced settings should not be enabled by default.
- Empty fields should preserve `mlx_lm.server` defaults.
- Aggressive defaults should be avoided.
- Users should be told that advanced options are workload-dependent and may not improve performance.

## Candidate Options

Structured candidate fields:

- `defaultTemperature`
- `defaultTopP`
- `defaultTopK`
- `defaultMinP`
- `defaultMaxTokens`
- `allowedOrigins`
- `logLevel`
- `decodeConcurrency`
- `promptConcurrency`
- `prefillStepSize`
- `promptCacheSize`
- `promptCacheBytes`

Expert candidate fields:

- `rawExtraArgs`
- `chatTemplateArgs`

Names may change during implementation if `mlx_lm.server` uses different argument names or semantics.

## UI Design

The expected UI location is the Model Profile Editor.

Design direction:

- Add an "Advanced Launch Options" disclosure group.
- Keep it collapsed by default.
- Show "Leave empty to use mlx_lm.server defaults."
- Show "Advanced options are workload-dependent and may not improve performance."
- Treat raw extra args as expert-only.
- Show a command preview from the same argument builder used for launch.
- Provide Copy Preview so users can copy the exact displayed command.
- Provide Clear Advanced Options so users can quickly return the draft to simple launch behavior.
- Keep Start / Stop / Restart controls unchanged.
- Keep Connection Settings tied to the selected model profile.

The UI should not imply that enabling advanced options guarantees better performance.

## Data Model Design

A future implementation may add a nested structure to `ModelConfig`, for example:

```text
ModelConfig
  advancedLaunchOptions
```

The structure should keep optional values distinct from empty or unset values.

Design principles:

- Existing saved profiles remain valid.
- Missing advanced settings mean simple launch behavior.
- Empty strings and nil values are omitted from launch arguments.
- Structured values remain typed where possible.
- Raw extra args are stored separately from structured fields.

## Argument Construction Design

SwiftUI views must not build `Process` arguments directly.

The intended flow is:

```text
ModelConfig -> ModelLaunchRequest -> ModelProcessManager argument builder
```

Argument construction should:

- Start from the existing simple launch command.
- Add structured advanced args only when explicitly set.
- Append `rawExtraArgs` only when explicitly set.
- Omit empty values.
- Produce a command preview from the same builder used for launch.
- Avoid logging secrets or unrelated local paths.

Simple launch must remain:

```text
<mlxServerExecutablePath> --model <modelID> --host <host> --port <port>
```

## Validation Policy

Validation should happen before saving and before launch.

Recommended validation:

- Reject invalid numeric values.
- Reject negative concurrency, size, or token values.
- Reject obviously malformed `allowedOrigins`.
- Surface unknown or risky raw extra args clearly.
- Preserve the user's draft until they fix invalid fields.
- Do not launch if validation fails.

Validation should be conservative. If an option is not understood well enough to validate safely, it should remain unset or be treated as expert raw input with a clear warning.

## Safety Boundaries

- Direct Mode is maintained.
- The app remains outside the inference request path.
- Advanced options are optional and user-tunable.
- Empty values are omitted from launch arguments.
- Aggressive defaults are avoided.
- No SwiftUI view builds process args directly.
- Stop and Restart still target only the app-managed process.
- No `pkill`, `killall`, or `pgrep` in Swift code.
- The app does not call `/v1/chat/completions`.
- Runtime settings and model profiles remain local files and must not be committed.

## Testing Plan

Unit and manual tests should cover:

- Argument construction tests.
- Empty advanced values are omitted.
- Simple launch remains unchanged when advanced options are unset.
- `rawExtraArgs` are appended only when explicitly set.
- Structured options generate expected `mlx_lm.server` args.
- Invalid values are rejected or surfaced clearly.
- Command preview matches the launch argument builder.
- No SwiftUI view builds `Process` args directly.
- No app code calls `/v1/chat/completions`.
- No `pkill`, `killall`, or `pgrep` in Swift code.
- Existing Start / Stop / Restart behavior remains unchanged without advanced values.

Manual checks should include:

- Existing profiles load without advanced settings.
- Saving a profile with no advanced values preserves simple launch.
- Enabling one structured option changes only the expected argument.
- Clearing an advanced field removes it from the command.
- Invalid values prevent launch and show a clear message.

## Future Work

Possible implementation steps:

- Add `AdvancedLaunchOptions` model.
- Add draft/editing support in Model Profile Editor.
- Add validation service.
- Add argument builder tests.
- Add command preview.
- Add migration-safe settings persistence.
- Add benchmark notes for tested option combinations.

Advanced options should remain optional until repeated benchmark evidence supports safer defaults.
