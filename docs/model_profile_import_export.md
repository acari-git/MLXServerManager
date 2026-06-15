# Model Profile Import / Export Design

## Overview

Model Profile Import / Export is a v2.6.0 docs-only design for backing up, moving, and sharing MLX Server Manager profile metadata safely.

The feature is not implemented yet. This document defines the intended file format, safety boundaries, UI behavior, validation policy, and test plan before implementation.

Import and export apply only to Model Profile metadata. They do not include model weights, Hugging Face cache, local runtime settings, secrets, or app binaries.

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

## Import Behavior

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

Keep the UI small and explicit. Do not turn import/export into a model installer, model downloader, backend router, or first-run wizard.

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
