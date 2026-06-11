# Architecture

## v0.1 Architecture

Direct Mode keeps inference traffic outside the app:

```text
External OpenAI-compatible client -> mlx_lm.server
```

The app controls and observes the server:

```text
SwiftUI View -> View Model -> Services -> mlx_lm.server process
```

## Suggested Modules

- `Views`: SwiftUI rendering and user actions.
- `ViewModels`: UI state, commands, validation, and presentation logic.
- `ServerProcessService`: owns `Process` launch, termination, stdout, and stderr.
- `PortCheckService`: checks whether the configured port is available.
- `ReadyCheckService`: checks server readiness through HTTP.
- `MemoryMonitorService`: reads memory usage for the managed process.
- `ConnectionConfigService`: formats copyable OpenAI-compatible settings.
- `AppConfiguration`: stores user-editable launch and connection settings.

## Dependency Rule

SwiftUI views must not directly import or use process-launching primitives. Views should send intents to view models. View models should call services through protocols where useful.

## Future Extension Points

- App Intents can call the same view-model or service layer used by the UI.
- LAN Web UI can observe the same app state through a separate adapter.
- Proxy mode can be added as a separate execution mode, not as a change to Direct Mode.
- Automatic unload can subscribe to readiness, request, and memory signals without changing Start / Stop contracts.

## Path Policy

Do not hardcode user-specific absolute paths. Use user-selected paths, app settings, environment lookup, or platform APIs such as the home directory when a default is needed.

