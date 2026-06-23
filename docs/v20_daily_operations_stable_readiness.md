# v20 Daily Operations Stable Readiness

v20.0.0 aligns the integrated GUI with implemented behavior.

## Completed

- Removed unavailable extra connection-port UI from the integrated model table, settings panel, safety rows, and footer.
- Kept Hermes Agent guidance on Direct Mode connection values.
- Replaced auto-unload wording with manual-stop wording.
- Replaced CPU and GPU/Metal usage wording with unsampled labels.
- Renamed model memory wording to process memory.
- Renamed last-use wording to last-check semantics.
- Added Start guardrail state for missing selection, missing executable, missing model path, and unavailable server port.
- Routed recovery actions through the integrated workspace entry point.
- Updated tests to check implemented safety rows only.

## Remaining limitations

- CPU and GPU/Metal are not sampled metrics.
- Automatic unload remains intentionally unimplemented.
- Model memory is process-level memory.
- Last-check is not usage telemetry.

## Direct Mode boundary

The release keeps the client-to-mlx_lm.server path and does not add Chat UI, request inspection, response rewriting, credential storage, model file deletion, cache cleanup, telemetry, automatic download, automatic start, automatic unload scheduling, LAN Web UI, or App Intents.

## Manual checklist

- Confirm removed unavailable connection-port UI is not visible.
- Confirm Hermes values are Direct Mode values.
- Confirm CPU and GPU/Metal are unsampled.
- Confirm stop mode says manual stop only.
- Confirm process memory wording is used.
- Confirm Start is blocked by explicit blocking issues.
- Confirm Recovery actions require user action.
