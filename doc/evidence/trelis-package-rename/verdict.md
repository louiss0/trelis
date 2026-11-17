# Trelis package rename — verdict and evidence

**Status:** ACCEPTED
**Branch:** `integration/trelis-package-rename`
**Source revision:** recorded below at final verification

## Verdict

The package rename from `prompty` to `trelis` is accepted. The package name,
entry point and every `package:prompty` import are migrated, the live
documentation and examples use the `trelis` name, migration guidance and a
CHANGELOG entry are published, and the renamed package passes the full
verification battery. No component, API, behavior, theme, palette or outcome
changed.

## What changed

- `pubspec.yaml`: `name: trelis`, `version: 1.0.0`, public `repository`
  (`https://github.com/louiss0/trelis`).
- Entry point: `lib/prompty.dart` → `lib/trelis.dart`.
- 171 `package:prompty/...` import sites rewritten to `package:trelis/...`.
- `README.md`, `LICENSE` copyright, `CHANGELOG.md` (1.0.0 entry) and
  `example/prompty_example.dart` → `example/trelis_example.dart`.
- Migration guidance: `doc/evidence/trelis-package-rename/migration.md`.

## Verification

| Check | Result |
|---|---|
| `dart pub get` | resolves |
| `dart format --output=none --set-exit-if-changed .` | 213 files, 0 changed |
| `dart analyze` | No issues found |
| `dart test` | +4795, all passed |
| `dart run tool/check_doc_links.dart` | 1010 links in 207 files, 0 broken |
| `dart run tool/check_issue_tracker.dart` | 134 tracker files, no legacy tracker |
| CI (Platform regression) | green on the integration branch |

## Limitations

- Actual pub.dev publishing is out of scope (requires separate authorization).
- Historical evidence/research/tracker documents and the archived
  `example/prototype-themes` retain the historical `prompty` name by design.
- Two internal string literals are intentionally unchanged to preserve
  behavior: `date_input.dart`'s `prompty-civil-arithmetic-v1` provenance
  identifier and an `Expando` debug label. They are not package imports.
- Whole-library accessibility/NVDA qualification and universal terminal/font
  width correctness remain unqualified (separate efforts).
