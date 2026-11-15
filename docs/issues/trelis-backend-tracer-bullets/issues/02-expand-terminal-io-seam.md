# 02: Expand the shared terminal I/O seam without changing behavior

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Let existing components use a replaceable terminal I/O adapter while retaining the old form, so the migration can land green instead of requiring one breaking rewrite.

**Blocked by:**
- [01: Capture the regression baseline and deterministic harness](01-baseline-and-harness.md)

**Status:** resolved

**Acceptance reference:** [B-BASE](../../trelis-backend-implementation/spec.md#b-base), [B-CAP](../../trelis-backend-implementation/spec.md#b-cap), [B-FAIL](../../trelis-backend-implementation/spec.md#b-fail).

- [x] Add the new adapter form beside the current path, covering selected input/output observations, acquisition and restoration.
- [x] Demonstrate unchanged existing public prompt/feedback results and output contracts through the expanded seam.
- [x] Inject failures and environmental observations without requiring a real developer terminal in deterministic tests.
- [x] Do not remove the legacy implementation before all consumers migrate; record the later contract condition.
- [x] Keep constructor behavior output-free and avoid competing owners of native terminal modes.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-02-terminal-io` at `31c8e8c8b1a1288b0db1f54a8f22f95123fea557` and merged into `integration/trelis-backend-tracer-bullets` by merge commit `526789368e90ed655c11f9e61b846c0361475ec9`.

The additive public adapter is in `lib/src/terminal_io.dart`, exported from `lib/prompty.dart`, and integrated with `TextInput` and all four feedback components while retaining legacy invocation paths. Public-seam tests are in `test/terminal_io_test.dart`; implementation evidence and limitations are recorded in `doc/evidence/trelis-backend/ticket-02-terminal-io.md` with the Windows repeat report in `doc/evidence/trelis-backend/ticket-02-text-input-repeat.txt`.

Merged verification passed 39 focused tests, `dart analyze`, and documentation link checking. Ticket-branch verification also passed the 144-case public component matrix and the full 647-test suite, plus fresh retained-native Windows repeat/restoration evidence.
