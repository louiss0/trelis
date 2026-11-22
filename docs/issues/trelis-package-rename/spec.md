# Trelis package rename and release migration

**Status:** ready-for-agent

Rename the Dart package from `prompty` to `trelis`, matching the project name,
and prepare release-ready metadata plus consumer migration guidance. Public
behavior, the 38-component API surface, the 15 structural themes and the 45
palettes are all unchanged — this is a naming and packaging migration only.

## Scope

- `pubspec.yaml`: `name` → `trelis`; refresh `description`; set the public
  `repository` URL (`https://github.com/louiss0/trelis`).
- Package entry point: `lib/prompty.dart` → `lib/trelis.dart`.
- Every `package:prompty/...` import becomes `package:trelis/...` across
  `lib/`, `test/`, `example/`, `tool/`, and `bin/`.
- Update the remaining textual `prompty` references in `README.md`,
  `CHANGELOG.md`, `GLOSSARY.md`, and the docs that name the package, without
  rewriting resolved design/evidence history (historical commit references and
  quoted identifiers stay as written unless they are live import paths).
- Publish migration guidance (a `assets/evidence/trelis-package-rename/migration.md`
  or equivalent) and a CHANGELOG entry describing the rename, the breaking
  import change, and the one-line consumer migration (`package:prompty/...` →
  `package:trelis/...`).
- Verify: `dart analyze` clean, the full `dart test` suite green, `dart run
  tool/check_doc_links.dart` green, `dart run tool/check_issue_tracker.dart`
  clean, and CI green on the integration branch.

## Out of scope

- Any behavior, API, or presentation change beyond the rename.
- Actually publishing to pub.dev (requires separate authorization).
- Accessibility qualification and package-level feature work (separate efforts).
- Rewriting the Git history or past evidence documents to backdate the name.

## Acceptance

- No `package:prompty` import remains anywhere in the repository.
- The package entry point is `lib/trelis.dart` and it is what `pubspec.yaml`
  declares/exposes.
- The full test suite, analyzer, tracker boundary and doc-link checks are green
  locally and in CI.
- Migration guidance and the CHANGELOG entry are present and truthful.
