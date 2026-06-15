# Model Profile Import / Export Design

## Overview

Model Profile Import / Export started as a v2.6.0 docs-only design for backing up, moving, and sharing MLX Server Manager profile metadata safely.

v2.7.0 implements Export Profiles. v2.9.0 implements Import Profiles Preview. v3.0.0 implements importing selected valid profiles without conflicts. v3.3.0 implements Rename for profile-name conflicts. Replace and broader conflict handling remain future work.

Import and export apply only to Model Profile metadata. They do not include model weights, Hugging Face cache, local runtime settings, secrets, or app binaries.

Import/export follows the product principles in [Product Direction](product_direction.md): preserve `mlx-lm` runtime performance, keep metadata operations explicit and side-effect-free, and avoid hiding server lifecycle or ownership boundaries.

## v2.7.0 Implementation Status

Implemented:

- `Export Profiles...` button in the Model Profiles area.
- Save panel with default filename `MLXServerManager-Profiles.json`.
- JSON export document with `schemaVersion`, `app`, `exportedAt`, and `profiles`.
- Pretty printed, sorted-key JSON with ISO 8601 dates.
- Export of profile `name`, `modelID`, `host`, `port`, and non-empty `advancedLaunchOptions`.
- UI privacy summary near the export button.
- Success, cancel, and failure messages in the UI and Logs.

Not implemented:

- Replace conflict handling.
- Selecting an imported profile after import.
- Model download or install automation in the current import/export flow.

Export is side-effect-free with respect to server lifecycle. It does not start, stop, restart, adopt, forget, readiness-check, or send HTTP requests.

## v2.8.0 Import Preview / Validation Design Polish

v2.8.0 refines the future Import Profiles design. It is a documentation-only step. Import Profiles remains unimplemented, while Export Profiles remains implemented as of v2.7.0.

The v2.8.0 design keeps import limited to Model Profile metadata. Import must not include model weights, Hugging Face cache, API keys, tokens, secrets, executable paths, app settings, runtime state, process ownership, or external server ownership.

### Import Preview Sheet Design

The future Import Preview sheet should show document-level information before any profile is applied:

- source file name,
- `schemaVersion`,
- `app` field,
- `exportedAt`,
- total profiles in the file,
- valid profile count,
- invalid profile count,
- warning count,
- profiles list,
- per-profile status,
- conflict status,
- selected import action.

Each profile row should show:

- profile name,
- `modelID`,
- host,
- port,
- whether Advanced Launch Options are included,
- validation status,
- conflict status,
- planned action: `import`, `skip`, `rename`, `replace`, or `invalid-blocked`.

Preview must be side-effect-free:

- no managed server start, stop, or restart,
- no external process operation,
- no adopted external server state changes,
- no selected profile or current target changes,
- no readiness check,
- no `/v1/models` call,
- no external HTTP request,
- no model download,
- no model file or cache changes.

### Validation Result Model

Future implementation should use an explicit validation result model rather than mixing validation with UI state:

```text
ImportValidationResult
- documentStatus
- profiles[]
- errors[]
- warnings[]
- infos[]
- canImport

ValidatedImportProfile
- sourceIndex
- name
- modelID
- host
- port
- advancedLaunchOptions
- status
- messages[]
- conflict
- plannedAction
```

Severity policy:

- `error`: blocks import for the affected profile or entire document.
- `warning`: can be imported only after user review, confirmation, or adjustment.
- `info`: informational and non-blocking.

Document-level blocking errors, such as unsupported schema versions, should prevent partial import. Profile-level errors should block only invalid entries when the document itself is supported.

### Validation Rules

Document validation:

- JSON must parse successfully.
- Top-level value must be an object.
- `schemaVersion` is required and must be supported.
- `app` should be `MLXServerManager`.
- `profiles` must be an array.
- Unsupported schema versions block the entire import.

Profile validation:

- `name` must not be empty.
- `modelID` must not be empty.
- `host` must not be empty and must be valid for the app's host policy.
- `port` must be an integer in `1...65535`.
- probability values such as temperature, top-p, and min-p must be in `0...1`.
- positive integer fields must be greater than `0`.
- `chatTemplateArgs` must be valid JSON when present and non-empty.
- unknown fields must not be executed.
- unknown fields should be ignored unless a future schema explicitly supports them.
- executable path fields must be ignored or rejected.
- API key, token, or secret-looking fields must be ignored or rejected with a warning or error.
- model weight paths, local model paths, and cache paths must not be imported.

Invalid entries should not block all valid entries unless the document has a document-level blocking error.

### Unsupported Schema Version

Unsupported `schemaVersion` is a document-level blocking error. The app should not silently reinterpret unknown schemas and should not partially import profiles from an unsupported document.

Example message:

```text
This file uses schemaVersion 2, but this version of MLX Server Manager supports schemaVersion 1 only. No profiles were imported.
```

Future migration must be explicit and testable.

### Conflict Handling

Potential conflicts:

- same profile name as an existing profile,
- same `modelID + host + port` as an existing profile,
- duplicate profile names inside the imported file,
- duplicate equivalent profiles inside the imported file,
- replace target ambiguity,
- generated rename result collision.

Allowed planned actions:

- `skip`: do not import the profile.
- `rename`: import with a generated non-conflicting name.
- `replace`: replace an existing profile only after explicit confirmation.

Default behavior should be `skip` or `rename`, not `replace`. Replace must require explicit confirmation.

Rename should be deterministic, for example:

- `<name> (Imported)`
- `<name> (Imported 2)`

Invalid profiles cannot be imported even if renamed. Import must not start a server. Import should not automatically change the selected target unless a future implementation explicitly asks the user.

### Advanced Launch Options Validation

Advanced Launch Options may be imported as metadata, but they remain optional and user-tunable.

Policy:

- Start-time validation still applies.
- Empty advanced values are omitted from launch arguments.
- `rawExtraArgs` is displayed in the preview.
- `rawExtraArgs` should show a warning.
- `chatTemplateArgs` must be valid JSON when present.
- numeric constraints must mirror current app validation.
- unknown advanced fields are ignored unless the schema supports them.

Example warning:

```text
This profile includes raw extra server arguments. Review them before starting a managed server.
```

### Privacy and Local Path Boundary

Import must not treat shared JSON as trusted executable input. Unknown fields are data, not commands.

Privacy policy:

- Do not import `mlx_lm.server executable path`.
- Do not import local model paths.
- Do not import Hugging Face cache paths.
- Do not import API keys, tokens, or secrets.
- Warn that export files may reveal model IDs, profile names, host, port, notes, and Advanced Launch Options.
- Warn that private model IDs can be sensitive.

Import Preview should help users inspect shared files before importing. It should not imply that model files exist locally.

### Import Side-Effect Boundary

Preview side effects:

- no lifecycle changes,
- no network calls,
- no readiness checks,
- no adopted external server changes,
- no current target changes,
- no model download,
- no model file deletion,
- no cache changes.

Future actual import side effects:

- write only selected valid profile metadata,
- do not start a managed server,
- do not adopt an external server,
- do not take process ownership,
- do not change external process state.

Selecting an imported profile after import should be a future explicit option, default off or behind confirmation.

### Error, Warning, and Info Message Examples

Error examples:

- `Import file is not valid JSON.`
- `Unsupported profile export schema version.`
- `The import file must contain a profiles array.`
- `Profile name is required.`
- `Model ID is required.`
- `Host is required.`
- `Port must be between 1 and 65535.`
- `Temperature must be between 0 and 1.`
- `Chat Template Args must be valid JSON.`

Warning examples:

- `This profile includes raw extra server arguments. Review them before starting a managed server.`
- `Duplicate profile name found. Choose skip, rename, or replace.`
- `Replace requires explicit confirmation.`
- `Secret-looking field ignored.`
- `Executable path ignored. Configure it locally in Settings.`
- `Local path ignored. Model files are not imported.`

Info examples:

- `Profile metadata only. No model files will be imported.`
- `No server will be started after import.`
- `External server ownership will not change.`

### Future Implementation Staging

- v2.9.0: Import Preview implementation.
- v3.0.0: Import selected valid profiles.
- v3.2.0: Conflict handling design polish.
- v3.3.0: Rename profile-name conflicts.
- v3.4.0 candidate: Replace conflicted profiles.
- v3.5.0 candidate: Import/export schema tests and fixtures.
- v4.0.0 candidate: Import/export stable release.

## v2.9.0 Import Preview Implementation Status

v2.9.0 implements Import Profiles Preview only.

Implemented:

- `Import Profiles...` button near `Export Profiles...`.
- JSON file picker for profile export documents.
- Import Preview sheet.
- Document-level validation for JSON object shape, `schemaVersion`, `app`, and `profiles`.
- `schemaVersion` 1 support.
- Blocking document-level error for unsupported schema versions.
- Profile-level validation for name, `modelID`, host, port, and Advanced Launch Options.
- Warnings for `rawExtraArgs`, secret-looking fields, executable path fields, local path fields, and ignored unknown fields.
- Conflict preview for existing profile names, existing `modelID + host + port`, duplicate imported names, and duplicate imported `modelID + host + port`.
- Preview rows showing profile metadata, validation status, messages, conflict summary, and planned action summary.
- Clear `Preview only` messaging in the UI and Logs.

Not implemented:

- Actual profile import or save.
- Writing imported profiles to `models.json`.
- Selecting imported profiles.
- Skip, rename, or replace execution.
- Conflict resolution actions.
- Model file import.
- Hugging Face cache import.
- API key, token, secret, executable path, or local path import.
- Automatic server start after preview.

Import Preview remains side-effect-free. It reads the selected JSON file, decodes metadata, validates it, and updates preview UI state only. It does not start, stop, restart, adopt, forget, readiness-check, call `/v1/models`, make external HTTP requests, download models, delete files, mutate caches, save app settings, save profiles, or change external process ownership.

## v3.0.0 Import Selected Profiles Implementation Status

v3.0.0 implements importing selected valid profiles from the Import Preview sheet.

Implemented:

- Profile selection in Import Preview.
- Default selection for importable profiles.
- Disabled selection for invalid profiles.
- Disabled selection for conflict profiles.
- `Import Selected Profiles` button.
- Confirmation alert before import.
- Re-validation and conflict re-check before saving.
- Appending selected valid non-conflicting profile metadata to `models.json`.
- Success and no-op messages in UI and Logs.

Importable profiles:

- must have no validation errors,
- must have no conflict summary,
- must have valid `name`, `modelID`, host, and port,
- may include valid Advanced Launch Options metadata.

Skipped profiles:

- invalid profiles,
- profiles with conflicts,
- profiles that become conflicting during final re-check.

Not implemented:

- rename conflict handling,
- replace conflict handling,
- forced import of conflicting profiles,
- selecting imported profiles after import,
- model file import,
- Hugging Face cache import,
- API key, token, secret, executable path, or local path import.

Import saves only model profile metadata:

- profile name,
- `modelID`,
- host,
- port,
- Advanced Launch Options.

Import does not save runtime state, PID, memory metrics, readiness result, selected current target state, adopted external server state, logs, unknown fields, secrets, executable paths, local model paths, model weights, or caches.

After import, selected profile is not changed automatically. Server lifecycle and external process ownership are unchanged. Import does not start, stop, restart, adopt, forget, readiness-check, call `/v1/models`, make external HTTP requests, download models, delete files, or mutate caches.

## v3.2.0 Conflict Handling Design Polish

v3.2.0 is a documentation-only design step for future import conflict handling. It does not implement Rename or Replace.

### Current v3.0.0 Behavior

Current import behavior is intentionally conservative:

- valid and non-conflicting profiles can be imported,
- invalid profiles are blocked,
- conflicting profiles are skipped and disabled,
- Rename is not implemented,
- Replace is not implemented,
- selected profile does not change automatically,
- no server lifecycle changes occur,
- no network calls occur,
- no `/v1/models` calls occur,
- no external process ownership changes occur.

### Conflict Types

Conflict handling must account for:

- same profile name as an existing profile,
- same `modelID + host + port` as an existing profile,
- duplicate names inside the imported file,
- duplicate `modelID + host + port` inside the imported file,
- rename result colliding with an existing profile,
- rename result colliding with another imported profile,
- replace target ambiguity,
- profile becoming invalid after rename,
- unsupported `schemaVersion`,
- document-level blocking errors.

### Conflict Resolution Goals

Conflict resolution should:

- preserve user control,
- avoid silent overwrite,
- avoid automatic process changes,
- avoid changing selected profile automatically,
- make the action for each profile visible before import,
- keep the default action safe,
- avoid hidden server Start / Stop / Restart,
- avoid secrets, model weights, caches, and executable paths,
- keep import predictable and reversible where possible.

Conflict handling follows the project principles: preserve `mlx-lm` runtime performance, keep metadata operations explicit, and avoid hidden lifecycle or ownership changes.

### Default Behavior

The default behavior should remain safe:

- conflicting profiles default to `Skip`,
- Rename and Replace are opt-in,
- invalid profiles cannot be imported,
- document-level blocking errors disable all import actions,
- non-conflicting valid profiles can remain selected by default,
- conflict profiles should not be selected unless the user explicitly chooses Rename or Replace in a future UI.

### Rename Design

Rename is safer than Replace and is the preferred first conflict-resolution implementation candidate.

v3.3.0 implements the initial Rename behavior for profile-name conflicts:

- user can choose Rename for name conflicts,
- Rename must be previewed before import,
- renamed profile must be revalidated,
- renamed profile must not collide with existing profiles,
- renamed profile must not collide with other imported profiles,
- Rename does not change `modelID`, host, or port unless a future design explicitly supports endpoint editing,
- Rename does not start servers,
- Rename does not change selected profile.

Deterministic suggested names:

- `<name> (Imported)`,
- `<name> (Imported 2)`,
- `<name> (Imported 3)`.

Suggested UI:

- per-profile action dropdown with `Skip` and `Rename`,
- proposed new name field,
- inline validation message,
- optional `Use Suggested Name` action.

### Replace Design

Replace is higher risk than Rename and should be staged later.

v3.4.0 candidate behavior:

- Replace requires explicit confirmation,
- Replace shows before / after profile metadata comparison,
- Replace clearly identifies the target existing profile,
- Replace is not offered if the target is ambiguous,
- Replace only changes profile metadata,
- Replace does not delete model weights,
- Replace does not delete caches,
- Replace does not affect logs,
- Replace does not change selected profile automatically,
- Replace does not start, stop, or restart servers,
- Replace does not affect adopted external server state.

Confirmation message:

```text
Replace existing profile metadata? This will update the selected profile configuration only. It will not delete model files, start servers, call /v1/models, import secrets, or change process ownership.
```

### Duplicate Handling

Duplicates inside the imported file should be resolved before conflicts with existing profiles:

- duplicate imported names default to Skip or Rename,
- duplicate imported `modelID + host + port` values default to Skip,
- if multiple imported profiles target the same existing profile for Replace, block until the user resolves ambiguity,
- rename suggestions should be deterministic,
- order-dependent behavior should be avoided or clearly documented.

### Confirmation Requirements

Future conflict actions should require confirmation when they can alter existing metadata:

- Rename should show the final imported name before import.
- Replace must require explicit confirmation.
- Replace must show the target existing profile.
- Document-level blocking errors must prevent confirmation and import.
- Confirmation must state that no server lifecycle, network, model download, model deletion, secret import, or process ownership change occurs.

### Selection Behavior

Selection should remain predictable:

- valid non-conflicting profiles are selected by default,
- invalid profiles are disabled,
- conflict profiles default to Skip,
- future Rename action can make a profile importable if the resulting name is valid and non-conflicting,
- future Replace action can make a profile importable only with explicit target and confirmation,
- selected profile in the app should not change automatically after import,
- optional `select imported profile after import` should remain future work and default off if ever added.

### Import Result Logging

Import result logs should include:

- imported count,
- skipped count,
- renamed count,
- replaced count,
- invalid count,
- conflict count,
- safety note that no server lifecycle changes occurred,
- safety note that no secrets were imported,
- safety note that no executable paths were imported.

Example:

```text
Import completed: 2 imported, 1 skipped, 0 renamed, 0 replaced. Servers were not started or modified.
```

### Error, Warning, and Confirmation Messages

Suggested messages:

- `Name conflict: an existing profile already uses this name.`
- `Endpoint conflict: an existing profile already uses this modelID, host, and port.`
- `Duplicate imported name: choose Skip or Rename.`
- `Duplicate imported endpoint: choose Skip.`
- `Rename collision: the proposed name already exists.`
- `Replace target is ambiguous. Choose one target or skip this profile.`
- `Replace requires explicit confirmation.`
- `Invalid profile cannot be imported.`
- `Document-level error blocks import.`
- `Selected profile unchanged after import.`
- `Server lifecycle unchanged after import.`

### Safety and Side-Effect Boundaries

Conflict handling remains model profile metadata only.

It must not:

- import model weights,
- import Hugging Face cache,
- import API keys, tokens, or secrets,
- import executable paths,
- start a managed server,
- stop or restart a managed server,
- call `/v1/models`,
- make external HTTP requests,
- kill, stop, restart, adopt, or take ownership of external processes,
- change Adopted External Server state,
- change selected profile automatically.

### Future Implementation Staging

- v3.3.0: Rename profile-name conflicts implementation.
- v3.4.0 candidate: Replace conflicted profiles implementation.
- v3.5.0 candidate: Import/export fixtures and tests.
- v4.0.0 candidate: Import/export stable release.

## v3.3.0 Rename Conflicted Profiles Implementation Status

v3.3.0 implements Rename for imported profiles that are otherwise valid but conflict by profile name.

Implemented:

- per-profile `Skip`, `Import`, and `Rename` actions in Import Preview,
- Rename action only for profile-name conflicts,
- suggested deterministic names such as `<name> (Imported)` and `<name> (Imported 2)`,
- editable rename field before import,
- UI validation for empty or whitespace rename names,
- UI validation for rename names that already exist locally,
- UI validation for rename names that conflict with another selected import,
- final import-time validation before writing to `models.json`,
- import result logging with renamed count,
- no selected profile change after import.

Not implemented:

- Replace conflict handling,
- overwrite of existing local profiles,
- endpoint/runtime identity conflict resolution by Rename,
- model file import,
- Hugging Face cache import,
- API key, token, secret, executable path, or local path import,
- automatic server start after import.

Rename changes only the imported profile display name before saving it as a new profile. It does not modify an existing local profile. It does not modify `modelID`, host, port, Advanced Launch Options, runtime state, selected profile, adopted external server state, or process ownership.

Import remains metadata-only and side-effect-free with respect to server lifecycle. It does not start, stop, restart, adopt, forget, readiness-check, call `/v1/models`, make external HTTP requests, download models, delete files, or mutate caches.

## Goals

- Let users back up saved Model Profiles.
- Let users move profiles between Macs or local environments.
- Let teams or communities share profile templates.
- Let users preview imported profiles before applying them.
- Make conflict handling explicit before import.
- Keep secrets, tokens, model weights, caches, and local runtime state out of exported files.
- Preserve Direct Mode and existing server lifecycle boundaries.

## Non-goals

- No model download.
- No model deletion.
- No model weight export.
- No Hugging Face cache export.
- No API key export.
- No Hugging Face token export.
- No GitHub token export.
- No automatic server start after import.
- No external process operation.
- No inference proxy.
- No Chat UI.
- No multi-backend routing.
- No automatic tuning.
- No migration of app-managed process ownership.

## Use Cases

- Back up a working set of Model Profiles before changing local settings.
- Move profile metadata from one Apple Silicon Mac to another.
- Share a baseline profile template for a public model ID.
- Keep Advanced Launch Options consistent across local environments.
- Review a contributed profile before importing it.

## Direct Mode Boundary

Import / Export must not change the inference path:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

MLX Server Manager remains a process and configuration control surface. It does not proxy inference requests, run chat completions, or route requests between backends.

Importing profiles must not start `mlx_lm.server`, stop a managed server, stop an external process, adopt an external server, or change process ownership.

## Security and Privacy Boundary

Export files should be safe to inspect as plain text before sharing. They may still reveal model IDs, host, port, display names, notes, and Advanced Launch Options, so the app should warn users before export.

Export must not include:

- API keys.
- Hugging Face tokens.
- GitHub tokens.
- `.env` values.
- `HF_TOKEN`.
- model weights.
- model cache directories.
- Hugging Face cache contents.
- `settings.json`.
- `models.json` as a raw file copy.
- app bundles or build artifacts.
- local logs.
- personal paths by default.

Private model IDs can still reveal private context. The export flow should ask users to review profile names, model IDs, notes, and advanced args before sharing.

## Export Format

Recommended format:

- JSON.
- Versioned schema.
- Human-readable.
- Explicit app name.
- ISO 8601 `exportedAt` timestamp.
- `profiles` array.
- Optional top-level `notes`.

Example:

```json
{
  "schemaVersion": 1,
  "app": "MLXServerManager",
  "exportedAt": "2026-06-15T00:00:00Z",
  "notes": "Example public profile metadata export.",
  "profiles": [
    {
      "name": "Qwen3.6 35B 4bit",
      "modelID": "unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit",
      "host": "127.0.0.1",
      "port": 8080,
      "enableThinking": false,
      "notes": "Example profile template.",
      "advancedLaunchOptions": {
        "rawExtraArgs": "",
        "chatTemplateArgs": "",
        "defaultTemperature": null,
        "defaultTopP": null,
        "defaultTopK": null,
        "defaultMinP": null,
        "defaultMaxTokens": null,
        "allowedOrigins": "",
        "logLevel": "",
        "decodeConcurrency": null,
        "promptConcurrency": null,
        "prefillStepSize": null,
        "promptCacheSize": null,
        "promptCacheBytes": null
      }
    }
  ]
}
```

Export defaults:

- Do not export `mlx_lm.server executable path`.
- Do not export local model paths.
- Do not export API key placeholder.
- Do not export runtime state.
- Do not export selected profile state unless a future schema explicitly needs it.

If a future `includeExecutablePath` option is added, it should be off by default and guarded by a privacy warning.

v2.7.0 exports all current in-memory Model Profiles. If the profile list is empty, Export is unavailable and no file is written.

## Import Behavior

Import is not implemented in v2.7.0.

Recommended flow:

1. User clicks `Import Profiles`.
2. App opens a file picker for JSON.
3. App parses JSON without applying changes.
4. App validates `schemaVersion`.
5. App validates `app`.
6. App validates the `profiles` array.
7. App shows an Import Preview sheet.
8. User selects which valid profiles to import.
9. User chooses conflict handling.
10. User confirms import.
11. App saves imported profiles to `models.json`.

Import must not automatically start a server. Import must not stop or restart a running managed server. Import must not operate on external processes.

Selecting an imported profile after import should be an explicit option, not an automatic side effect by default. If the app is running a managed server, selecting an imported profile should follow the existing selected/running model and Restart-required policy.

Invalid entries should be rejected safely and shown in the preview with clear reasons.

## Validation Behavior

Required profile validation:

- `name` must not be empty.
- `modelID` must not be empty.
- `host` must be valid.
- `port` must be an integer in `1...65535`.
- Advanced launch numeric values must be positive where applicable.
- Probability values such as temperature, top-p, and min-p must be within `0...1`.
- `chatTemplateArgs` must be valid JSON if present and non-empty.
- `rawExtraArgs` should be treated as advanced user-controlled text.
- Unsupported `schemaVersion` should block import.

Unknown fields should be ignored by default, or preserved only if a future schema intentionally supports extension fields.

Validation should happen:

- during import preview,
- before saving imported profiles,
- and again before Start through the existing launch validation path.

## Conflict Handling

Conflicts can include:

- same profile name,
- same `modelID`,
- same `modelID + host + port`,
- duplicate entries inside the imported file,
- duplicate names created by rename behavior.

Recommended conflict options:

- `Skip`: do not import conflicting entries.
- `Rename`: import with a generated name such as `Imported - <name>`.
- `Replace`: replace an existing profile after explicit confirmation.

Replace should require a confirmation step. It should not change a running managed process until the user explicitly restarts through the existing lifecycle controls.

## Advanced Launch Options Handling

`advancedLaunchOptions` may be included in profile export/import because they are part of profile metadata.

Requirements:

- Validate all structured values before import.
- Treat empty values as omitted.
- Keep simple launch unchanged when imported advanced options are empty.
- Show raw extra args in preview.
- Warn that Advanced Launch Options are workload-dependent and may not improve performance.
- Run existing Start-time validation before launch.
- Do not start any process as part of import.

`rawExtraArgs` are not shell commands. They are intended as `mlx_lm.server` arguments, but they are still advanced user-controlled text and should be reviewed carefully.

## Local Path Handling

Executable paths are machine-specific. The default design should not export them.

Recommended policy:

- Do not export `mlx_lm.server executable path`.
- Do not export local model directories.
- Do not export Hugging Face cache paths.
- If future optional path export is added, keep it off by default.
- Show warnings for any imported local path field if a future schema supports it.
- Warn users not to paste personal paths into screenshots, docs, or issues.

Importing a profile should not imply that model files exist on the target Mac. The user remains responsible for local model files or Hugging Face cache.

## UI Design

Recommended controls:

- `Export Profiles` button near Model Profile management.
- `Import Profiles` button near Model Profile management.
- Import Preview sheet.
- Conflict handling control.
- Validation result list.
- Privacy warning before export.

v2.7.0 implements only `Export Profiles...` and a short always-visible privacy summary. Import UI remains future work.

Export summary should show:

- number of profiles,
- whether Advanced Launch Options are included,
- that secrets are not included,
- that executable path is not included,
- that model weights and cache are not included.

Import summary should show:

- number of valid profiles,
- number of skipped profiles,
- number of invalid profiles,
- conflict resolution result,
- whether an imported profile will be selected after import.

Keep the UI small and explicit. Do not turn import/export into an implicit model installer, hidden downloader, backend router, or first-run wizard. Future model download design, if added separately, must stay explicit and preserve performance, safety, and Direct Mode boundaries.

## Error Messages

Suggested error message style:

- `Unsupported profile export schema version.`
- `This file does not look like an MLX Server Manager profile export.`
- `Profile name is required.`
- `Model ID is required.`
- `Port must be between 1 and 65535.`
- `Chat Template Args must be valid JSON.`
- `Skipped duplicate profile: <name>.`
- `Replace requires confirmation.`
- `Import saved profile metadata only. No server was started.`

Messages should be clear enough for first-time users and precise enough for bug reports.

## Testing Plan

Test cases should cover:

- export creates valid JSON,
- export includes schema version and app name,
- export does not include API keys, tokens, local executable path, model weights, cache paths, or logs,
- export includes only selected profile metadata fields,
- export does not include adopted external server state, selected current target state, readiness results, PID, memory metrics, or runtime process state,
- export does not start, stop, restart, adopt, forget, readiness-check, or call `/v1/models`,
- import rejects unsupported schema versions,
- import rejects missing or invalid profiles,
- import preview shows valid and invalid entries,
- conflict handling supports skip, rename, and replace,
- duplicate entries inside the imported file are handled,
- Advanced Launch Options validate correctly,
- empty advanced values are omitted from future launch args,
- importing does not start `mlx_lm.server`,
- importing does not stop or restart a managed server,
- importing does not operate on external processes,
- imported profiles follow existing selected/running and Restart-required behavior,
- the app still does not call `/v1/chat/completions`,
- Swift code still does not use `pkill`, `killall`, or `pgrep`.

## Future Work

- Define a concrete Codable import/export schema type.
- Add Import Preview UI.
- Add export privacy summary.
- Add conflict resolution UI.
- Add JSON schema examples for shared profile templates.
- Add tests for import validation and conflict behavior.
- Consider optional path export only after privacy implications are reviewed.
- Consider template-only exports that omit notes and advanced args for easier public sharing.
