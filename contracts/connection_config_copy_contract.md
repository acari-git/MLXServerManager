# Connection Config Copy Contract

## Scope

Defines the content copied for external OpenAI-compatible clients.

## Inputs

- Host
- Port
- Scheme
- API base path
- Model identifier
- Optional API key placeholder

## Required Output

The copied text should include:

- Base URL
- Model identifier
- API key placeholder when useful

Example:

```text
Base URL: http://127.0.0.1:8000/v1
Model: <model-id>
API Key: not required locally, use a placeholder if your client requires one
```

## Required Behavior

- Do not include secrets.
- Do not include user-specific absolute paths.
- Keep output suitable for OpenAI-compatible clients.
- Keep the copied config independent of any proxy, because v0.1 Direct Mode does not use one.

