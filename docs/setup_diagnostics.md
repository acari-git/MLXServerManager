# Setup Diagnostics

Setup Diagnostics is the v0.2 feature that checks whether MLX Server Manager is ready to operate the configured `mlx_lm.server` in Direct Mode.

Diagnostics should make setup problems visible before Start while preserving the v0.1 runtime boundaries.

## Non-Goals

- No proxy.
- No Chat UI.
- No app-side `/v1/chat/completions` request.
- No inference request.
- No external process termination.
- No alternate backend checks for LM Studio, Ollama, llama.cpp, or other servers.

## Diagnostic Items

### Executable Path

Check the configured `mlx_lm.server executable path` from app settings.

Results:

- `fail`: path is empty.
- `fail`: path does not exist.
- `fail`: path exists but is not a file.
- `fail`: path exists but is not executable.
- `pass`: path exists and is executable.

The diagnostic should not assume a user-specific absolute path. The user must provide the path through the app UI.

### Safe Executable Probe

After the executable path passes file checks, run a safe probe command such as:

```text
<mlx_lm.server executable path> --help
```

The probe should be bounded by a short timeout. It should capture stdout and stderr, but Logs should truncate long output.

Results:

- `pass`: process launches and exits normally or prints recognizable help output.
- `warning`: process launches but exits with a non-zero status while still producing help-like output.
- `fail`: process cannot launch.
- `fail`: process times out.

The probe must not start a server and must not load a model.

### Host and Port

Validate the selected model host and port.

Results:

- `fail`: host is empty.
- `warning`: host is not `127.0.0.1` for v0.2 local-first use.
- `fail`: port is outside the valid TCP port range.
- `pass`: host and port are syntactically valid.

The UI should continue to recommend `127.0.0.1` for local use. The app should not encourage exposing `mlx_lm.server` directly to the internet.

### Port Availability

Use the existing Port Check behavior.

Results:

- `pass`: selected host and port are available.
- `warning`: port is busy before Start.
- `fail`: port check cannot be completed.

If the port is busy and no app-managed process is attached, the result should explain that an external process may already be using the port. Diagnostics must not stop that process.

### Required Start Settings

Confirm the minimum settings needed for Start:

- executable path
- model ID
- host
- port

Results:

- `pass`: required settings are present.
- `fail`: one or more required settings are missing.

### Ready Check After Start

When a managed process is running, diagnostics may reuse the existing Ready Check.

The only readiness endpoint is:

```text
GET /v1/models
```

Results:

- `pass`: `/v1/models` returns HTTP 200 and a response body.
- `warning`: server is running but not ready.
- `fail`: request fails.
- `not run`: no managed process is running.

Diagnostics must not call `/v1/chat/completions`.

### Configuration Storage

Show the resolved Application Support directory used by the app, and show the expected local files:

- `settings.json`
- `models.json`

Results:

- `pass`: storage location can be resolved.
- `warning`: files do not exist yet but can be created by saving settings.
- `fail`: storage location cannot be resolved or accessed.

These files are local runtime state and must not be committed.

## Result Model Direction

Use a structured diagnostics result instead of plain strings where practical.

Suggested fields:

- `id`
- `title`
- `status`
- `message`
- `details`
- `timestamp`

Suggested statuses:

- `pass`
- `warning`
- `fail`
- `notRun`

## Service Direction

Add a dedicated service, for example `SetupDiagnostics`, that coordinates existing services:

- `SettingsStore`
- `PortChecker`
- `ReadyChecker`

Process launching for the safe executable probe should stay outside SwiftUI views.

## Logging

Each diagnostics run should write concise Logs entries:

- start of diagnostics
- executable path result
- safe probe result
- host/port validation result
- port availability result
- required settings result
- ready result when applicable
- storage location result
- final summary

Logs must avoid secrets and should truncate long command output.

## Manual Verification

Manual tests should cover:

- empty executable path
- missing executable path
- non-executable file
- valid executable path
- safe help probe success
- invalid port
- busy port from an external process
- available port
- managed server ready through `/v1/models`
- settings storage path display
- no app-side inference request
