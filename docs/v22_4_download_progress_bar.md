# v22.4.0 Download Progress Bar

v22.4.0 makes Hugging Face download progress visible in the Downloads surface.

## Implemented

- Added a `Download progress` panel below the download status rows.
- Shows a linear progress bar when percentage output is available from the `hf` command.
- Shows an indeterminate progress bar while a download is active but no percentage has been parsed yet.
- Shows idle, preparing, finalizing, completed, failed, and cancelled text states.
- Added queue-row progress bars for each session download entry.
- Mirrors parsed percentage progress into the queue entry so the queue can show the same progress as the active status.

## Notes

Progress accuracy depends on the output emitted by the Hugging Face CLI. If the CLI does not emit percentage text, the app shows an indeterminate bar rather than inventing a percentage.

## Verification

- Debug build should pass.
- Test suite should pass.
- `git diff --check` should pass.
