# docs

Durable written record of implementation plans and research findings, kept so decisions and context survive past a single session's conversation.

## Belongs here

- `plans/<date>-<slug>.md` — approved implementation plans (e.g. the phased build-out plan), one file per plan
- `research/<date>-<slug>.md` — findings from investigating the codebase, existing scripts, or the dev environment before a plan was written

## Does NOT belong here

- Module-specific architectural rules — those stay in each module's own scoped `CLAUDE.md`
- Source code of any kind — see App/Core/Downloaders/Converters/Resources instead

## Non-obvious patterns

Files here are exempt from the repo's line-limit hook (it only checks source-code extensions), so a plan or research doc can run long without being split — prefer that over fragmenting a single plan across multiple files.
