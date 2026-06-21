# Model Availability Surface Design

## Release

- Added in `v6.25.0`.
- Docs-only design for a future model availability surface.
- Follows `v6.18.0` / `v6.18.1` Model Availability Documentation.
- No Swift source, tests, path checks, directory scans, downloads, model deletion, diagnostics execution, or runtime behavior changes are included in this release.

## Purpose

`v6.25.0` defines where and how future model availability information may appear in the app before any UI or path-checking implementation is added.

The goal is to make local model presence understandable without implying automatic model management, recursive scanning, compatibility certification, or external server ownership.

This design keeps the app's current Direct Mode boundary unchanged:

```text
client -> mlx_lm.server
```

A model availability surface may help users understand whether the selected profile points at a configured, present, missing, external, or unknown model target. It must not enter the inference path or manage model files automatically.

## Current State

Current app behavior:

- profiles store user-configured model identifiers and endpoint settings;
- the app can start and stop only the managed `mlx_lm.server` process it launches;
- read-only surfaces show current target, profile, client setup, logs, and metrics context;
- model availability terms are documented but not implemented as a dedicated surface;
- no automatic model directory scan exists;
- no download manager exists;
- no model deletion or cache cleanup exists;
- no compatibility checker exists.

Current availability documentation already defines conservative wording for:

- configured;
- present;
- missing;
- external;
- unknown;
- stale state;
- explicit check scope.

## Design Goals

A future model availability surface should:

- show the selected profile's model availability state in plain language;
- distinguish user-configured metadata from observed local file presence;
- make stale or unchecked state visible;
- keep checks explicit and user-triggered;
- show only copy-safe path summaries;
- avoid promising model compatibility unless a separate compatibility check exists;
- provide safe next actions such as choose profile, run explicit check, or open documentation;
- remain read-only unless a separate model download or profile editing feature is explicitly implemented.

## Non-Goals

`v6.25.0` does not design or approve:

- automatic background scanning;
- recursive model directory indexing;
- model download implementation;
- model deletion;
- cache cleanup;
- compatibility certification;
- endpoint inference tests;
- `/v1/chat/completions` checks;
- traffic inspection;
- telemetry;
- persistence of model availability history;
- external server process ownership;
- client auto-configuration.

## Placement

A future model availability surface can be introduced in one of two conservative stages.

### Stage 1: Read-Only Card

Add a compact card to existing read-only surfaces:

- Dashboard: short availability state for the selected profile.
- Detail Inspector: fuller selected-profile availability detail.
- Profiles surface: per-profile availability badge only after explicit check.

Stage 1 should avoid adding a new top-level sidebar section unless the information becomes too large for existing surfaces.

### Stage 2: Dedicated Surface

A dedicated sidebar section may be considered later only if the app adds explicit user-triggered availability checks across multiple profiles.

A dedicated surface should still remain read-only by default and should not imply file management.

## Primary User Questions

The surface should answer only narrow questions:

1. What model target is configured for the selected profile?
2. Has local presence been checked explicitly?
3. Was the configured local path present at the time of the check?
4. Is the target external or not inspectable by the app?
5. What is the safest next action?

It should not answer broader questions such as:

- Is this model compatible with my hardware?
- Is this the fastest model for this machine?
- Is the model safe or trustworthy?
- Is the external server managed by this app?
- Should old model files be deleted?

## Availability States

Use the terms from `docs/model_availability_documentation.md`.

Recommended surface states:

| State | Meaning | User-facing tone |
| --- | --- | --- |
| `configured` | A profile has a model identifier or path-like value. | Neutral. Configuration exists, but presence may not be checked. |
| `present` | An explicit local check found the expected path at check time. | Positive but scoped. Do not imply compatibility. |
| `missing` | An explicit local check did not find the expected path at check time. | Actionable. Ask the user to update profile or choose model location. |
| `external` | Target appears to be served outside app-managed local model inspection. | Informational. Do not imply ownership. |
| `unknown` | No explicit check has run or state is stale. | Neutral. Offer explicit check. |
| `notInspectable` | The app cannot inspect the target safely or within scope. | Conservative. Explain the boundary. |

## Data Sources

A future surface may use only explicit and local data sources:

- selected `ModelConfig` metadata;
- user-selected model path or identifier if available;
- explicitly triggered local file existence check;
- current target summary already known by the app;
- external server/adopted target metadata already surfaced elsewhere.

Do not use:

- background directory scans;
- Hugging Face API calls;
- endpoint inference calls;
- prompt/completion traffic;
- system-wide process discovery to infer ownership;
- telemetry or remote analytics.

## Explicit Check Behavior

If availability checking is implemented later, the surface should make the trigger explicit:

- button text: `Check Model Availability`;
- scope text: `Checks the configured local path for the selected profile only.`;
- stale text: `Last checked at <time>. State may have changed.`;
- no automatic re-check on app launch;
- no automatic re-check on profile selection;
- no recursive scan;
- no download attempt;
- no deletion or cleanup suggestion beyond documentation links.

A check should be cancellable only if it can become long-running. A single file-existence check should complete quickly and does not need progress UI.

## UI Content Model

A future card can use this structure:

```text
Model Availability
Status: Unknown
Profile: Qwen Example
Configured target: qwen/example-mlx-4bit
Last checked: Not checked
Next step: Run an explicit availability check if you want local presence confirmation.
```

When state is `present`:

```text
Status: Present
Scope: Selected profile only
Checked path: ~/Models/mlx/example-model
Last checked: 2026-06-21 18:00
Note: Presence does not confirm model compatibility or performance.
```

When state is `missing`:

```text
Status: Missing
Scope: Selected profile only
Checked path: ~/Models/mlx/example-model
Next step: Update the profile path or place the model at the configured location.
```

When state is `external`:

```text
Status: External
Scope: App cannot inspect external server model files.
Next step: Use the external server's own tools to confirm model availability.
```

## Copy-Safe Path Display

The surface should compact user paths before display or copy:

- show `~/Models/mlx/example-model` instead of `/Users/<name>/Models/mlx/example-model`;
- do not show account names by default;
- do not show tokens or query strings;
- do not include raw command output;
- do not include full logs;
- do not include environment variables.

Detailed paths can be shown only when the user explicitly opens a local-only detail control. Copy summary should use compact paths.

## Relationship To Profiles

Model availability is a property of the selected profile's configured target at a point in time.

The surface must not:

- mutate profile fields during a check;
- create profiles automatically;
- rename profiles;
- replace profiles;
- change selected profile;
- start, stop, or restart a server;
- alter advanced launch options.

If the configured target changes, the previous availability result should be considered stale or invalid.

## Relationship To Diagnostics

Model availability can later appear as one diagnostics category, but the availability surface should not depend on full diagnostics execution.

A future integration may:

- show the most recent explicit availability check as diagnostics input;
- include availability state in a copied diagnostics summary;
- reuse copy-safe redaction rules from diagnostics fixtures.

A future integration must not:

- run endpoint tests to prove availability;
- call `/v1/chat/completions`;
- infer model presence from generated responses;
- persist diagnostics history without separate design approval.

## Relationship To Model Download

The model availability surface may point users toward model download documentation or a future download manager, but it must not implement download behavior itself.

If a download manager is added later, availability should remain clear about boundaries:

- `missing` does not automatically mean download is safe;
- `present` does not mean the model is compatible;
- partial downloads require a distinct state if that feature exists;
- credentials must never appear in availability summaries.

## Relationship To External Servers

External server targets should be reported as external or not inspectable unless the app has a clear local path selected by the user.

The surface must not claim:

- the external server is owned by MLX Server Manager;
- the app can stop the external process;
- the app can inspect external model files;
- the external model is locally present;
- the external endpoint's model identifier maps to a local file.

## Accessibility And Identifiers

If implemented, the surface should use stable identifiers such as:

- `modelAvailability.card`;
- `modelAvailability.status`;
- `modelAvailability.profileName`;
- `modelAvailability.configuredTarget`;
- `modelAvailability.lastChecked`;
- `modelAvailability.nextAction`;
- `modelAvailability.checkButton`.

VoiceOver text should include the state and scope together, for example:

```text
Model Availability, Unknown, selected profile only, not checked.
```

## Empty And Error States

Recommended states:

- No selected profile: `Select a profile to view model availability.`
- Empty target: `No model target is configured for this profile.`
- Invalid local path syntax: `The configured target cannot be checked as a local path.`
- Check failed: `Availability check failed. No model files were changed.`
- Permission denied: `The app could not read this location. Choose a different path or adjust permissions.`
- Stale result: `The profile changed after the last check. Run availability check again.`

All error states should be scoped and should avoid suggesting automatic repair.

## Manual Verification Checklist

A future implementation should verify:

- selected profile with unchecked target shows `unknown`;
- explicit check for existing local path shows `present`;
- explicit check for missing local path shows `missing`;
- external target shows `external` or `notInspectable`;
- compact path display removes `/Users/<name>`;
- copied summary does not include tokens, raw command output, prompts, responses, or full logs;
- changing the selected profile marks previous availability state stale or profile-scoped;
- checking availability does not mutate profiles;
- checking availability does not start, stop, or restart `mlx_lm.server`;
- checking availability does not call `/v1/models` unless a separate readiness check is explicitly requested;
- checking availability never calls `/v1/chat/completions`;
- no background scan occurs on launch or profile selection;
- no model download, deletion, cache cleanup, telemetry, or traffic inspection occurs.

## Implementation Entry Criteria

Start implementation only when all of the following are true:

- the first UI placement is selected: Dashboard card, Detail Inspector card, Profiles badge, or dedicated surface;
- local target source is explicitly defined;
- stale-state behavior is defined;
- copy-safe path compaction helper exists or is planned;
- availability check scope is limited to the selected profile;
- tests can run without real user paths or model files;
- fixtures use placeholder paths only;
- no runtime lifecycle behavior changes are required.

## Release Acceptance

`v6.25.0` is acceptable if:

- it adds this design document;
- README references the design;
- `docs/tasks.md` records the completed docs-only work;
- no Swift source files change;
- no test files change;
- no fixture files change;
- no model availability checks are implemented;
- no endpoint calls are added;
- no inference requests are added;
- no background monitoring, telemetry, traffic inspection, model deletion, model scanning, cache cleanup, or release automation is added;
- the current downloadable app binary remains `v6.5.1`.
