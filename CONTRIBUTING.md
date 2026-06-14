# Contributing

Thank you for considering a contribution to MLX Server Manager.

This project is intentionally narrow: it is a macOS GUI for managing pure `mlx_lm.server` in Direct Mode.

```text
OpenAI-compatible client -> mlx_lm.server -> MLX model
```

The app should remain outside the inference request path.

## Project Scope

MLX Server Manager may manage:

- Starting `mlx_lm.server`.
- Stopping the app-managed process.
- Restarting the app-managed process.
- Ready checks.
- Port conflict checks.
- Logs.
- Memory display.
- Model profiles.
- OpenAI-compatible connection setting copy actions.
- Setup diagnostics.

## Direct Mode Boundary

Do not route client inference requests through MLX Server Manager.

The app should not become:

- An inference proxy.
- A Chat UI.
- A model downloader.
- A model deletion tool.
- A multi-backend wrapper.
- A replacement for `mlx-lm` setup.

## Welcome Contributions

Good contribution areas include:

- Documentation improvements.
- UI clarity.
- Diagnostics improvements.
- Launch configuration safety.
- Benchmark methodology.
- OpenAI-compatible client setup notes.
- Safer validation and error messages.
- Tests for services where practical.

## Out of Scope

Please do not propose changes that add:

- Inference proxy behavior.
- Chat UI.
- Model downloader behavior.
- Model deletion.
- Hugging Face cache deletion.
- Multi-backend wrapper behavior.
- Automatic tuning defaults without benchmark evidence.
- Telemetry, analytics, crash reporting, or external log sending.

## Development Safety Rules

- Keep SwiftUI views focused on rendering state and sending user intents.
- Keep process launch, termination, port checks, polling, and pipe handling in services or controllers.
- Stop and Restart must target only the app-managed process.
- Do not use broad process-kill patterns.
- Do not hardcode user-specific absolute paths.
- Keep Direct Mode intact.

## Repository Hygiene

Do not commit:

- `settings.json`
- `models.json`
- `.env`
- `HF_TOKEN`
- model files
- model directories
- Hugging Face cache
- logs
- `.venv`
- `.app`
- `.zip`
- `.dSYM`
- DerivedData or other build artifacts

## Basic Checks

Before asking for review, run:

```sh
git status --short --untracked-files=all
git diff --check
git ls-files settings.json models.json '*.safetensors' '*.gguf' '*.bin' '.env' HF_TOKEN models logs .venv '*.app' '*.zip' '*.dSYM'
grep -R -n "pkill\\|killall\\|pgrep" MLXServerManager || true
grep -R -n "/v1/chat/completions" MLXServerManager || true
```

`/v1/chat/completions` may appear only in copy-helper UI or documentation for external clients. The app itself should not send inference requests.

Also review README, docs, AGENTS.md, and Swift files for personal home-directory paths before committing.

## Proposing Changes

For larger changes, open an issue or discussion first and describe:

- The user problem.
- The proposed behavior.
- How it preserves Direct Mode.
- What files or services are affected.
- Manual test steps.
- Any safety or repository hygiene risks.

Keep pull requests focused. Prefer small, reviewable changes over broad rewrites.

## Human-Reviewed AI-Assisted Workflow

AI assistance is acceptable for planning, implementation, documentation, and release preparation, but generated changes must be human reviewed.

Review AI-assisted changes for:

- Scope creep.
- Incorrect product claims.
- Secret or local path leakage.
- Generated binary artifacts.
- Any change that would put the app in the inference path.
