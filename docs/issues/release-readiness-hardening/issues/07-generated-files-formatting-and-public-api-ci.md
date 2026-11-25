# 07 Generated-file determinism, formatting, and external public API CI

Status: resolved

**Blocked by:** none

**What to build:** Make generated Dart files byte-deterministic using UTF-8 with LF newlines after formatting, regardless of host defaults. Declare LF checkout policy for generated text targets and perform the one-time normalization. Keep generated-diff verification byte strict so content drift still fails. Apply repository formatting to files currently failing the formatting gate and keep formatting before analysis/tests in CI. Put the external public API checker into the platform regression workflow as a required step; analyze the positive fixture as an external package and require every negative case to fail with its expected diagnostic. Replace source-order/literal inventory assertions with meaningful set comparisons or compile behavior. See the [spec](../spec.md), especially “Generated files and formatting” and “Public native lifecycle coverage and CI”.

## Acceptance criteria

- [x] Generators enforce UTF-8/LF output after formatting and generated targets are covered by LF checkout policy.
- [x] Generated files are normalized through generator/template changes only; generated-diff verification remains byte strict and catches content drift.
- [x] The repository formatting gate passes and is ordered before analysis/tests in CI.
- [x] External public API positive fixture is analyzed as an external package, negative cases fail with expected diagnostic codes, and the checker is a required workflow step.
- [x] Public inventory tests compare meaningful sets or compile behavior rather than literal fixture source ordering.
- [x] Generator, generated-diff, public API checker, formatter, analyzer, and focused tests pass.

## Comments

## Answer

Implemented on branch `release-readiness/07-release-infra` (worktree `prompty-rr-07`).

**Root cause of the nondeterminism (found test-first):** `dart format` preserves
whatever line endings the file already carries (verified directly: CRLF input
stays CRLF, LF input stays LF), and the generators wrote their pre-format
output through Python text-mode writes, which produce CRLF on Windows. The
byte comparison therefore passed on each host only by accident of matching
checkout/generation pairs and diverged whenever checkout policy and host
differed. The enhanced checker failed red on the pre-fix tree with
`generator output is not LF-only` / `checked-in file is not LF-only` for all
43 targets on a Windows `core.autocrlf=true` host.

**What changed:**

- `tool/lf_output.py` (new): shared `write_lf`/`enforce_lf` helpers. Both
  generators (`generate_theme_factories.py`, `generate_theme_tests.py`) write
  UTF-8/LF and re-enforce LF bytes after invoking `dart format`, regardless of
  host newline defaults.
- `.gitattributes` (new): `text eol=lf` for `lib/src/themes/*_theme.dart`,
  `test/*_theme_factories_test.dart` and
  `test/*_theme_acceptance_matrix_test.dart` (plain templates included), so
  Windows `core.autocrlf` cannot reintroduce CRLF into byte-strict targets.
- One-time normalization performed by regenerating every target through the
  corrected generators and re-checking out the plain templates under the new
  policy. No generated file was hand-edited; committed content is unchanged
  apart from working-tree line endings (the index was already LF).
- `tool/check_generated_diffs.py`: comparison remains byte strict and now
  reports non-LF generator output or checked-in files explicitly. Verified
  negative: injecting `// drift` into a generated test makes the checker fail
  with `generated diff: test\rail_theme_factories_test.dart`; the checker
  leaves the worktree as found on failure.
- Formatting gate repair: `dart format` applied to the 8 failing files
  (`bin/editable_probe.dart`, `lib/src/autocomplete.dart`,
  `test/bracket_theme_adaptive_test.dart`, `test/cron_field_cells_review_test.dart`,
  `test/line_adaptive_presentation_test.dart`, `test/minimal_adaptive_presentation_test.dart`,
  `test/multiline_test.dart`, `test/theme_filesystem_components_test.dart`).
  Reviewed diffs: pure line-wrapping, no generated file touched, no behavior
  change. Gate now passes: `Formatted 895 files (0 changed)`.
- `.github/workflows/platform-regression.yml`: the dart matrix job
  (windows/ubuntu/macos, so generated-file verification runs on a Windows and
  POSIX hosts) now runs `python tool/check_generated_diffs.py` and
  `dart run tool/check_public_api.dart` as required steps before `dart test`;
  the formatting gate remains ordered before analysis and tests.
  `actions/setup-python` makes `python` available identically on all matrix
  hosts.
- External public API checker: verified the positive fixture is analyzed as
  an external package (`dart analyze` inside `fixtures/public_api_fixture`,
  which depends on trelis by path) and every negative case fails with its
  expected diagnostic code — full run output ends with
  `negative public API inventory: ok` covering direct constructors, static
  factories, invocation configuration, supplied-answer types, hidden legacy
  components/internals and resolver functions.
- `test/public_compatibility_inventory_test.dart`: export assertions now
  compare membership with `unorderedEquals` instead of literal source order.
  The fixture test no longer treats fixture source text as compilation;
  instead it compares meaningful sets in both directions — declared theme
  classes vs. fixture-constructed themes, and public theme API factory methods
  vs. fixture-exercised `theme.` invocations (38 factories each way) — while
  compile acceptance/rejection stays with the external checker.

**Verification evidence (post-merge of `integration/release-readiness-hardening`
at f266fd4, clean merge):**

- `dart format --output=none --set-exit-if-changed .` → `Formatted 895 files (0 changed)`
- `dart analyze` → `No issues found!`
- `python tool/check_generated_diffs.py` → `generated diff check: ok (43 targets)`
- `dart run tool/check_public_api.dart` → `positive fixture: ok` + `negative public API inventory: ok`
- `dart run tool/check_issue_tracker.dart` / `check_doc_links.dart` → pass
- `dart test` → all 5,704 tests passed post-merge (5,697 pre-merge; the
  increase is ticket 01's new input regression coverage)
- Focused post-merge: inventory, multiline, public multiline input and shared
  terminal reader tests all pass.
