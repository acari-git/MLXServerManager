# Public Release Checklist

Use this checklist before making the repository public or announcing a release more broadly.

## Public Release Safety Checklist

- Confirm the repository is clean.
- Confirm the latest release notes match the current code and docs.
- Confirm README describes the project clearly for a new visitor.
- Confirm Direct Mode is explicit.
- Confirm the app is not described as a Chat UI, inference proxy, or multi-backend wrapper.
- Confirm the current binary asset is identified correctly.
- Confirm docs-only releases are not described as new app binaries.
- Confirm the README screenshot is displayed and points to `screenshots/main-window.png`.

## Secrets Check

Run:

```sh
grep -R -nE "hf_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}" README.md docs MLXServerManager CONTRIBUTING.md SECURITY.md || true
```

Expected result: no real tokens.

## Tracked File Check

Run:

```sh
git ls-files settings.json models.json '*.safetensors' '*.gguf' '*.bin' '.env' HF_TOKEN models logs .venv '*.app' '*.zip' '*.dSYM'
```

Expected result: empty.

## Personal Path Check

Review README, docs, AGENTS.md, Swift files, CONTRIBUTING.md, and SECURITY.md for personal home-directory paths.

Expected result: no committed personal fixed paths.

## Binary Artifact Check

Confirm these are not committed:

- `.app`
- `.zip`
- `.dSYM`
- DerivedData
- build products
- logs
- model files
- Hugging Face cache

## README Check

- Project purpose is clear.
- Direct Mode is clear.
- Quick Start is short and usable.
- Current binary asset is clear.
- Docs-only releases are explained.
- Known limitations are visible.
- Benchmark findings are linked without overclaiming performance.
- Supported OpenAI-compatible client context is clear.

## Release Check

- Latest tag points to the intended commit.
- Release title and notes are accurate.
- Docs-only releases do not attach new binary assets.
- Binary release assets do not include runtime settings, model profiles, model files, secrets, logs, or build byproducts.
- Unsigned and non-notarized app caveats are visible.

## Screenshot Check

Before publishing screenshots:

- Confirm the README screenshot has been added.
- Do not show tokens, local secrets, or private paths.
- Do not show private model directories.
- Do not show private logs.
- Confirm the screenshot is safe for public repository display.
- Prefer sample model IDs and local loopback URLs.
- Confirm screenshots do not imply Chat UI, proxy behavior, or multi-backend support.

## GitHub Repo Settings Check

- Repository description is accurate.
- Topics are set.
- Security policy is visible.
- Issues are enabled only if maintainers are ready to triage them.
- Private vulnerability reporting is enabled if available.
- Release assets are reviewed before public announcement.

Suggested repository description:

```text
macOS GUI for managing pure mlx_lm.server on Apple Silicon in Direct Mode.
```

Recommended GitHub topics:

- `mlx`
- `mlx-lm`
- `apple-silicon`
- `macos`
- `local-llm`
- `openai-compatible`
- `llm-server`
- `swiftui`
- `agent-tools`
- `hermes-agent`

## Codex for OSS Readiness Notes

Codex or other AI assistance may be used to prepare docs, code, tests, and release notes, but maintainers should review all changes before publishing.

Before accepting AI-assisted changes, confirm:

- No secret or path leakage.
- No binary artifacts.
- No model files.
- No incorrect performance claims.
- No expansion beyond Direct Mode.
- No inference proxy or Chat UI scope.
