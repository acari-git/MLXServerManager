# Hermes Agent and OpenAI-Compatible Client Connection

## Overview

This guide explains how to use a pure `mlx_lm.server` process managed by MLX Server Manager from Hermes Agent or another OpenAI-compatible client.

MLX Server Manager starts, stops, restarts, checks, and displays local server state. It does not proxy inference requests.

## What This Guide Is For

Use this guide when you want an OpenAI-compatible client to connect to the local endpoint started by MLX Server Manager.

The same connection values usually apply to Hermes Agent, custom scripts, and other clients that accept an OpenAI-compatible base URL, model ID, and API key placeholder.

Hermes Agent-specific provider names, config file locations, or extra headers can vary by setup. Use the values below according to your Hermes Agent configuration.

## Direct Mode Boundary

The inference path stays direct:

```text
Hermes Agent or OpenAI-compatible client -> mlx_lm.server -> MLX model
```

MLX Server Manager is not in the inference request path. It manages the local `mlx_lm.server` process and provides connection settings for clients.

## Requirements

- A working local `mlx-lm` environment.
- A valid `mlx_lm.server` executable path configured in MLX Server Manager.
- A model profile configured in MLX Server Manager.
- A local OpenAI-compatible client such as Hermes Agent.
- Local access to the selected host and port, usually `127.0.0.1:8080`.

## Step 1: Start mlx_lm.server From MLX Server Manager

1. Open MLX Server Manager.
2. Confirm the selected Model Profile.
3. Confirm the `mlx_lm.server executable path` in Settings.
4. Run Setup Diagnostics.
5. Press Start.
6. Wait for the status to become Ready.

For a baseline setup, leave Advanced Launch Options empty first. Add advanced options only after the simple launch path works.

## Step 2: Confirm Readiness With /v1/models

MLX Server Manager uses `/v1/models` for readiness checks.

You can also verify from a terminal:

```sh
curl http://127.0.0.1:8080/v1/models
```

If this fails, fix readiness before configuring a client.

## Step 3: Copy OpenAI-Compatible Connection Settings

In MLX Server Manager, use Connection Settings to copy:

- Base URL
- Model ID
- OpenAI-compatible JSON config
- `curl /v1/models`
- `curl /v1/chat/completions`

The copied chat-completions command is a client-side test example. MLX Server Manager itself does not execute `/v1/chat/completions`.

## Step 4: Configure Hermes Agent or Another OpenAI-Compatible Client

Configure your client as an OpenAI-compatible endpoint.

Depending on your Hermes Agent setup, this may involve a provider entry, local model entry, environment variables, or an app setting. Use the client-specific location that accepts these values:

- Base URL
- Model ID
- API key placeholder

If the client requires an API key, use a dummy local value such as `not-required-local`. Do not use a real hosted API key for this local endpoint.

## Example Connection Values

Base URL:

```text
http://127.0.0.1:8080/v1
```

Model:

```text
unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit
```

API Key:

```text
not-required-local
```

## Example curl /v1/models

```sh
curl http://127.0.0.1:8080/v1/models
```

## Example curl /v1/chat/completions

```sh
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer not-required-local" \
  -d '{
    "model": "unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit",
    "messages": [
      {
        "role": "user",
        "content": "Say hello in one sentence."
      }
    ],
    "chat_template_kwargs": {
      "enable_thinking": false
    }
  }'
```

This curl command is a connection test example for a client or terminal. MLX Server Manager does not run this request.

## Qwen Thinking Note

For Qwen-style models, some clients may need template options to control thinking behavior. If your request format supports it, you can include:

```json
{
  "chat_template_kwargs": {
    "enable_thinking": false
  }
}
```

Whether this is needed depends on the model, server behavior, and client request format.

## Troubleshooting

### /v1/models Fails

- Confirm MLX Server Manager shows Ready.
- Confirm the client uses the same host and port.
- Run Port Check in MLX Server Manager.
- Confirm no other process is using the selected port.

### Connection Refused

- The server may not be running.
- The client may be using the wrong port.
- The host may differ from the selected model profile.

### Model Not Found

- Confirm the client model name exactly matches the MLX Server Manager Model Profile `modelID`.
- Confirm the selected profile is the one currently running.
- If Restart required is shown, restart the managed server before testing the selected model.

### 401 or API Key Error

Local `mlx_lm.server` does not require a hosted API key, but some clients require the field to be non-empty. Use a dummy value such as:

```text
not-required-local
```

Do not put real API keys in local dummy config.

### Timeout or Slow First Request

- The model may still be loading.
- The first request can be slower than later requests.
- Memory pressure can slow down local inference.
- Check MLX Server Manager Logs and Memory display.

### Advanced Launch Options

- Leave Advanced Launch Options empty for the first successful baseline.
- Tune only after `/v1/models` and a simple client request work.
- Advanced options are workload-dependent and may not improve performance.
- Copy Preview can help review the exact launch command before saving or starting.

## Security Notes

- Use `127.0.0.1` by default.
- Avoid exposing the local server to LAN or WAN unless you understand the risks.
- Treat `mlx_lm.server` as local development infrastructure.
- Do not put real API keys in local dummy config.
- Do not commit local settings files such as `settings.json` or `models.json`.
- Do not commit model files or Hugging Face cache contents.

## Non-Goals

- MLX Server Manager is not a Hermes Agent plugin.
- MLX Server Manager is not a proxy.
- MLX Server Manager is not a chat UI.
- MLX Server Manager is not a multi-backend router.
- MLX Server Manager is not a model downloader.
