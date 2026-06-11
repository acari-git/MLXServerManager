# Ready Check Contract

## Scope

Defines readiness detection for Direct Mode.

## Endpoint

The default readiness probe should use an OpenAI-compatible endpoint, such as:

```text
GET http://<host>:<port>/v1/models
```

## States

- Not started
- Checking
- Ready
- Timed out
- Failed

## Required Behavior

- Start probing after process launch.
- Use bounded retry and timeout behavior.
- Treat a valid OpenAI-compatible response as ready.
- Treat connection refusal during startup as not ready yet, until timeout.
- Preserve the last failure reason for diagnostics.

## Constraints

Ready checks must not send inference requests and must not load extra model state.

