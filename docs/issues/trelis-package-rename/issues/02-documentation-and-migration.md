# 02: Update documentation and publish migration guidance

**Parent:** [Trelis package rename and release migration](../spec.md)

**What to build:** Bring the project documentation to the `trelis` name and
publish truthful consumer migration guidance and a CHANGELOG entry.

**Blocked by:**
- [01: Rename package identifier, entry point and imports](01-rename-package-identifier.md)

**Status:** resolved

- [x] `README.md` and `example/` reflect the `trelis` package name and the
      renamed entry point; sample code imports `package:trelis/trelis.dart`.
- [x] `CHANGELOG.md` gains a release entry describing the rename, the breaking
      import change and the one-line migration.
- [x] `GLOSSARY.md` and live docs that name the package use `trelis` (do not
      rewrite resolved design/evidence history or quoted identifiers).
- [x] Publish `doc/evidence/trelis-package-rename/migration.md` (or equivalent)
      with the before/after import mapping, the entry-point change, and any
      pubspec/version notes.
- [x] No live `package:prompty` reference remains in documentation or examples.

- [x] Record actual verification: source revision, commands run and results; do
      not treat the edit itself as a pass.

## Comments

**Claim.** Claimed on `integration/trelis-package-rename`. Ticket 01 is
resolved, so the code imports are already `package:trelis`. This ticket
renames the live documentation, the example filename, and publishes
migration guidance; historical evidence/research docs and the archived
prototype-themes stay as written.

**Verification.** `dart analyze` → No issues found. `dart test` → +4795, all
passed. `dart run tool/check_doc_links.dart` → 0 broken links.
`dart run tool/check_issue_tracker.dart` → clean.

**Answer.** README title/import/example path, `example/prompty_example.dart`
(renamed to `trelis_example.dart`), LICENSE copyright and the CHANGELOG now use
`trelis`; a `2.0.0` CHANGELOG entry and
`doc/evidence/trelis-package-rename/migration.md` document the breaking import
change and the one-line migration. Remaining `prompty` text is intentionally
left: historical evidence/research/tracker docs, the archived
`example/prototype-themes`, the rename's own before/after descriptions, and two
internal string literals (`date_input.dart`'s `prompty-civil-arithmetic-v1`
provenance identifier and an `Expando` debug label), which are not package
imports and would be behavior changes if rewritten. No live `package:prompty`
import remains.
