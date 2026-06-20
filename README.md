# MLX Server Manager

MLX Server Manager is a lightweight macOS SwiftUI GUI for operating local OpenAI-compatible MLX endpoints in Direct Mode.

It is primarily a control surface for app-managed `mlx_lm.server`, with support for detecting and adopting an already-running external OpenAI-compatible server as connection context.

The app keeps Direct Mode:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

MLX Server Manager controls and observes app-managed local server processes, but it does not enter the inference request path. OpenAI-compatible clients connect directly to the server endpoint.

## Screenshots

### Main Dashboard

![MLX Server Manager main dashboard](screenshots/main-dashboard-v2.2.png)

The main dashboard shows the core MLX Server Manager workflow in one place: model profiles, app settings, diagnostics, server status, selected model details, OpenAI-compatible connection settings, and logs.

MLX Server Manager remains a Direct Mode control surface for `mlx_lm.server`. It does not proxy inference requests.

### Connection Settings / Current Target

![Connection Settings Current Target summary](screenshots/connection-settings-current-target-v2.2.png)

Connection Settings shows the current OpenAI-compatible target clearly.

It displays:

- target type
- Base URL
- Model ID
- API key placeholder
- readiness endpoint
- ownership note
- copy actions for client setup

The copy actions help configure OpenAI-compatible clients, including Hermes Agent, without routing inference through MLX Server Manager.

### Adopted External Server

![Adopted External Server state](screenshots/adopted-external-server-v2.2.png)

Adopted External Server mode lets users use a detected external OpenAI-compatible server as a connection context.

Adopt does not mean process ownership. MLX Server Manager does not stop, restart, kill, monitor memory for, or collect logs from adopted external servers.

The Direct Mode path remains:

`OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model`

### First-run Onboarding Guidance

![First-run Onboarding Guidance panel](screenshots/onboarding-guidance-v2.5.png)

The onboarding guidance panel gives short, state-aware setup hints for first-time users.

It helps users understand what to configure next, such as the `mlx_lm.server` executable path, selected model profile, server state, and connection settings.

The guidance is informational only. It does not install dependencies, download models, start external processes, proxy inference, or change process ownership.

## Why This Project Exists

`mlx_lm.server` is fast and simple, but day-to-day local use benefits from a small GUI around process management, diagnostics, model profiles, logs, memory display, external endpoint visibility, and connection settings.

MLX Server Manager exists to provide that management layer without becoming the inference layer. The goal is to make pure `mlx_lm.server` easier to operate for local OpenAI-compatible clients, especially agent tools that need a stable local endpoint.

## Project Principles

MLX Server Manager follows three product principles:

1. Preserve `mlx-lm` runtime performance as the top priority.
2. Make `mlx-lm` usable for users who are not comfortable with CLI workflows.
3. Adopt useful features from other local LLM tools when they do not conflict with `mlx-lm` performance, safety, or Direct Mode boundaries.

See [docs/product_direction.md](docs/product_direction.md) for the full project direction, including current non-goals and future candidate features.

## What This Is

- A local macOS app for starting, stopping, and restarting an app-managed `mlx_lm.server`.
- A status and diagnostics surface for readiness checks via `GET /v1/models`.
- A model profile editor for local OpenAI-compatible endpoint settings.
- A managed-process log and memory display.
- A Direct Mode connection settings copier for OpenAI-compatible clients.
- A conservative external server detector for selected host/port endpoints.
- An Adopt External Server flow for connection context only, not process ownership.

## What This Is Not

- Not a chat UI.
- Not an inference proxy.
- Does not currently include model download or install automation.
- Not a model deletion tool.
- Not a multi-backend wrapper.
- Not a replacement for `mlx-lm` or model setup.

## Install

Download the latest app-code release asset from GitHub Releases:

```text
MLXServerManager-v6.5.1-unsigned.zip
```

On the GitHub Release page, use the file listed under **Assets** with this exact name. Do not use **Source code (zip)** or **Source code (tar.gz)** when you want the app.

`v6.6.0`, `v6.6.1`, `v6.7.0`, `v6.7.1`, `v6.8.0`, and `v6.8.1` are documentation releases. They do not replace the current app binary.

Verify the checksum before opening the app:

```text
SHA-256: 31e8603f93d3a3eaedee9749a255668c9b804854fb69cb3b63f36b411613274e
```

From the folder containing the downloaded zip, you can check it with:

```sh
shasum -a 256 MLXServerManager-v6.5.1-unsigned.zip
```

Extract the zip and confirm it contains `MLXServerManager.app`. Move the app to your preferred local location, such as `/Applications` or a user-owned apps folder.

This is an unsigned, non-notarized local-use build. macOS may show a Gatekeeper warning. If you trust the Release asset, verify the zip contents and checksum before removing quarantine:

```sh
xattr -dr com.apple.quarantine /path/to/MLXServerManager.app
open -n /path/to/MLXServerManager.app
```

Do not download the source archive if you want the app binary. Use the named `MLXServerManager-v6.5.1-unsigned.zip` release asset.

## Quick Start

1. Open `MLXServerManager.app`.
2. In Settings, set the `mlx_lm.server executable path`.
3. Configure or add a Model Profile.
4. Run Setup Diagnostics.
5. Press Start.
6. Confirm the Current Target summary in Connection Settings.
7. Copy Base URL, Model ID, API key placeholder, JSON config, Hermes Agent config, or curl readiness check from Connection Settings.
8. Paste those values into an OpenAI-compatible client.

You must provide your own `mlx-lm` environment, `mlx_lm.server` executable, and model files or Hugging Face cache. The app keeps Direct Mode: the client connects directly to `mlx_lm.server`; MLX Server Manager does not proxy inference traffic or run chat completions.

See [docs/distribution.md](docs/distribution.md) for release asset and Gatekeeper details, and [docs/known_limitations.md](docs/known_limitations.md) for the full stable-scope boundary.

See [docs/benchmark_findings.md](docs/benchmark_findings.md) for benchmark-informed notes on Direct Mode, long-context workloads, streaming TTFT, and future optional Advanced Launch Options.

Advanced Launch Options are optional, per-profile user-tunable settings. They are empty by default and omitted from launch arguments unless explicitly set. See [docs/advanced_launch_options.md](docs/advanced_launch_options.md) for design notes and safety boundaries.

External server detection is documented in [docs/external_server_detection.md](docs/external_server_detection.md). It detects existing OpenAI-compatible servers on the selected host/port without taking ownership of external processes.

Adopt External Server behavior is documented in [docs/adopt_external_server.md](docs/adopt_external_server.md). v1.7.0 adds the initial implementation for explicitly adopting a detected external server as connection context only, without taking process ownership.

Connection Settings polish is documented in [docs/connection_settings_polish.md](docs/connection_settings_polish.md). v1.9.0 implements the initial Current Target summary and expanded copy actions for Managed, External Detected, Adopted, and Not Running connection states. Direct Mode remains unchanged.

Dashboard UI Refresh v1 is documented in [docs/dashboard_ui_refresh.md](docs/dashboard_ui_refresh.md). v4.2.0 through v4.9.0 built the dashboard in small display-oriented steps. v5.0.0 finalizes Dashboard v1 as the current stable overview for Next Steps, Current Target, Server State, Client Setup, Diagnostics & Logs, and Profiles / Import Export while preserving lifecycle behavior, Direct Mode, external server ownership boundaries, and Import / Export behavior. v5.1.0 keeps that surface stable and documents larger layout ideas as future work rather than part of Dashboard v1.

Future Full App Layout Refresh planning is documented in [docs/full_app_layout_refresh.md](docs/full_app_layout_refresh.md). v5.2.0 is a docs-only planning release for possible future v6.x sidebar, profiles, server, logs, client setup, and inspector surfaces. It does not implement a new layout or change Dashboard v1 behavior.

App Shell / Sidebar Foundation is documented in [docs/app_shell_sidebar_foundation.md](docs/app_shell_sidebar_foundation.md). v5.3.0 introduced the docs-only design, and v6.0.0 implements the initial native sidebar shell with Dashboard as the default and only active top-level section. It does not change runtime behavior, Direct Mode, lifecycle controls, Import / Export behavior, network behavior, or persistence.

Profiles / Model List Surface design is documented in [docs/profiles_model_list_surface.md](docs/profiles_model_list_surface.md). v5.4.0 is a docs-only detailed design release for a possible future v6.1.0 Profiles section; it does not implement a model list table, model download, model deletion, or profile behavior changes.

Detail Inspector Foundation design is documented in [docs/detail_inspector_foundation.md](docs/detail_inspector_foundation.md). v5.5.0 is a docs-only detailed design release for a possible future v6.2.0 inspector area; it does not implement inspector UI, endpoint testing, model file management, or behavior changes.

Logs Panel Refresh design is documented in [docs/logs_panel_refresh.md](docs/logs_panel_refresh.md). v6.3.0 implements the first Logs Panel Refresh as a top-level sidebar destination for app-managed lifecycle and log context. v6.3.1 polishes the shared log view with entry count display and stable identifiers. It does not implement external log capture, telemetry, background monitoring, or behavior changes.

Client Setup Surface design is documented in [docs/client_setup_surface.md](docs/client_setup_surface.md). v6.4.0 implements the first Client Setup surface as a top-level sidebar destination for copy-safe OpenAI-compatible setup values. v6.4.1 polishes that surface with a copy scope card. It does not implement generated client configs, API key storage, endpoint testing, proxying, or behavior changes.

Metrics / System Context design is documented in [docs/metrics_system_context.md](docs/metrics_system_context.md). v6.5.0 implements the first Metrics / System Context surface as a read-only top-level sidebar destination. v6.5.1 polishes that surface with a context scope card. It does not implement active system monitoring, telemetry, request inspection, or behavior changes.

v6 Implementation Readiness Review is documented in [docs/v6_implementation_readiness.md](docs/v6_implementation_readiness.md). v5.9.0 is a docs-only readiness release that consolidates v5.2.0 through v5.8.0 planning; v6.0.0 starts app-code work with the narrow App Shell / Sidebar Foundation only.

v6 App Layout Stabilization Review is documented in [docs/v6_app_layout_stabilization_review.md](docs/v6_app_layout_stabilization_review.md). v6.6.0 is a docs-only stabilization review after the v6.0.0 through v6.5.1 App Shell and top-level surface work. v6.6.1 polishes that review with next-phase entry criteria and a manual verification checklist. Both produce no new app binary and keep the current downloadable binary at v6.5.1.

Distribution / Packaging Readiness Review is documented in [docs/distribution_packaging_readiness.md](docs/distribution_packaging_readiness.md). v6.7.0 is a docs-only readiness release for future signed, notarized, DMG, and automated release workflow decisions. v6.7.1 polishes that review with install documentation planning and manual packaging verification notes. v6.8.0 refreshes the README Install and Quick Start sections around the current unsigned app asset. v6.8.1 polishes the install section with clearer GitHub Assets guidance and a checksum command. These releases produce no new app binary and keep the current downloadable binary at v6.5.1.

Signed Distribution Design is documented in [docs/signed_distribution_design.md](docs/signed_distribution_design.md). v6.9.0 is a docs-only design release for a future signed zip distribution path. v6.9.1 polishes that design with signing implementation entry criteria, manual verification notes, and asset coexistence decision criteria. It does not sign the app, run notarization, create a DMG, create an installer, add release automation, or produce a new app binary.

Notarization Workflow Design is documented in [docs/notarization_workflow_design.md](docs/notarization_workflow_design.md). v6.10.0 is a docs-only design release for future notarized distribution. v6.10.1 polishes that design with implementation entry criteria, conservative status wording rules, and fallback decision criteria. It defines credential boundaries, conceptual notarization flow, result handling, asset naming, release notes requirements, verification notes, and fallback policy without running signing, notarization, stapling, DMG, installer, release automation, or producing a new app binary.

Signed Zip Implementation Readiness is documented in [docs/signed_zip_implementation_readiness.md](docs/signed_zip_implementation_readiness.md). v6.11.0 is a docs-only readiness review for a future signed zip implementation. It defines readiness gates, local signing preconditions, candidate manual flow, required checks, forbidden entries, release notes requirements, README install requirements, and fallback policy without signing the app, producing a new app binary, or changing runtime behavior.

v6.0.1 is a small App Shell / Sidebar polish release. It keeps Dashboard as the only active top-level section and adds macOS sidebar list styling plus sidebar accessibility polish. v6.0.2 follows up with App Shell release hygiene before v6.1.0 work begins. v6.0.3 adds stable App Shell accessibility identifiers for the sidebar, detail area, and section rows without changing runtime behavior. v6.0.4 adds focused AppSection metadata tests to lock the Dashboard-only v6.0.x shell boundary before v6.1.0 work begins. v6.0.5 closes the v6.0.x App Shell foundation series with a docs-only v6.1 implementation handoff. v6.1.0 adds the first staged Profiles / Model List Surface as a top-level sidebar destination while keeping Dashboard as the default Direct Mode control surface. v6.1.1 polishes the Profiles surface with summary cards and clearer list identifiers while preserving runtime behavior. v6.2.0 adds the first read-only Detail Inspector Foundation as a top-level sidebar destination for selected profile and connection target details. v6.2.1 polishes the Inspector with summary cards and clearer target status identifiers while preserving runtime behavior. v6.3.0 adds the first Logs Panel Refresh as a top-level sidebar destination for app-managed lifecycle and log context while preserving runtime behavior. v6.3.1 polishes the shared LogView with entry count display and stable identifiers while preserving runtime behavior. v6.4.0 adds the first Client Setup surface as a top-level sidebar destination for copy-safe OpenAI-compatible setup values while preserving Direct Mode and runtime behavior. v6.4.1 polishes Client Setup with a copy scope card while preserving existing copy actions and runtime behavior. v6.5.0 adds the first read-only Metrics / System Context surface while preserving Direct Mode and runtime behavior. v6.5.1 polishes Metrics with a context scope card while preserving read-only behavior. v6.6.0 records a docs-only App Layout Stabilization Review and does not produce a new app binary. v6.6.1 polishes the stabilization review with next-phase entry criteria and manual verification notes. v6.7.0 adds a docs-only Distribution / Packaging Readiness Review and does not produce a new app binary. v6.7.1 polishes that review with install documentation planning and packaging verification notes. v6.8.0 refreshes the README Install and Quick Start sections while preserving the current v6.5.1 app binary. v6.8.1 polishes the install guidance with GitHub Assets and checksum command details. v6.9.0 adds a docs-only Signed Distribution Design while preserving the current v6.5.1 unsigned app binary. v6.9.1 polishes the signed distribution design with entry criteria and verification notes. v6.10.0 adds a docs-only Notarization Workflow Design while preserving the current v6.5.1 unsigned app binary. v6.10.1 polishes the notarization workflow design with entry criteria, status wording, and fallback decision notes. v6.11.0 adds a docs-only Signed Zip Implementation Readiness review while preserving the current v6.5.1 unsigned app binary.

Screenshot refresh planning is documented in [docs/screenshot_refresh.md](docs/screenshot_refresh.md). Future screenshots should cover the v1.9+ Current Target summary and Adopted External Server states without exposing private paths or secrets.

First-run guidance is documented in [docs/onboarding_first_run.md](docs/onboarding_first_run.md). v2.4.0 adds a small in-app guidance panel that points first-time users toward executable path setup, model profile selection, diagnostics, Start, and Connection Settings while preserving Direct Mode.

Model Profile export and import are documented in [docs/model_profile_import_export.md](docs/model_profile_import_export.md). v4.0.0 treats Import / Export as a stable metadata-only feature set: Export Profiles, Import Preview, Import Selected Profiles, Rename for profile-name conflicts, explicit Replace for one unambiguous existing profile target, and deterministic regression tests. Import does not include model weights, caches, API keys, tokens, executable paths, or automatic server start.

## Current Binary Asset

The current downloadable app binary asset is the latest app-code release:

- `MLXServerManager-v6.5.1-unsigned.zip`

v4.0.0 and v4.1.0 are docs-only preparation releases. v4.2.0 through v5.0.0 are app-code dashboard polish releases with unsigned app zip assets. v5.1.0 through v5.9.0 are documentation releases. v6.0.0 is an app-code shell foundation release. v6.0.1 is an app-code sidebar polish release. v6.0.2 is an app-code release hygiene follow-up. v6.0.3 is an app-code App Shell identifier follow-up. v6.0.4 is an app-code AppSection metadata test follow-up with an unsigned app zip asset. v6.0.5 is docs-only and includes no new app zip. v6.1.0 is an app-code Profiles / Model List Surface release. v6.1.1 is an app-code Profiles Surface polish release. v6.2.0 is an app-code Detail Inspector Foundation release. v6.2.1 is an app-code Detail Inspector polish release. v6.3.0 is an app-code Logs Panel Refresh release. v6.3.1 is an app-code Logs Surface polish release. v6.4.0 is an app-code Client Setup Surface release. v6.4.1 is an app-code Client Setup Surface polish release. v6.5.0 is an app-code Metrics / System Context release. v6.5.1 is an app-code Metrics Surface polish release with an unsigned app zip asset. v6.6.0 is docs-only and includes no new app zip. v6.6.1 is docs-only and includes no new app zip. v6.7.0 is docs-only and includes no new app zip. v6.7.1 is docs-only and includes no new app zip. v6.8.0 is docs-only and includes no new app zip. v6.8.1 is docs-only and includes no new app zip. v6.9.0 is docs-only and includes no new app zip. v6.9.1 is docs-only and includes no new app zip. v6.10.0 is docs-only and includes no new app zip. v6.10.1 is docs-only and includes no new app zip. v6.11.0 is docs-only and includes no new app zip.

## Target Users

- macOS users running local MLX / `mlx-lm`.
- Users who want a GUI for `mlx_lm.server` Start, Stop, Restart, diagnostics, logs, model profiles, and connection settings.
- Users of OpenAI-compatible clients such as Hermes Agent, Open WebUI, LibreChat, AnythingLLM, or custom scripts.

## Supported Client Context

MLX Server Manager presents connection information for OpenAI-compatible clients. Typical clients use:

- Base URL: `http://127.0.0.1:8080/v1`
- Model ID: the selected Model Profile's `modelID`
- API key placeholder: `not-required-local`

The client sends inference requests directly to the selected server endpoint. MLX Server Manager starts, stops, monitors, diagnoses, and copies connection settings for app-managed `mlx_lm.server`; for adopted external servers it provides connection context only.

For Hermes Agent and similar clients, see [docs/hermes_agent_connection.md](docs/hermes_agent_connection.md). Hermes Agent is treated as an OpenAI-compatible client; MLX Server Manager still stays outside the inference request path.

## Current Feature Set

As of v5.9.0, MLX Server Manager includes:

- Start, Stop, and Restart for the `mlx_lm.server` process started by this app.
- Managed-process-only Stop and Restart behavior.
- Port availability check.
- Ready check via `GET /v1/models`.
- Settings save and restore.
- Model profile add, edit, delete, and selection.
- Export Profiles for model profile metadata backup.
- Import selected valid model profiles from JSON metadata.
- Import Preview validation for schema v1 profile export documents.
- Rename for imported profile-name conflicts.
- Explicit Replace for one unambiguous existing profile target.
- Import / Export fixtures and XCTest regression coverage.
- Model switching with `Restart required` state.
- Advanced Launch Options per model profile.
- External Server Detection for selected host/port endpoints.
- Adopt External Server and Forget External Server for connection context only.
- Current Target summary in Connection Settings:
  - Managed Server
  - External Server Detected
  - Adopted External Server
  - Not Running / Not Connected
- Dashboard foundation cards for Current Target and Server State.
- Polished Current Target wording for no target, managed server, external server, adopted external server, unavailable endpoint, and readiness states.
- Polished Server State wording for managed process ownership, external context, readiness, lifecycle, stopped, unavailable, and failed states.
- Display-only Dashboard guidance for logs, diagnostics, readiness failures, port busy states, unavailable targets, and external server log boundaries.
- Display-only Dashboard guidance for selected profile metadata, profile endpoint, current target relationship, Export Profiles, Import Preview, Rename, Replace, and metadata-only Import / Export safety.
- Display-only Dashboard Next Steps guidance for first-run setup, managed Start, external adoption, readiness expectations, Direct Mode, and manual troubleshooting boundaries.
- Dashboard grouping headings and scan order that clarify Next Steps, Current Target, Server State, Diagnostics & Logs, and Profiles / Import Export responsibilities.
- Display-only Dashboard Client Setup guidance for active endpoint, selected profile model ID, profile endpoint relationship, readiness before client use, and Direct Mode copy context.
- Dashboard UI Refresh v1 as the stable display-oriented overview for operational state and connection guidance.
- Lightweight Onboarding Guidance panel for first-run setup and connection state hints.
- Menu bar quick actions.
- Logs readability improvements.
- Copy Logs.
- Setup Diagnostics summary.
- Copy Diagnostics Summary.
- OpenAI-compatible connection setting copy actions:
  - Copy Base URL
  - Copy Model ID
  - Copy API key placeholder
  - Copy JSON config
  - Copy Hermes Agent config
  - Copy all connection settings
  - Copy `curl /v1/models` readiness check
  - Copy OpenAI-compatible chat example text
- Unsigned `.app` zip distribution documentation.

The copied `curl /v1/chat/completions` text is only a client-side convenience example. The app itself uses `/v1/models` for readiness and diagnostics and does not send inference requests.

## Non-Goals

- Chat UI.
- Proxy mode.
- LAN Web UI.
- App Intents.
- Auto unload.
- Hugging Face download manager.
- Model download in the current release.
- Model deletion.
- Hugging Face cache deletion.
- Multiple concurrent server management.
- Multiple model simultaneous launch.
- RAG.
- Embedding manager.
- Tool-call translation.
- Telemetry, analytics, crash reporting, external log sending, or cloud logging.
- Persistent file logging.
- Notarization, Developer ID signing, DMG, App Store distribution, Homebrew cask, auto updater, or CI/CD release automation.

Model download is a future candidate only if it can preserve `mlx-lm` runtime performance, avoid silent downloads or automatic server start, and keep clear safety and privacy boundaries.

## First-Run Workflow

1. Prepare a working local `mlx-lm` environment yourself.
2. Launch MLX Server Manager.
3. Open Settings and set the `mlx_lm.server executable path`.
4. Configure a Model Profile:
   - Display name
   - Model ID
   - Host
   - Port
   - Enable thinking option
   - Notes
5. Run Setup Diagnostics.
6. Start the managed server.
7. Confirm Ready status via `/v1/models`.
8. Copy Base URL, Model ID, JSON config, or curl examples from Connection Settings.
9. Paste those values into your OpenAI-compatible client.
10. Use Stop or Restart when needed.

For local use, `127.0.0.1` is recommended:

- Host: `127.0.0.1`
- Port: `8080`
- Base URL: `http://127.0.0.1:8080/v1`
- API key placeholder: `not-required-local`

Do not expose `mlx_lm.server` directly to the internet.

## OpenAI-Compatible Client Example

JSON config:

```json
{
  "api_key": "not-required-local",
  "base_url": "http://127.0.0.1:8080/v1",
  "model": "unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit"
}
```

List models:

```sh
curl http://127.0.0.1:8080/v1/models
```

Minimal chat-completions request for an external client:

```sh
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer not-required-local" \
  -d '{
    "model": "unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit",
    "messages": [
      {"role": "user", "content": "こんにちは"}
    ],
    "max_tokens": 128,
    "chat_template_kwargs": {
      "enable_thinking": false
    }
  }'
```

Qwen thinking behavior is controlled by the client request and model template behavior. MLX Server Manager only copies helper text; it does not run this request.

## Known Limitations

- The documented release asset is an unsigned local-use `.app` zip.
- The app is not notarized and is not signed with Developer ID.
- macOS Gatekeeper may warn when opening the app.
- Browser-downloaded unsigned builds may show "`MLXServerManager` is damaged and can't be opened"; this can be Gatekeeper quarantine, not necessarily a broken zip or app. Verify the Release asset and checksum before removing quarantine.
- The app does not bundle `mlx-lm`.
- The app does not bundle models.
- You must provide model files or Hugging Face cache separately.
- The app does not download models.
- The app does not optimize inference.
- The app does not alter the MLX performance path.
- Ready Check uses `/v1/models` only.
- The app does not test chat completions.
- Stop and Restart affect only the process started and held by this app.
- External `mlx_lm.server` processes are not stopped.
- There is no automatic updater, DMG, installer, or CI/CD release pipeline.

See [docs/known_limitations.md](docs/known_limitations.md) for the full list.

If macOS blocks the unsigned app after download, see [docs/distribution.md](docs/distribution.md#gatekeeper-quarantine-warning) before running it.

## Configuration and Repository Hygiene

The app stores runtime configuration under the user's Application Support directory:

- `settings.json`
- `models.json`

These files are local runtime state and should not be committed. Model directories, model artifacts, logs, virtual environments, `.env`, `HF_TOKEN`, `.app`, `.zip`, `.dSYM`, and build artifacts must also stay out of Git.

Do not hardcode user-specific absolute paths in source code or committed documentation.

## AI-Assisted Maintenance

This project is maintained with human-reviewed AI assistance for planning, documentation, implementation, and release preparation. AI-generated changes should remain small, reviewable, and consistent with the Direct Mode product boundary.

All changes should be reviewed for:

- No secrets.
- No local personal paths.
- No model files or runtime settings.
- No app bundles or build artifacts.
- No expansion into Chat UI, inference proxy behavior, or multi-backend wrapper behavior.

## Documentation

- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security: [SECURITY.md](SECURITY.md)
- Issue templates: [.github/ISSUE_TEMPLATE/](.github/ISSUE_TEMPLATE/)
- Public release checklist: [docs/public_release_checklist.md](docs/public_release_checklist.md)
- Stable scope: [docs/stable_scope.md](docs/stable_scope.md)
- Known limitations: [docs/known_limitations.md](docs/known_limitations.md)
- Hermes Agent connection guide: [docs/hermes_agent_connection.md](docs/hermes_agent_connection.md)
- Advanced Launch Options: [docs/advanced_launch_options.md](docs/advanced_launch_options.md)
- External Server Detection: [docs/external_server_detection.md](docs/external_server_detection.md)
- Adopt External Server: [docs/adopt_external_server.md](docs/adopt_external_server.md)
- Connection Settings polish: [docs/connection_settings_polish.md](docs/connection_settings_polish.md)
- Screenshot refresh plan: [docs/screenshot_refresh.md](docs/screenshot_refresh.md)
- Onboarding / first-run guidance: [docs/onboarding_first_run.md](docs/onboarding_first_run.md)
- Model Profile import/export design: [docs/model_profile_import_export.md](docs/model_profile_import_export.md)
- v1.0 plan: [docs/v1.0_plan.md](docs/v1.0_plan.md)
- v1.0.1 maintenance plan: [docs/v1.0.1_maintenance.md](docs/v1.0.1_maintenance.md)
- Requirements: [docs/requirements.md](docs/requirements.md)
- Architecture: [docs/architecture.md](docs/architecture.md)
- Testing: [docs/testing.md](docs/testing.md)
- Distribution: [docs/distribution.md](docs/distribution.md)
- Behavioral contracts: [contracts/](contracts/)
