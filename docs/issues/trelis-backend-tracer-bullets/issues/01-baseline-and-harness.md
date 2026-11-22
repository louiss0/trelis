# 01: Capture the regression baseline and deterministic harness

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Make existing prompt and feedback behavior reproducible before changing the critical backend, so later slices can distinguish intended presentation changes from regressions.

**Blocked by:** None (can start immediately).

**Status:** resolved

**Acceptance reference:** [B-BASE](../../trelis-backend-implementation/spec.md#b-base), [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity).

- [x] Capture the current public component, answer-type and lifecycle inventory with source revision and available baseline results.
- [x] Supply deterministic selected-output, environment, geometry, time, input and failure fixtures without changing production behavior.
- [x] Retain deep public behavior assertions and relevant historical limitations; do not turn old reports or configured CI into current passes.
- [x] Record failed or unavailable baseline checks explicitly and preserve unrelated working-tree/evidence artifacts.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-01-baseline` at `9469994ed64b6a225df07de7e0e25911479b2213` and merged into `integration/trelis-backend-tracer-bullets` by merge commit `cea914e1b6ac270e3f9f5345b3aff4df188553ea`.

Evidence is recorded in `assets/evidence/trelis-backend/baseline.md` with the native repeat report in `assets/evidence/trelis-backend/baseline-text-input-repeat.txt`. Deterministic public-seam fixtures and tracer tests are in `test/support/backend_baseline_fixture.dart` and `test/backend_baseline_harness_test.dart`.

Merged verification passed the focused baseline tests (3), `dart analyze`, and documentation link checking. The implementation report also records a full 642-test pass, the 144-case component acceptance matrix, fresh Windows TextInput repeat evidence, an initially flaky feedback-native probe followed by a passing sequential retry, and unavailable CI/POSIX-native/GUI evidence without representing those as passes.
