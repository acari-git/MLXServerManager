# v19 Daily Operations Recovery Readiness

This document records the readiness pass for the v19.0.0 Daily Operations Recovery Stable release.

## Goal

v19.0.0 keeps the integrated GUI and turns safety signals into actionable recovery guidance.

## Completed recovery surfaces

### Failure classification

`RecoveryIssueCategory` classifies common runtime and download failures:

- executable missing
- executable not executable
- model path missing
- port busy
- permission denied
- readiness timeout
- process exited early
- HF CLI missing
- HF access / gated model
- network error
- destination error
- unknown issue

### Recovery action model

`RecoveryAction` maps each issue category to primary and secondary next actions. Actions remain explicit and user-triggered.

### Integrated Recovery panel

`IntegratedRecoveryPanelView` shows:

- current issue
- severity badge
- issue detail
- related important log
- primary and secondary recovery actions
- Refresh Safety
- Copy Troubleshooting

### Runtime recovery wiring

Runtime state now feeds recovery issues for:

- generic runtime errors
- port busy
- port check failure
- readiness failure

### Download recovery wiring

The latest failed Hugging Face download can become the active recovery issue and expose download-oriented recovery actions.

### Logs to troubleshooting summary

The troubleshooting summary includes:

- runtime state
- target base URL
- selected model
- active recovery issue
- safety summary
- recent logs

### Model availability refresh

The integrated Recovery panel can manually refresh safety state. The refresh remains explicit and user-triggered.

### Recovery UX polish

The panel includes severity labels, primary action emphasis, secondary actions, and an OK/no-recovery empty state.

### Tests

`ModelOperationsSafetyTests` now covers:

- duplicate endpoint warning behavior
- safety row presence
- copyable safety summary presence
- default no-recovery state
- troubleshooting summary content

## Known limitations

- Recovery action navigation actions log intent when they cannot directly switch local view state.
- CPU and GPU/Metal usage remain conservative display labels, not sampled metrics.
- Proxy port remains informational only.
- Auto-unload does not include a runtime scheduler.
- Recovery classification is string-based and conservative.

## Safety boundaries

v19.0.0 preserves Direct Mode:

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

## Manual checklist

- Trigger or simulate a port busy state and confirm Recovery shows Port Busy.
- Confirm Copy Troubleshooting includes runtime, target, selected model, recovery, safety, and logs.
- Confirm failed download appears as a recovery issue when a queue entry fails.
- Confirm Refresh Safety is explicit and does not auto-start or auto-download.
- Confirm Edit Profile remains explicit.
- Confirm Direct Mode copy values are unchanged.
