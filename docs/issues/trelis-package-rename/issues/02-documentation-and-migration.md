# 02: Update documentation and publish migration guidance

**Parent:** [Trelis package rename and release migration](../spec.md)

**What to build:** Bring the project documentation to the `trelis` name and
publish truthful consumer migration guidance and a CHANGELOG entry.

**Blocked by:**
- [01: Rename package identifier, entry point and imports](01-rename-package-identifier.md)

**Status:** claimed

- [ ] `README.md` and `example/` reflect the `trelis` package name and the
      renamed entry point; sample code imports `package:trelis/trelis.dart`.
- [ ] `CHANGELOG.md` gains a release entry describing the rename, the breaking
      import change and the one-line migration.
- [ ] `GLOSSARY.md` and live docs that name the package use `trelis` (do not
      rewrite resolved design/evidence history or quoted identifiers).
- [ ] Publish `doc/evidence/trelis-package-rename/migration.md` (or equivalent)
      with the before/after import mapping, the entry-point change, and any
      pubspec/version notes.
- [ ] No live `package:prompty` reference remains in documentation or examples.

- [ ] Record actual verification: source revision, commands run and results; do
      not treat the edit itself as a pass.

## Comments

**Claim.** Claimed on `integration/trelis-package-rename`. Ticket 01 is
resolved, so the code imports are already `package:trelis`. This ticket
renames the live documentation, the example filename, and publishes
migration guidance; historical evidence/research docs and the archived
prototype-themes stay as written.
