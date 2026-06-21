# Diagnostics Fixtures

These files are static diagnostics fixture data for future tests.

They are not app runtime resources.
They do not execute diagnostics.
They do not call endpoints.
They do not send inference requests.
They do not persist diagnostics history.

## Layout

- `results/`: status-oriented result fixtures.
- `redaction/`: redaction expectation fixtures.
- `aggregation/`: aggregation expectation fixtures.
- `negative/`: boundary and unsafe-content absence fixtures.
- `summaries/`: expected copied-summary text fixtures.

## Coverage

Initial coverage includes:

- pass, warning, fail, skipped, unknown, cancelled, and timeout statuses;
- copy-safe redaction examples;
- aggregation precedence example;
- external ownership boundary example;
- selected profile no-change example;
- copied mixed-status summary example.

## Safety

Fixtures must use placeholder data only.
Do not add real tokens, real account names, real home paths, machine names, raw command output, prompts, responses, or live endpoint data.
