# 03: Release readiness and final verification

**Parent:** [Trelis package rename and release migration](../spec.md)

**What to build:** Finalize release metadata and prove the renamed package is
green end to end.

**Blocked by:**
- [02: Update documentation and publish migration guidance](02-documentation-and-migration.md)

**Status:** claimed

- [ ] `pubspec.yaml` carries a correct `description` and the public `repository`
      URL (`https://github.com/louiss0/trelis`); version is intentional.
- [ ] `dart pub get` resolves; `dart analyze` is clean.
- [ ] Full `dart test` suite passes.
- [ ] `dart run tool/check_doc_links.dart` reports no broken links.
- [ ] `dart run tool/check_issue_tracker.dart` reports no legacy tracker.
- [ ] CI (Platform regression workflow) is green on the integration branch.
- [ ] Publish an accepted/blocked verdict with revision-linked artifacts and any
      limitations; actual pub.dev publishing remains out of scope.

- [ ] Record actual verification: source revision, commands run and results; do
      not treat the edit itself as a pass.

## Comments

**Claim.** Claimed on `integration/trelis-package-rename`. Tickets 01 and 02
are resolved. This ticket finalizes release metadata, runs the full
verification battery, and records the verdict.
