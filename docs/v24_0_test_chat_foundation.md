# v24.0.0 Test Chat Foundation

v24.0.0 adds a small Test Chat panel for direct endpoint verification while keeping the runtime logs visible.

## Changes

- Split the integrated workspace bottom panel into two panes:
  - left: Test Chat
  - right: Logs
- Added a single-turn Test Chat client for the selected OpenAI-compatible endpoint.
- Sends one user message directly to `/v1/chat/completions` with `stream: false`.
- Displays response text, HTTP status, elapsed time, and request status.
- Adds Send, Cancel, Clear, and Copy response actions.
- Writes Test Chat request, response, cancellation, and failure events to the existing log stream.
- Updated the integrated footer version label to 24.0.0.

## Boundaries

This is a connection test client, not a full chat app.

It does not add:

- conversation history persistence
- multi-session chat
- prompt rewriting
- system prompt insertion
- routing across backends
- RAG
- agent actions
- inference proxying

## Direct Mode

Requests are sent directly from the app to the selected OpenAI-compatible endpoint. The app does not rewrite prompts and does not proxy client traffic between other clients and `mlx_lm.server`.

## Verification

- Debug build passed with `xcodebuild -project MLXServerManager.xcodeproj -scheme MLXServerManager -configuration Debug CODE_SIGNING_ALLOWED=NO build`.
