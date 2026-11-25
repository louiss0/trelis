# 08 Prerelease version, migration documentation, and honest release evidence

Status: resolved

**Blocked by:** [01](01-input-event-crlf-and-multiline-finish.md), [07](07-generated-files-formatting-and-public-api-ci.md)

**What to build:** Reconcile package versioning, changelog, README, migration guidance, examples, and release evidence with the implemented public API and open human gates. Change the package version to 1.0.0-dev.1 while interaction and colour gates remain incomplete. Rewrite changelog entries for the package rename, breaking theme-instance cutover, removed APIs, new key gestures, remaining instability, and missing human evidence. Migrate user-facing examples to exported theme instances and parameterless prompt methods; remove or clearly quarantine internal compatibility examples as contributor-only test material. Correct supplied-answer, invocation-level output/session configuration, direct-constructor, and static-factory claims. Document scripted input honestly as an explicit stream environment, the exact termunicode pin as an accepted Unicode-data policy, and documentation-directory publish warnings as accepted project-structure tradeoffs. Record publish dry-run output as evidence only and keep interaction/colour gates ready-for-human without stable/accessibility overclaims. See the [spec](../spec.md), especially “Documentation, version and release evidence”.

## Acceptance criteria

- [x] `pubspec.yaml` version is `1.0.0-dev.1` and all public unstable-status messaging agrees with it.
- [x] README and migration documentation teach only supported public theme-instance usage to package consumers; internal compatibility examples are absent or explicitly contributor/test scoped.
- [x] Changelog accurately separates rename, breaking cutover, removed APIs, key gestures, prerelease instability, and missing human evidence; false compatibility claims are gone.
- [x] Scripted input, exact Unicode pin, documentation-directory warning, publish dry-run evidence, and open interaction/colour human gates are documented truthfully.
- [x] No stable API, accessibility qualification, screen-reader usability, or real-terminal colour-quality claim is made without required human evidence.
- [x] Documentation-link and tracker checks plus focused tests pass.


## Answer

Implemented on `release-readiness/08-prerelease-docs` (merge of
`integration/release-readiness-hardening` included, no conflicts).

- `pubspec.yaml` version is `1.0.0-dev.1`; unstable-status messaging agrees in
  `README.md`, `lib/trelis.dart`, `docs/adaptive-theme-public-api-migration.md`
  and `CHANGELOG.md`.
- `README.md` rewritten around the public theme-instance API: theme
  construction, parameterless `prompt()`, the 38-method component catalog,
  scripted input documented honestly as an explicit stream environment
  (`TerminalEnvironment.scripted`), and the ticket-01 input-event-local
  CRLF/unframed-paste documentation integrated in the "Key gestures and line
  endings" section. Constructor-based component documentation moved to
  `docs/internal-component-compatibility.md`, explicitly scoped as
  contributor/test-only material (relative asset links adjusted).
- `CHANGELOG.md` rewritten as `## 1.0.0-dev.1` with separated entries: package
  rename, breaking theme-instance cutover with removed APIs, key gestures,
  component inventory with the exact `termunicode` pin, and missing human
  evidence. The false compatibility claims are gone.
  `assets/evidence/trelis-package-rename/migration.md` gained a historical
  banner so its rename-time "nothing else changed" claim is not read as
  current guidance, including the prerelease constraint note.
- Unicode pin policy documented in README "Unicode data policy" and in the
  publish evidence; the exact pin stays.
- Publish dry-run evidence: `dart pub publish --dry-run` from clean commit
  `b26eddb` exits 65 with exactly 2 warnings and no errors, recorded in
  `assets/evidence/release-readiness/publish-dry-run.md` with full output in
  `publish-dry-run-output.txt`. Both warnings (exact `termunicode` constraint,
  `docs` vs `doc` directory name) are documented as accepted tradeoffs; the
  evidence explicitly is not authorization to publish.
- Overclaim sweep: pubspec description and `lib/trelis.dart` no longer lead
  with "Accessible"; README "Accessibility status" and "Release status and
  evidence" sections state the open interaction/colour human gates without
  stable/accessibility/screen-reader/colour-quality claims.

Evidence commands and results:

- `dart run tool/check_doc_links.dart` — 1256 relative links in 283 Markdown
  files, no broken links.
- `dart run tool/check_issue_tracker.dart` — 201 tracker files checked, no
  legacy local tracker.
- `dart analyze` — no issues found.
- `dart test test/public_theme_instance_test.dart
  test/public_compatibility_inventory_test.dart
  test/public_multiline_input_test.dart` — all 31 tests passed.
- `dart pub publish --dry-run` — evidence above (2 accepted warnings, no
  errors, evidence only).

No test determinism, native harness, CI native routing or generator work was
performed; those belong to other tickets.

## Comments
