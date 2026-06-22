# v13 Direct Mode Safety Review

This review captures the safety and scope boundaries checked before the v13.0.0 Runtime Diagnostics Stable release.

## Direct Mode invariant

MLX Server Manager remains a Direct Mode manager:

```text
client -> mlx_lm.server
```

The app may help users configure, start, stop, diagnose, and benchmark a local `mlx_lm.server` process, but it must not become an inference proxy.

## Confirmed out of scope for v13.0.0

- Chat UI
- Inference proxy
- Request or response rewriting
- Request or response inspection
- Multi-backend routing
- Hugging Face token persistence
- Model file deletion
- Hugging Face cache cleanup
- Telemetry
- Automatic download
- Automatic server start
- LAN Web UI
- App Intents

## Runtime diagnostics boundaries

The v12.x diagnostics work is read-only or explicitly user-triggered:

- Ready Check is explicit.
- Speed Test is explicit.
- Benchmark history is session-scoped and local.
- Runtime timeline is session-scoped and local.
- Launch command preview is read-only unless copied.
- Benchmark summary copy is user-triggered.

## File safety

Profile deletion must remain metadata-only. It must not delete model files, downloaded repositories, or Hugging Face caches.

## Credential safety

Hugging Face search and download guidance must not store or manage user tokens. If a model requires authentication, the app should guide the user to resolve access outside persistent app-managed credentials.

## v14 GUI review carry-over

The v14.0.0 GUI optimization phase should preserve all boundaries above while improving information architecture, visual density, and Japanese/English language switching.
