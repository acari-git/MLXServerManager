# v18 Model Operations Safety Readiness

This document records the readiness pass for the v18.0.0 Model Operations Safety Stable release.

## Goal

v18.0.0 keeps the v17 integrated GUI and adds model-operation safety checks around start, profile editing, ports, model identity, duplicate profiles, and failed-start recovery.

## Completed safety surfaces

### Integrated Safety panel

The right-side selected model panel now includes a Safety section with:

- executable readiness
- model identity validation
- server port safety
- proxy port safety
- duplicate profile warning
- runtime editing safety
- failed-start recovery summary
- copyable safety summary

### Port conflict safety

The selected server port and informational proxy port are checked through `PortChecker` and shown as:

- Available
- Busy
- Invalid
- Check failed

Proxy display remains informational. Proxy mode is not implemented.

### Model path / HF ID validation

Selected model identity now reports:

- existing local path
- missing local path
- valid-looking Hugging Face owner/model ID
- full Hugging Face URL needing review
- unrecognized model identity needing review

### Duplicate profile warnings

Duplicate checks include:

- display name
- model ID
- host + server port endpoint

Warnings appear in the safety section and model table pills.

### Runtime editing safety

The integrated right-side Edit action now exposes runtime editing safety guidance. Runtime-critical fields remain guarded through the existing editor behavior and runtime lock messaging.

### Failed start recovery

Recovery guidance is derived from runtime failure state and classifies common failure categories:

- executable problems
- model path problems
- port problems
- permission problems
- readiness/timeout problems
- unknown failures requiring log review

### Safety tests

`ModelOperationsSafetyTests` covers:

- duplicate endpoint warning behavior
- safety row presence
- copyable safety summary presence

## Known limitations

- CPU and GPU/Metal usage remain conservative display labels, not sampled metrics.
- Proxy port remains informational only.
- Auto-unload does not include a runtime scheduler.
- Profile editor still uses sheet-based editing rather than inline field editing.

## Safety boundaries

v18.0.0 preserves Direct Mode:

```text
client -> mlx_lm.server
```

The release does not add:

- Chat UI
- inference proxy
- proxy mode
- request inspection
- response rewriting
- credential storage
- model file deletion
- Hugging Face cache cleanup
- telemetry
- automatic download
- automatic start
- LAN Web UI
- App Intents

## Manual verification checklist

- Open the app and confirm the integrated workspace appears by default.
- Select a model and review the Safety section.
- Confirm executable, model identity, server port, proxy port, duplicate, runtime editing, and recovery rows are visible.
- Copy the safety summary.
- Create or import duplicate profiles and confirm duplicate warnings appear.
- Confirm model validation distinguishes local path / HF ID / review-needed values.
- Confirm port checks show Available or Busy where appropriate.
- Confirm Edit/Delete remain explicit user actions.
- Confirm failed start states produce recovery guidance.
