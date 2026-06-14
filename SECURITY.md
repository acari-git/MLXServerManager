# Security Policy

## Supported Versions

Security review is best effort and focused on the latest release.

Older releases may not receive backported fixes unless the issue is severe and practical to address.

## Reporting a Security Issue

If GitHub private vulnerability reporting is available, please use it.

If private reporting is not available, open a minimal public issue that does not include secrets, tokens, local private paths, private logs, or model files. State that you have a security concern and provide enough high-level context for maintainers to follow up.

Do not attach logs that contain secrets.

## Local-Only Assumptions

MLX Server Manager is designed for local use. The recommended host is `127.0.0.1`.

Do not expose `mlx_lm.server` publicly without understanding the network and security implications. OpenAI-compatible endpoints may be callable by any client that can reach the host and port.

## Unsigned App Warning

Current release assets are unsigned local-use macOS app builds and are not notarized.

macOS Gatekeeper may warn when opening the app, including warnings that the app is damaged and cannot be opened. Verify the Release asset source, zip contents, and checksum before deciding whether to remove quarantine from an extracted app.

## Secrets and Tokens

The app should not handle or store real API secrets for local `mlx_lm.server` use. The default API key value is a placeholder for OpenAI-compatible client configuration.

Do not commit:

- `.env`
- `HF_TOKEN`
- runtime settings
- model profiles
- logs containing secrets
- model files
- Hugging Face cache

## Repository Artifact Safety

Do not commit:

- `settings.json`
- `models.json`
- `.app`
- `.zip`
- `.dSYM`
- DerivedData
- build artifacts
- model files
- model directories
- logs
- `.venv`

## Process Safety

Stop and Restart should only affect processes started and held by MLX Server Manager.

The app must not stop external `mlx_lm.server` processes.

The app must not rely on broad process-name matching for termination.

## Inference Boundary

MLX Server Manager is not in the inference request path.

```text
OpenAI-compatible client -> mlx_lm.server -> MLX model
```

The app should not become an inference proxy, Chat UI, or multi-backend wrapper.
