# Specify accessible text and progress feedback

Type: grilling
Labels: wayfinder:grilling
Status: resolved
Blocked by: 04
Assignee: primary-agent
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Answer

Confirmed by the human after live discussion. These are interaction/presentation requirements, not implemented behavior or verified screen-reader support.

### Ownership and lifecycle

- Text, Progress, Spinner and MultiSpinner are feedback-only. They do not take focus, read keys, acquire input, change input/echo modes, own operation cancellation or exit the application.
- The application owns work and any interaction. Do not advertise a cancellation key unless the application actually provides it.
- Clean up cursor/rendering changes the feedback presentation owns. Input-mode ownership remains outside these components.
- Retain start and final outcome/failure messages. Disposal of unfinished feedback never implies success.
- Finalization is terminal for that task: ignore stale asynchronous progress/state updates rather than repainting a final outcome as running.
- Distinguish caller-supplied waiting/running from completed, failed, skipped, cancelled and interrupted outcomes. Neither 100 percent nor disposal implies success.
- Preserve semantic task identity and final details independently of color, decoration or position. Narrow layouts can simplify decoration, but task names, values, outcomes and errors remain available.

### Text

- Supplied strings are literal content by default; unsafe terminal controls are rendered harmlessly rather than executed. Raw ANSI is not interpreted implicitly.
- Ordinary text stays ordinary. Hint/success/warning/error distinctions have readable labels where needed; theme styling supplements rather than replaces meaning.
- Exact control-sanitization implementation is not selected here and must preserve intended readable content without permitting terminal-control injection.

### Progress and Spinner

- Linear output includes start, meaningful phase/milestone updates and final outcome; never emit animation frames as lines or repeated unchanged heartbeat messages.
- Provisional configurable linear numeric defaults: 10-percentage-point milestones, at most one intermediate numeric update per 5 seconds, coalesced to the latest eligible value. Start and final outcomes do not wait for the numeric timer.
- These defaults need real-environment validation; they are not a universally accessible announcement interval.
- Unknown totals use an explicit indeterminate activity state without a fabricated percentage.
- Determinate updates require a positive total and completed count within bounds. Reject invalid updates through a caller-facing error while retaining the last valid display; do not clamp or print misleading values. Exact Dart error/result representation is deferred.
- Identify recalculation when the total changes rather than silently suggesting ordinary regression. The precise presentation can be refined in validation.
- Spinner animation is optional supplementary presentation. Disabling animation preserves rich layout with explicit static state and real state/value updates; it does not force linear mode.

### MultiSpinner

- Use stable task identities and stable rich row order. Each linear task update names its task.
- Coalesce intermediate progress/phase updates across the group into at most one batch per configurable 5-second default window; per-task throttles alone are insufficient.
- Start/final outcomes and failures are not delayed by the intermediate timer. The batching rule bounds intermediate batch frequency, not the number of genuine outcomes a caller can generate.
- Retain individual failure details and produce a final group summary with every task outcome. Mixed results must not be represented as blanket success.
- The final summary is an intentional reviewable recap; it must not erase or contradict individual task outcomes.

### Modes and verification

- Follow the shared contract's output-stream and rich/linear selection rules. Redirected feedback is stable textual output without animation or cursor addressing.
- Rich and nonanimated views use explicit state words and meaningful values; linear output retains useful history.
- These components emit understandable text; they do not guarantee what a screen reader will speak or manipulate its settings.
- Verify task identification, progress interpretation, quiet output, failure retention, final summaries, narrow layouts, control handling and lifecycle in the exact environments selected by [Choose the accessibility verification matrix and evidence gates](11-verification-matrix.md). Include high-concurrency workloads and real screen-reader review, not only single-task snapshots.

## Question

What are the accessible presentation and lifecycle contracts for Text, Progress, Spinner and MultiSpinner? Decide meaningful nonvisual updates, throttling, completion/error states, reduced motion, non-color cues and linear/noninteractive output behavior.
