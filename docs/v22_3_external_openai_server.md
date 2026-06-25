# v22.3.0 External OpenAI-Compatible Server Support

v22.3.0 strengthens the app-side workflow for OpenAI-compatible servers that are not launched by MLX Server Manager.

## Intended external targets

- vLLM
- Rapid-MLX
- LM Studio
- Ollama OpenAI-compatible endpoints
- Other local OpenAI-compatible `/v1` servers

## Implemented

- Added an External Server panel to the integrated right sidebar.
- Shows target type, base URL, model value, ownership, and lifecycle boundary.
- Adds copy actions for Base URL, Model, and API key placeholder.
- Adds Ready Check, Adopt, and Forget actions in one place.
- Explicitly states that Adopt only stores connection context.
- Explicitly states that external servers are not stopped, restarted, logged, or memory-monitored by the app.

## Boundary

External server support does not change Direct Mode. Clients still connect directly to the selected OpenAI-compatible endpoint. The app does not proxy inference requests, rewrite requests, route across multiple backends, or add Chat UI.

## Verification

- Debug build should pass.
- Test suite should pass.
- `git diff --check` should pass.
