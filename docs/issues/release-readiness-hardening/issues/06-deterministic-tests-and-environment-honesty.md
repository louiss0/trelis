# 06 Deterministic timing, resize, platform, and locale test evidence

Status: resolved

**Blocked by:** none

**What to build:** Remove consequential fixed sleeps from the identified asynchronous prompt, colour-input, feedback batching, resize, and native PowerShell interaction tests. Use the existing FeedbackClock seam for MultiSpinner batching, controlled resize notification streams where possible, provider completion/event-queue drainage/observable output conditions with bounded deadlines elsewhere, and bounded waits for prompt/help/caret states in native scripts. Keep only a small polling smoke test that awaits the observable reflow condition. Convert bare platform conditional returns into explicit test-platform declarations or reasoned skips. Provision or assert CI locale prerequisites so missing numeric/date fixtures fail as prerequisite diagnostics rather than silently passing. Preserve exact terminal byte assertions where those bytes are the external contract. See the [spec](../spec.md), especially “Test determinism and environment honesty”.

## Acceptance criteria

- [x] Identified fixed sleeps that merely hope asynchronous work finished are replaced by deterministic state, clock, notification, readiness, or bounded observable conditions.
- [x] MultiSpinner batching tests use the existing FeedbackClock seam rather than real milliseconds.
- [x] Resize behavior uses controlled notifications where possible; the remaining polling smoke test bounded-waits for actual reflow.
- [x] Native PowerShell interactions wait for prompt, help, dismissal, or restored-caret state rather than fixed post-key delays.
- [x] Platform-only tests declare platform/reasoned skips, and locale prerequisites are provisioned or fail explicitly in CI.
- [x] Focused tests, analyzer, and relevant broader test suites pass.

## Comments

## Answer

Implemented on branch `release-readiness/06-determinism` in three commits
(`test(determinism): bounded waits and clock-driven feedback batching in Dart
tests`, `test(determinism): bounded waits in native PowerShell interaction
harnesses`, plus the integration merge).

### Shared deterministic seams (new test fixtures)

- `test/support/bounded_wait.dart` — `awaitCondition`/`awaitOutputContains`
  bounded-poll observable output/state with a failure deadline and a diagnostic
  naming the missing condition; `awaitLoneEscape` is the documented lone-escape
  disambiguation protocol wait (moved here from the async-search fixture, which
  re-exports it for existing callers).
- `test/support/fake_feedback_clock.dart` — shared test-controlled
  `FeedbackClock`; time advances only through `elapse`, so no real milliseconds
  participate in cadence or batching assertions.

### Dart test determinism

- `test/feedback_test.dart` — the milestone-coalescing and unchanged-heartbeat
  Progress tests now drive `FakeFeedbackClock` through the exact batching
  windows instead of sleeping 90–160 real milliseconds; the file-private clock
  was replaced by the shared fixture. Exact output assertions unchanged.
- `test/multi_spinner_test.dart` — both batching tests (latest-state coalescing
  and the 100-task single batch window) use the clock seam; frame-glyph byte
  assertions preserved exactly.
- `test/theme_feedback_components_test.dart` — the participation-release wait
  is event-queue drainage (`_pump()`), which is the actual synchronization
  contract of the release future chain.
- `test/color_input_test.dart` — the preview-withdrawal assertion bounded-waits
  for the observable `Preview unavailable` output.
- `test/cron_interaction_conformance_test.dart`, `test/cron_linear_parity_test.dart`
  — preview activation and cancellation bounded-wait for `Calculating preview`
  / `Matching preview: cancelled` output; the stray-arrow ordering uses event
  drainage because stream processing is in-order. The hostile-list
  responsiveness assertion (750 ms) is retained because responsiveness is the
  behavior under test, now measured at the moment the observable output arrives.
- `test/cron_provider_bounds_test.dart` — cancellation no longer sleeps before
  flipping the flag; the preview machinery polls `isCancelled` itself and kills
  the hung worker whenever spawning finishes, so the cancelled outcome is
  deterministic.
- `test/duration_input_test.dart` — the lone escape is delivered on a stream
  that stays open (the actual input contract) and the prompt's own completion
  is awaited; removing the fixed delay without that restructuring falsified the
  test, confirming the synchronization contract.
- `test/editable_probe_test.dart` — the interrupt is sent only after the
  probe's own stderr observably contains `Help dismissed` (bounded deadline).
- `test/multiline_tag_migration_test.dart` — help dismissal bounded-waits for
  the observable `Help dismissed.` output rather than the decoder's fixed
  disambiguation delay.
- `test/slider_test.dart` — the help-dismissal path bounded-waits for the
  observable dismissal; the editing-return path uses the named `awaitLoneEscape`
  seam because no output marker exists there and input must not merge into the
  ambiguous escape chunk.
- `test/native_async_fixture_test.dart` — the controlled providers resolve
  through bare futures/`Timer.run`, so event-queue drainage is the
  synchronization contract; the failure path bounded-waits for
  `Search unavailable`.
- `test/native_resize_test.dart` — the polling smoke test bounded-waits for the
  observable reflow (`> <`) instead of assuming one 600 ms poll interval.
- Remaining millisecond delays in Dart tests are inside bounded polling loops
  (`_until` helpers, `_appearedWithin`, the new stderr wait) or are intentional
  fixture behavior: `test/feedback_native_app.dart`'s 8 s `wait` keeps the
  process alive so the native harness can observe it, and
  `gui_evidence_probe_test.dart`'s pulse interval is a behavior parameter.

### Resize notifications

`test/idle_text_input_resize_test.dart` already drove controlled notification
streams through the resize observer seam; it is unchanged. The native polling
fallback keeps exactly one smoke test, now bounded-waiting the reflow.

### Native PowerShell interactions

- All 23 uniform `*_windows.ps1` interaction scripts plus
  `terminal_probe_windows.ps1` and `filesystem_picker_native_checks.ps1`:
  the fixed seven/six-second startup sleep is now a bounded (60 s) readiness
  poll — acquiring the console flips the observed console state away from the
  pre-launch baseline with VT output enabled, distinguishing compilation time
  from interaction responsiveness; a process that finishes before interaction
  short-circuits readiness as moot. `feedback_windows.ps1` bounded-waits for
  the observable final output line (`application result`).
- `test/text_input_windows.ps1` — help scenarios wait for the observable help
  screen (`Help:`), the restored screen equality and the restored caret state
  through a `Wait-Probe`/`Wait-ProbeSettled` helper instead of fixed 300 ms
  post-key delays; modal re-open/interrupt/EOF sequences rely on the ordered
  console input queue. Caret scenarios bounded-wait for the exact caret/row
  states they assert (same equality/regex conditions, so a wrong terminal state
  fails with the last observed state as the diagnostic).
- `test/key_capture_windows.ps1` — navigation keys need no separation because
  console input records are an ordered queue; the final result assertion proves
  the order.
- All `.ps1` files parse cleanly (PowerShell `Parser::ParseFile` over every
  script). The scripts themselves were not executed locally because they spawn
  real console windows; the `windows-native` CI job remains the execution
  evidence path.
- Left for ticket 02 (ConPTY staging/diagnostics) rather than conflicting: the
  in-child `Start-Sleep -Seconds 2/3/4` pre-launch staging delays and the
  keep-alive sleeps inside the spawned command lines, and the post-Start-Process
  3 s console-delegation wait in `text_input_windows.ps1`.

### Platform and locale honesty

- Bare `if (!Platform.isX) return;` guards converted to explicit `skip:`
  declarations with reasons in the date-input, path-input, posix-errno,
  native-resize and number-input tests; the runner output now reports
  `Skip: requires a … host` instead of silently passing.
- `test/number_input_test.dart` Linux numeric-convention test fails with a
  prerequisite diagnostic when no `de_DE`/`fr_FR` locale is installed or
  `locale -a` is unavailable, instead of passing silently; the dart CI job
  provisions `de_DE.UTF-8` on Linux (`platform-regression.yml`).
- `test/date_input_windows_test.dart` fails with a prerequisite diagnostic
  when the host short-date profile is not the declared en-US fixture;
  `test/date_input_system_instructions_test.dart` fails explicitly when the
  system date pattern cannot resolve.

### Verification

- `dart test` full suite on the merged branch: 5700 passed, 4 explicitly
  skipped (`requires a … host`), 0 failures — includes the merged ticket 01/07
  work.
- `dart analyze`: no issues.
- `dart format --output=none --set-exit-if-changed .`: clean on the merged
  branch (the two pre-existing drifted files were repaired by ticket 07 in the
  integration branch, not hand-edited here).
- Focused repeats: duration-input escape restructuring verified across three
  consecutive runs before and after; cron/slider/feedback/resize/editable-probe
  suites green.
- Exact terminal byte assertions (spinner frames, caret rows, editor state
  regexes, secret non-disclosure) preserved unchanged throughout.
