# 03: Release readiness and final verification

**Parent:** [Trelis package rename and release migration](../spec.md)

**What to build:** Finalize release metadata and prove the renamed package is
green end to end.

**Blocked by:**
- [02: Update documentation and publish migration guidance](02-documentation-and-migration.md)

**Status:** resolved

- [x] `pubspec.yaml` carries a correct `description` and the public `repository`
      URL (`https://github.com/louiss0/trelis`); version is intentional.
- [x] `dart pub get` resolves; `dart analyze` is clean.
- [x] Full `dart test` suite passes.
- [x] `dart run tool/check_doc_links.dart` reports no broken links.
- [x] `dart run tool/check_issue_tracker.dart` reports no legacy tracker.
- [x] CI (Platform regression workflow) is green on the integration branch.
- [x] Publish an accepted/blocked verdict with revision-linked artifacts and any
      limitations; actual pub.dev publishing remains out of scope.

- [x] Record actual verification: source revision, commands run and results; do
      not treat the edit itself as a pass.

## Comments

**Claim.** Claimed on `integration/trelis-package-rename`. Tickets 01 and 02
are resolved. This ticket finalizes release metadata, runs the full
verification battery, and records the verdict.

**Verification.** `dart pub get` resolves. `dart format` 0 changed.
`dart analyze` → No issues found. `dart test` → +4795, all passed.
`dart run tool/check_doc_links.dart` → 0 broken. `dart run
tool/check_issue_tracker.dart` → clean. CI green on the integration branch.

**Answer.** `pubspec.yaml` now carries `version: 2.0.0` and the public
repository URL; the full battery is green and
`doc/evidence/trelis-package-rename/verdict.md` records an ACCEPTED verdict
with the measured results and the explicit out-of-scope items (pub.dev
publishing, accessibility qualification, historical-name preservation). The
rename spec is complete.
