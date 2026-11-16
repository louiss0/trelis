# Package rename task order

The rename is atomic at the package level (the pubspec name, entry point and
imports must change together to keep anything compiling), so the three tickets
run strictly in order. No parallel ticket is safe while the import surface is
changing.

| Ticket | Blocked by |
|---|---|
| [01: Rename package identifier, entry point and imports](issues/01-rename-package-identifier.md) | — |
| [02: Update documentation and publish migration guidance](issues/02-documentation-and-migration.md) | [01](issues/01-rename-package-identifier.md) |
| [03: Release readiness and final verification](issues/03-release-readiness.md) | [02](issues/02-documentation-and-migration.md) |

Every ticket keeps the full test suite, analyzer, tracker boundary and doc-link
checks green. No ticket is "done" because its files were edited: the change must
compile, the suite must pass, and the evidence must record the actual revision
and results.
