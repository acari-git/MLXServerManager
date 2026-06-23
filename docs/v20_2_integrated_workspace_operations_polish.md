# v20.2.0 Integrated Workspace Operations Polish

Status: Completed.

## Summary

v20.2.0 is an app-code release that continues the integrated workspace polish work after the v20.1.0 documentation alignment release.

The release improves the model list, local system information, resource panels, and direct model lifecycle controls while preserving the Direct Mode boundary.

## Scope

- Removed the Help menu from the integrated workspace sidebar.
- Expanded sidebar row hit targets beyond label text.
- Reworked the model list columns for daily operation:
  - model name / usage
  - size
  - status
  - server port
  - process memory
  - auto unload
  - reasoning
- Added model size display based on local weight file totals.
- Added sortable model list headers with ascending / descending toggles.
- Added status-driven load / unload controls:
  - Ready
  - Load on hover
  - Loading
  - Loaded
  - Unload on hover
  - Unloading
- Added fixed-size rounded status controls with green load / loaded states and red unload hover state.
- Removed central Start / Stop / Restart / Speed Test action buttons from the integrated model list workflow.
- Added per-model reasoning toggles to the model list.
- Added auto-unload monitoring so enabled profiles unload after the configured elapsed time.
- Added Activity Monitor-style memory and CPU history panels.
- Removed GPU usage display because stable Activity Monitor-equivalent GPU utilization is not available through a simple public API.
- Added local Mac hardware summary under SYSTEM:
  - model identifier
  - chip / CPU brand string
  - active core count
  - memory capacity
  - storage used / total
- Removed explanatory helper text from the memory, CPU, and uptime cards where it duplicated visible state.

## Auto-Unload Behavior

Auto-unload is now functional rather than display-only.

When a model is loaded, the app checks once per second whether all of the following are true:

- the running model has auto-unload enabled;
- the configured minute threshold has elapsed since the managed server was started;
- the model is not currently loading or unloading.

When those conditions are met, the app logs the auto-unload event and calls the same managed stop path used by manual unload.

## Direct Mode Boundary

This release does not add inference proxying, request rewriting, a Chat UI, multi-backend routing, credential storage, model deletion, or cache cleanup.

Clients still connect directly to `mlx_lm.server`.

## Validation

- Debug build passed.
- `git diff --check` passed.
