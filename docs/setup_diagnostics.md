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
- invalid port
- busy port from an external process
- available port
- managed server ready through `/v1/models`
- settings storage path display
- no app-side inference request

### v0.2 Manual Checklist

Use this checklist for the implemented v0.2 Setup Diagnostics flow.

1. Start the app with no managed server running.
2. Click `Run Diagnostics`.
3. Confirm `Port availability` is `pass` when the selected host and port are free.
4. Confirm `Ready check` is `warning` while the server is stopped.
5. Confirm Diagnostics UI shows the same results as Logs.
6. Set a valid `mlx_lm.server executable path`.
7. Click `Run Diagnostics`.
8. Confirm executable path `configured`, `exists`, and `executable` checks are `pass`.
9. Enter an executable path that does not exist.
10. Click `Run Diagnostics`.
11. Confirm executable path `exists` and `executable` checks are `fail`.
12. Clear the executable path field.
13. Click `Run Diagnostics`.
14. Confirm executable path `configured`, `exists`, and `executable` checks are `fail`.
15. Restore the valid executable path.
16. Click `Run Diagnostics`.
17. Confirm the summary returns to `0 failure(s)` when all required settings are valid.
18. Click `Start`.
19. Confirm the managed server reaches Ready through `/v1/models`.
20. Click `Run Diagnostics` while the managed server is running.
21. Confirm `Port availability` is `warning`.
22. Confirm the message says `Port is busy because the managed server is running.`
23. Confirm the detail includes the managed pid.
24. Confirm `Ready check` is `pass`.
25. Confirm Diagnostics UI and Logs both show the improved port message.
26. Click `Restart`.
27. Confirm Restart still stops the managed process, releases the port, starts a new pid, and reaches Ready.
28. Click `Stop`.
29. Confirm Stop still releases the port.
30. Confirm diagnostics do not call `/v1/chat/completions`.
31. Confirm diagnostics do not run model inference.
32. Confirm diagnostics do not launch `mlx_lm.server`.
33. Confirm diagnostics do not stop external processes.
