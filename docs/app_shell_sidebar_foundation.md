# App Shell / Sidebar Foundation Design

## Status

- Implemented in `v6.0.0` as the App Shell / Sidebar Foundation.
- Polished in `v6.0.1` with small sidebar refinements.
- Dashboard remains the default and only active top-level section for this stage.
- Dashboard UI Refresh v1 remains the current stable surface.
- Later sections remain future-only.

The `v6.0.0` implementation narrows the broader [Full App Layout Refresh Design](full_app_layout_refresh.md) into a concrete app shell and sidebar foundation. It adds native top-level navigation while preserving Dashboard behavior, server lifecycle behavior, Direct Mode, import/export behavior, onboarding persistence, API key/token persistence, and process ownership boundaries.

## Goals

- Introduce a future navigation shell without changing runtime behavior.
- Make major app areas easier to discover.
- Keep Dashboard v1 as the landing overview.
- Preserve existing controls and behavior.
- Preserve Direct Mode.
- Preserve explicit lifecycle controls.
- Preserve external process ownership boundaries.
- Avoid creating Chat UI, inference proxy, or multi-backend router expectations.

## Non-goals

- No inference proxying.
- No Chat UI.
- No multi-backend routing.
- No hidden request rewriting.
- No model download.
- No model deletion.
- No external process ownership takeover.
- No automatic server Start, Stop, Restart, Adopt, or Forget behavior.
- No API key, token, or secret storage.
- No onboarding persistence or user tracking.
- No background automation.
- No runtime behavior changes.
- No new network calls.
- No change to `/v1/models` readiness or detection behavior.
- No `/v1/chat/completions` calls by the app.

## Navigation Structure

This structure starts in `v6.0.0` with Dashboard only. Other destinations remain intentionally deferred so the shell can land without moving controls or changing behavior.

### Dashboard

Purpose:

- Keep Dashboard v1 as the default landing page.
- Preserve the high-level operational overview.

Should show:

- Next Steps.
- Current Target.
- Server State.
- Client Setup.
- Diagnostics & Logs Guidance.
- Profiles & Import / Export guidance.

Should not do:

- Become a Chat UI.
- Become a router or inference proxy.
- Hide lifecycle controls behind automatic actions.
- Change Dashboard card order or behavior during the shell introduction.

Relation to existing v5 Dashboard cards:

- `DashboardOverviewView` remains the primary content for this section.
- v6.0.0 should initially mount the existing Dashboard surface rather than redesign it.

Implementation readiness:

- Implementation-ready as the default navigation destination if the existing view can be embedded without behavior changes.

### Profiles

Purpose:

- Provide a future home for model profile list and profile details.
- Make profile metadata and Import / Export easier to find.
- Use [Profiles / Model List Surface Design](profiles_model_list_surface.md) as the detailed follow-up design for a possible future `v6.1.0` implementation.

Should show:

- Model profile list.
- Selected profile display name and `modelID`.
- Endpoint metadata.
- Advanced Launch Options summary.
- Import / Export entry points.

Should not do:

- Download models.
- Delete model files.
- Mutate Hugging Face cache.
- Start servers after import.
- Change Import / Export schema, Rename behavior, Replace behavior, or selected profile semantics.

Relation to existing v5 Dashboard cards:

- Expands the profile context currently summarized by the Dashboard Profiles & Import / Export card.

Implementation readiness:

- Future-only for v6.0.0 unless the initial shell only links to existing profile controls without moving behavior. A dedicated Profiles / Model List Surface should be staged separately after the shell foundation.

### Server

Purpose:

- Provide a future home for managed server lifecycle context.
- Keep ownership and readiness language clear.

Should show:

- Current target.
- Managed process state.
- Readiness via `/v1/models`.
- Ownership notes.
- Explicit Start / Stop / Restart controls if moved or surfaced later.

Should not do:

- Automatically recover failed servers.
- Stop or restart external servers.
- Take ownership of adopted external servers.
- Add new readiness probes or background checks.

Relation to existing v5 Dashboard cards:

- Expands Server State and Current Target context.

Implementation readiness:

- Future-only beyond the shell foundation. v6.0.0 should not move lifecycle behavior unless separately scoped.

### Logs

Purpose:

- Provide a future home for managed server logs and app diagnostics output.

Should show:

- App logs.
- Managed server output surfaced by the app.
- Diagnostics entries.
- Copy Logs and Clear Logs if moved in a later scoped step.

Should not do:

- Capture external server logs.
- Scrape logs from unrelated processes.
- Add background log collection.

Relation to existing v5 Dashboard cards:

- Expands the Diagnostics & Logs Guidance area.

Implementation readiness:

- Future-only for detailed panel work.

### Client Setup

Purpose:

- Provide a future home for active endpoint and copy guidance.
- Keep Direct Mode client setup clear.

Should show:

- Active endpoint.
- Base URL.
- Model ID guidance.
- API key placeholder.
- JSON config.
- Hermes Agent config.
- readiness curl.
- Direct Mode explanation.

Should not do:

- Store real API keys, tokens, or secrets.
- Generate persistent client config files unless separately designed.
- Send inference requests.

Relation to existing v5 Dashboard cards:

- Expands Client Setup and Connection Settings copy context.

Implementation readiness:

- Future-only unless existing Connection Settings content is embedded unchanged.

### Settings

Purpose:

- Provide a future home for app preferences if the app shell needs a settings destination.

Should show:

- Existing app settings if they can be mounted without behavior changes.
- User-selected executable path controls.

Should not do:

- Add secrets storage.
- Add hidden runtime behavior.
- Add background automation.

Relation to existing v5 Dashboard cards:

- Settings is adjacent to Dashboard setup guidance but should not duplicate first-run guidance.

Implementation readiness:

- Future-only unless existing settings content is embedded unchanged.

## App Shell Layout

The `v6.0.0` implementation uses a native macOS `NavigationSplitView` app shell:

- Sidebar for major sections.
- Main content area for the selected section.
- Optional inspector/detail area deferred until a later step.
- Dashboard selected by default.

The initial implementation chooses the smallest native structure that preserves behavior and keeps the current Dashboard usable. See [Detail Inspector Foundation Design](detail_inspector_foundation.md) for the later candidate inspector boundary, [Logs Panel Refresh Design](logs_panel_refresh.md) for the future Logs section boundary, [Client Setup Surface Design](client_setup_surface.md) for the future Client Setup section boundary, and [Metrics / System Context Design](metrics_system_context.md) for the future metrics and system context boundary.

The implemented shell remains limited to app shell/sidebar foundation and does not pull in Profiles, Inspector, Logs, Client Setup, Metrics, or behavior changes. v6.0.1 keeps that boundary while adding small sidebar polish.

## Migration Strategy

`v6.0.0` migrates safely by:

1. Introduce the shell and sidebar.
2. Place existing Dashboard v1 as the first/default section.
3. Move no runtime behavior.
4. Duplicate no runtime controls unless needed for discoverability and explicitly reviewed.
5. Keep existing controls functional.
6. Preserve app state and persistence.
7. Keep future sections minimal or placeholder-only if needed.
8. Avoid changing Dashboard card order during the shell introduction.

The first implementation should make navigation safer and clearer without trying to solve profile tables, inspectors, logs refresh, metrics, or client setup redesign at the same time.

## Existing View Mapping

This is a design mapping, not an implementation requirement:

- `DashboardOverviewView` -> Dashboard.
- `StatusPanelView` -> Dashboard / Server.
- `ConnectionSettingsView` -> Client Setup / Settings.
- Model list and profile-related views -> Profiles.
- Managed server logs -> Logs.
- Import / Export controls -> Profiles or Settings depending on the existing structure.
- Setup Diagnostics -> Dashboard / Server / Settings depending on final navigation.

Views should continue to render state and send user intents. Process launch, termination, pipe handling, port probing, polling, and argument construction must remain outside SwiftUI views.

## Safety Boundaries

- Direct Mode remains unchanged.
- The app does not proxy inference requests.
- Lifecycle controls remain explicit.
- Stop and Restart apply only to app-managed processes.
- Adopted external servers remain connection context only.
- Forget External Server does not stop external processes.
- Import / Export remains metadata-only.
- No model download or deletion.
- No API key, token, or secret persistence.
- No hidden background checks or automatic diagnostics.

## Risks

- Sidebar navigation may hide important controls.
- Duplicate controls may confuse users.
- Users may think the app proxies requests if Client Setup is too prominent without Direct Mode explanation.
- Users may think adopted external servers are app-owned if ownership notes are not visible.
- Model profile metadata may be confused with installed model files.
- A larger layout may increase complexity without improving safety.

## Acceptance Criteria for v6.0.0

The implementation should only be accepted if:

- Dashboard v1 remains available.
- Existing runtime behavior is unchanged.
- Direct Mode is still obvious.
- External ownership boundary is still obvious.
- Start / Stop / Restart behavior is unchanged.
- Import / Export behavior is unchanged.
- No secrets persistence is added.
- UI changes are reversible and staged.
- New shell code does not build process arguments or perform lifecycle work inside views.

## Future Stages

These versions remain proposals only:

- `v6.0.0`: App Shell / Sidebar Foundation.
- `v6.1.0`: Profiles / Model List Surface.
- `v6.2.0`: Detail Inspector Foundation.
- `v6.3.0`: Logs Panel Refresh.
- `v6.4.0`: Client Setup Surface.
- `v6.5.0`: Metrics / System Context Design.

## v6.0.0 Implementation Boundary

`v6.0.0` implements only the app shell, sidebar navigation, and default Dashboard mounting. It does not implement model table, detail inspector, logs panel refresh, metrics widgets, Chat UI, model download, new network behavior, new persistence, new app binary packaging, zip asset, tag, release, or any runtime behavior change.
