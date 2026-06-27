# v22.20.0 Localization Profile Messages

v22.20.0 localizes a focused set of profile workflow messages from `AppViewModel`.

## Implemented

- Localized user-facing profile edit fallback text.
- Localized export profile status messages and save panel title.
- Localized import preview status messages and open panel title.
- Localized import completion and failure summaries.
- Localized primary delete-profile guard messages.

## Preserved text

- Raw `appendLog` output remains English and technical.
- File names, error details, counts, and profile IDs remain unchanged.
- Import service messages are left for a later service-level localization pass.

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
