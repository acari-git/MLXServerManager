# Memory Monitor Contract

## Scope

Defines memory usage reporting for the managed `mlx_lm.server` process.

## Inputs

- Managed process identifier
- Polling interval

## Outputs

- Current memory usage
- Peak memory usage when available
- Monitor status
- Last error when unavailable

## Required Behavior

- Monitor only the managed server process in v0.1.
- Handle process exit without crashing.
- Avoid high-frequency polling that could interfere with inference.
- Report unavailable data explicitly rather than showing misleading zeros.

## Future Extension

Later versions may add system-wide memory pressure, GPU/ANE-specific metrics if available, and automatic unload triggers.

