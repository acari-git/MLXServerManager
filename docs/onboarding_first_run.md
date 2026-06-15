# Onboarding / First-run Guidance

## Overview

Onboarding / First-run Guidance started as a v2.3.0 docs-only design and received an initial app implementation in v2.4.0. It helps first-time users understand what to configure, what to check before Start, and how Direct Mode affects their local OpenAI-compatible client setup.

The guidance should make the first run safer and clearer without adding automation that hides important ownership or network boundaries.

## v2.4.0 Initial Implementation

v2.4.0 adds a small Onboarding Guidance panel in the main app. It is lightweight guidance, not a wizard.

The panel summarizes the next setup step based on current app state:

- Missing `mlx_lm.server executable path`.
- Missing or empty selected Model Profile `modelID`.
- Not Running / Not Connected.
- External Server Detected.
- Adopted External Server.
- Managed Server Running.

The panel keeps these boundaries:

- No auto install.
- No model download.
- No model deletion.
- No inference proxy.
- No automatic external process ownership.
- No external process stop, restart, or kill.
- Direct Mode remains visible.

## v2.5.0 Screenshot Refresh

v2.5.0 adds a README screenshot for the First-run Onboarding Guidance panel:

- `screenshots/onboarding-guidance-v2.5.png`

This is a documentation and public presentation update only. It does not change onboarding behavior, server lifecycle behavior, Direct Mode, external process ownership, model download behavior, or inference routing.

## Goals

- Explain the first-run path from local `mlx-lm` setup through client configuration.
- Clarify what belongs in `mlx_lm.server executable path`.
- Clarify what belongs in a Model Profile.
- Explain readiness through `GET /v1/models`.
- Explain which Connection Settings values users should copy.
- Explain Managed Server versus External Server versus Adopted External Server.
- Reinforce that MLX Server Manager does not proxy inference requests.
- Keep API key placeholders local and dummy by default.

## Non-goals

- Do not add Chat UI.
- Do not add Proxy mode.
- Do not add multi-backend wrapper behavior.
- Do not add model download or model deletion.
- Do not automate `mlx-lm` installation.
- Do not automatically modify external client configuration.
- Do not stop, restart, kill, monitor memory for, or collect logs from external processes.
- Do not encourage users to expose local endpoints publicly.

## Target Users

- Users running MLX models locally on Apple Silicon.
- Users who have installed or can install `mlx-lm`.
- Users who want a GUI for managing `mlx_lm.server`.
- Users configuring Hermes Agent or another OpenAI-compatible client to use a local endpoint.
- Users who may already have an OpenAI-compatible server running and need to understand detected or adopted external server states.

## First-run Checklist

Before the first managed Start:

- Confirm the Mac is Apple Silicon.
- Confirm a working Python / virtualenv setup if using `mlx-lm`.
- Confirm `mlx_lm.server` exists and can run from the selected environment.
- Set `mlx_lm.server executable path` in Settings.
- Confirm the selected Model Profile.
- Confirm `modelID`.
- Confirm host and port, usually `127.0.0.1` and `8080`.
- Run Setup Diagnostics.
- Start the managed server.
- Check readiness via `GET /v1/models`.
- Copy connection settings.
- Configure an OpenAI-compatible client.
- Confirm the Direct Mode path:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

## Required Setup

MLX Server Manager does not bundle the runtime stack. Users must provide:

- Apple Silicon Mac.
- Local `mlx-lm` environment.
- `mlx_lm.server` executable path.
- Model files or Hugging Face cache.
- Model Profile with model ID, host, and port.

Recommended local defaults:

- Host: `127.0.0.1`
- Port: `8080`
- API key placeholder: `not-required-local`

## Recommended First Launch Flow

1. Open MLX Server Manager.
2. Open Settings.
3. Set `mlx_lm.server executable path`.
4. Create or select a Model Profile.
5. Confirm host, port, and model ID.
6. Leave Advanced Launch Options empty for the baseline first run.
7. Run Setup Diagnostics.
8. Press Start.
9. Confirm Ready status through `/v1/models`.
10. Open Connection Settings.
11. Confirm Current Target summary.
12. Copy Base URL, Model ID, API key placeholder, JSON config, Hermes Agent config, or readiness curl.
13. Paste the values into the OpenAI-compatible client.

## Managed Server Flow

Managed Server means MLX Server Manager started the `mlx_lm.server` process.

Flow:

1. Set `mlx_lm.server executable path`.
2. Select a Model Profile.
3. Press Start.
4. Wait for Ready.
5. Check Ready if needed.
6. Copy Connection Settings.
7. Use the endpoint from an external OpenAI-compatible client.
8. Use Stop or Restart when needed.

Managed server boundaries:

- Stop and Restart apply only to the app-managed process.
- Memory display is available only for the managed process.
- Logs are app-captured managed process logs and app-side status logs.
- Readiness uses `/v1/models`.
- The app does not send inference requests.

## External Server Flow

External Server means another process is already serving an OpenAI-compatible endpoint on the selected host and port.

Flow:

1. Start the external server outside MLX Server Manager.
2. Set the selected Model Profile host and port to match that endpoint.
3. Press Start or Check Ready.
4. If the endpoint responds to `/v1/models`, MLX Server Manager may show External Server Detected.
5. Review the ownership note.
6. Press Adopt External Server if you want to use it as connection context.
7. Copy Connection Settings.
8. Press Forget External Server when you no longer want the app-side context.

External server boundaries:

- External servers are not app-owned processes.
- Stop and Restart do not apply.
- The app does not kill external processes.
- The app does not monitor external memory.
- The app does not collect external stdout or stderr logs.
- Adopt means connection context only, not process ownership.

## Connection Settings Flow

Connection Settings should answer:

- Which target should the client connect to?
- Is the target managed by MLX Server Manager?
- Is the target ready?
- What values should be copied?

Typical values:

- Base URL: `http://127.0.0.1:8080/v1`
- Model ID: selected Model Profile `modelID`
- API key placeholder: `not-required-local`
- Readiness endpoint: `GET /v1/models`

Recommended copy order:

1. Copy Base URL.
2. Copy Model ID.
3. Copy API key placeholder.
4. Copy JSON config or Hermes Agent config.
5. Copy curl readiness check if troubleshooting.

The OpenAI-compatible chat example is copy-only helper text. MLX Server Manager does not execute `/v1/chat/completions`.

## Hermes Agent Setup Flow

Hermes Agent should be treated as an OpenAI-compatible client.

Suggested flow:

1. Start or adopt the local server endpoint.
2. Confirm Current Target summary.
3. Copy Hermes Agent config from Connection Settings.
4. Paste Base URL, model, and API key placeholder into the relevant Hermes Agent provider/client configuration.
5. If the Hermes Agent setup requires a provider name, headers, or local routing options, follow that setup's own documentation.
6. Confirm readiness separately with the copied `/v1/models` curl check if needed.

Qwen thinking note:

```text
If Qwen thinking control is needed, configure chat_template_kwargs client-side where supported.
```

The app should not hide that this is client-side behavior.

## Troubleshooting Prompts

Use short prompts to guide users without taking unsafe actions:

- Is `mlx_lm.server executable path` set?
- Does the selected path exist and appear executable?
- Does the selected Model Profile have a non-empty model ID?
- Is host set to `127.0.0.1` for local use?
- Is the selected port already in use?
- Does `/v1/models` respond?
- Is the target managed, external detected, adopted external, or not running?
- Are Stop and Restart disabled because the target is external?
- Does the OpenAI-compatible client use the same Base URL and Model ID shown in Connection Settings?

## UI Copy Suggestions

Short first-run or empty-state text candidates:

- `Set the mlx_lm.server executable path to start a managed server.`
- `MLX Server Manager does not proxy inference requests.`
- `Use Connection Settings to copy Base URL, Model ID, and local API key placeholder.`
- `If a compatible server is already running on this host and port, MLX Server Manager can detect it.`
- `Adopt means connection context only, not process ownership.`
- `Readiness is checked with /v1/models.`
- `Leave Advanced Launch Options empty for a baseline first run.`
- `Stop and Restart apply only to the app-managed process.`

## Safety and Privacy Notes

- Prefer `127.0.0.1` for local use.
- Do not expose a local server to public networks unless you understand the risk.
- Do not paste real API keys, tokens, or private paths into issues or screenshots.
- Keep `settings.json`, `models.json`, model files, `.env`, and `HF_TOKEN` out of Git.
- Use `not-required-local` or another dummy value unless the target server requires a real key.
- Keep Direct Mode visible: the app is not an inference proxy.
- Do not use app controls to manage external processes.

## Testing Plan

Future onboarding tests should confirm:

- First-run empty state explains required setup.
- Missing executable path is clearly actionable.
- Missing or invalid Model Profile fields are clearly actionable.
- Setup Diagnostics is discoverable before Start.
- Managed server Start reaches Ready through `/v1/models`.
- Connection Settings shows a usable Current Target summary.
- External Server Detected explains not-managed ownership.
- Adopt External Server explains connection context only.
- Hermes Agent config copy includes Base URL, model, and API key placeholder.
- Chat-completions examples remain copy-only helper text.
- The app does not call `/v1/chat/completions`.
- Stop and Restart remain scoped to app-managed processes.

## Future Work

- Add a first-run empty-state panel.
- Add contextual help near `mlx_lm.server executable path`.
- Add a first-run checklist UI that links to Setup Diagnostics.
- Add inline explanations for Managed Server versus Adopted External Server.
- Keep onboarding guidance text short enough for the main app UI.
