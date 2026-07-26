# Domain Docs

MLXServerManager uses a single-context domain documentation layout.

## Before exploring or changing the codebase

- Read `AGENTS.md` and `docs/stable_scope.md` first.
- Read root `CONTEXT.md` when it exists.
- Read relevant ADRs under `docs/adr/` when that directory exists.
- Treat older version-specific planning documents as historical unless `docs/stable_scope.md` explicitly adopts them.

Missing `CONTEXT.md` or ADRs are not blockers. Proceed without creating speculative documentation. Use domain-modeling workflows only when terminology or architectural decisions genuinely need to be resolved.

## Vocabulary

Use terms defined in `CONTEXT.md` consistently in implementation plans, issue titles, tests, and code. Do not silently replace established project terminology with synonyms.

## Conflicts

Surface any proposed change that conflicts with `docs/stable_scope.md`, `AGENTS.md`, or an existing ADR before implementing it.
