# Benchmark Findings

This document records benchmark-informed product direction for MLX Server Manager after local comparison work with `mlx_lm.server` and oMLX.

## Scope

These notes are directional. They are not a universal performance claim and they do not change the v1.0 product boundary.

MLX Server Manager remains a Direct Mode app:

```text
OpenAI-compatible client -> mlx_lm.server -> MLX model
```

The app manages the local `mlx_lm.server` process, shows state, and copies OpenAI-compatible connection settings. It is not an inference proxy, not a Chat UI, and not a multi-backend wrapper.

## What Was Compared

Model:

- `unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit`

Endpoints:

- oMLX: `http://127.0.0.1:8000/v1`
- MLXServerManager-managed pure `mlx_lm.server`: `http://127.0.0.1:8080/v1`

## Workloads Measured

- Short single-request style workloads.
- Continuous `long_run` request sequences.
- `long_context` prompts.
- `prompt_cache_style` repeated-context style prompts.
- Streaming time-to-first-token style checks.

## Key Findings

- Performance depends on workload.
- MLX Server Manager should not claim that pure `mlx_lm.server` is always faster than oMLX.
- In short and continuous single-request style workloads, oMLX was slightly better in some cases.
- In `long_context`, pure `mlx_lm.server` was clearly better in the measured run:
  - oMLX average latency: 4.844 seconds
  - `mlx_lm.server` average latency: 3.141 seconds
- In `prompt_cache_style`, pure `mlx_lm.server` was better in the measured run:
  - oMLX average latency: 5.074 seconds
  - `mlx_lm.server` average latency: 4.503 seconds
- Streaming TTFT favored pure `mlx_lm.server` strongly in the measured run:
  - oMLX: about 0.872 seconds at 1k and about 2.3-2.4 seconds at 4k-16k
  - `mlx_lm.server`: about 0.14-0.15 seconds at 1k-16k
- `long_run` stability was good for both systems:
  - 100 requests
  - 100% success
  - first10 and last10 latency degradation was minimal
- Earlier advanced launch option tests did not show clear improvement from aggressive tuning.

## Interpretation

The benchmark results support Direct Mode for use cases that care about long context, repeated context, and fast streaming first token behavior. This is especially relevant for OpenAI-compatible clients such as Hermes Agent when they reuse context or benefit from low TTFT.

The results do not justify positioning MLX Server Manager as a universally faster oMLX replacement. oMLX can be competitive or slightly better for some short, continuous single-request workloads.

## Product Direction

- Keep the default launch path simple.
- Keep Direct Mode as the primary architecture.
- Keep MLX Server Manager out of the inference request path.
- Continue presenting the app as a manager for `mlx_lm.server`, not as a backend abstraction layer.
- Treat Advanced Launch Options as future optional user-tunable controls.
- Do not enable aggressive launch tuning by default.
- Avoid Proxy mode, Chat UI, and request routing in the stable default direction.

Future optional Advanced Launch Options may include:

- Raw extra launch arguments.
- Chat template arguments.
- Prompt cache related options.
- Prefill, decode, and concurrency related options.
- Command preview.
- Validation before launch.

## What This Does Not Prove

- It does not prove that pure `mlx_lm.server` is always faster than oMLX.
- It does not prove that the same result applies to every model.
- It does not prove that the same result applies to every prompt shape.
- It does not prove that aggressive launch options should be enabled by default.
- It does not justify adding a proxy, Chat UI, or request router to MLX Server Manager.

## Future Benchmark Work

- Repeat the same workload matrix across more models.
- Include more prompt lengths and repeated-context patterns.
- Compare cold start and warm start behavior separately.
- Track TTFT, total latency, throughput, memory, and failure rate together.
- Re-test optional Advanced Launch Options only as user-tunable experiments.
- Document command lines and environment assumptions for reproducibility.
