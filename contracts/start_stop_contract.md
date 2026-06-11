# Start / Stop Contract

## Scope

Defines v0.1 behavior for starting, stopping, and restarting the managed `mlx_lm.server` process.

## Preconditions

- Launch configuration is valid.
- Configured command is available.
- Configured port is not occupied, unless the occupied process is the same managed process.
- Required model path or model identifier is available according to the selected launch mode.

## Start

When Start is requested:

1. Validate configuration.
2. Run port conflict check.
3. Launch `mlx_lm.server` as a child process managed by the app.
4. Capture stdout and stderr.
5. Transition to Starting.
6. Begin ready checks.

Start must not create a proxy or alter the inference route.

## Stop

When Stop is requested:

1. Send a graceful termination signal to the managed process.
2. Wait for process exit within a bounded timeout.
3. Escalate termination only if the process does not exit.
4. Transition to Stopped after exit.

The app should only stop the process it manages, unless the user explicitly opts into handling an external process in a future version.

## Restart

Restart is Stop followed by Start using the current validated configuration.

## Failure Behavior

Failures should preserve enough error detail for the UI and logs:

- Invalid configuration
- Port conflict
- Launch failure
- Early process exit
- Stop timeout

