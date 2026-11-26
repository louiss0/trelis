# Release readiness hardening

Status: stable
Labels: ready-for-agent

## Problem Statement

A terminal user can currently lose the documented Multiline finish gesture after pressing Enter: in rich interaction, Enter inserts a newline into the draft answer, but a later Ctrl+J can be consumed by input decoding instead of finishing the answer. The component help and compact hint therefore describe a key gesture that does not always work.

A package consumer cannot yet trust the release evidence or release documentation. The Dart test suite is large and green, but important native checks fail or exercise the internal compatibility route while presenting themselves as public theme-instance coverage. Native failures discard the terminal transcript and process state needed to distinguish product bugs from harness flakes. Generated-file verification changes with the host checkout's line endings, formatting is not clean, and several tests rely on elapsed time or silently pass when their required locale or platform fixture is absent.

A maintainer preparing 1.0.0 cannot make a coherent stable-release decision. The package declares 1.0.0 while the public barrel, migration guide, and adaptive-theme tracker correctly describe the API as unstable pending the independent interaction and colour release gates. The changelog still claims compatibility with direct constructors and invocation-level configuration even though the coordinated public cutover removed those APIs. Most user-facing component documentation still teaches the internal compatibility seam rather than the public theme-instance API.

## Solution

Make the release evidence match the public contract before any stable 1.0.0 claim:

- Preserve the new key-gesture contract: Enter inserts a newline or activates the focused Multiline action, while Ctrl+J finishes the answer. Reconcile CRLF normalization without reintroducing accidental submission or losing genuine CRLF data in supported paste forms.
- Reconnect the native help fixtures to F1, verify help dismissal and continued editing through real terminal harnesses, and make native harness failures report enough evidence to diagnose the underlying phase.
- Extend the public theme-instance native fixture routes before naming scenarios as public coverage. Make Windows and POSIX native release checks exercise the exported theme-owned route rather than the internal compatibility route.
- Make generated files byte-deterministic across Windows, Linux and macOS, restore the formatting gate, and put the external public API checker into CI.
- Replace consequential fixed sleeps with deterministic state, clock, notification or readiness conditions. Make unsupported environments explicit instead of silent passes.
- Reconcile package versioning, changelog, README and migration documentation with the implemented public API and with the still-open human release gates. Until those gates pass, present the package as a prerelease rather than a stable accessible 1.0.0.

## User Stories

1. As a terminal user answering a rich Multiline prompt, I want Ctrl+J to finish after Enter inserts a trailing newline, so that I can submit multiline answers without abandoning the prompt.
2. As a terminal user, I want Enter and Ctrl+J to retain their documented meanings when they are delivered as distinct input events, so that decoder state cannot erase a later finish gesture.
3. As a terminal user, I want genuine CRLF line endings in supported input forms to be treated as line endings rather than as a finish command, so that pasted or scripted text does not submit accidentally.
4. As a terminal user, I want framed paste to preserve multiline content as draft answer data, so that paste remains safe after the Ctrl+J correction.
5. As a terminal user, I want unframed paste limitations to be documented honestly, so that I do not mistake an ambiguous byte stream for a lossless paste format.
6. As a terminal user, I want F1 to open component help in the native Windows console harness, so that the tested behavior matches the help gesture shown by the product.
7. As a terminal user, I want Escape to dismiss component help and return me to the same draft answer and caret state, so that asking for help does not destroy my work.
8. As a terminal user, I want input typed while help is open not to be interpreted as answer data, so that modal help remains coherent.
9. As a terminal user, I want unassigned function keys not to swallow or corrupt my answer, so that unsupported gestures fail harmlessly.
10. As a terminal user entering a secret, I want help opened with F1 never to disclose the hidden entry, so that using help does not compromise secret safety.
11. As a terminal user, I want native prompt exits to restore console state after cancellation, interruption, EOF, validation failure and writer failure, so that my terminal remains usable.
12. As a package consumer, I want the documented public examples to construct reusable theme instances and call parameterless prompt methods, so that I learn the supported API rather than an internal test seam.
13. As a package consumer, I want scripted input and native input to produce the same visible outcomes for the same key gestures, so that I can trust automated integration evidence.
14. As a package consumer, I want the package version to communicate prerelease instability accurately, so that I do not rely on a stable API before the maintainers consider it stable.
15. As a package consumer, I want migration guidance and changelog entries to describe the actual breaking public cutover, so that I can migrate without following false compatibility promises.
16. As a package consumer, I want the exact Unicode dependency policy explained, so that I understand whether Unicode data can change indirectly beneath my application.
17. As a release maintainer, I want the Windows native lifecycle job to exercise public theme instances, so that the job name and release evidence mean what they say.
18. As a release maintainer, I want the POSIX PTY lifecycle checks to exercise public theme instances, so that Linux and macOS evidence covers the exported route.
19. As a release maintainer, I want specialized native scenarios such as resize, output redirection, dumb-terminal refusal, session retirement and repeat acquisition implemented through the public route before they are renamed, so that coverage is not merely relabeled.
20. As a release maintainer, I want the external public API checker to run in CI, so that direct constructors, static factories, invocation configuration and supplied-answer APIs cannot silently reappear.
21. As a release maintainer, I want the positive external fixture actually analyzed as an external package, so that public API coverage is compile evidence rather than a source-string assertion.
22. As a release maintainer, I want formatting to pass before analysis and tests, so that local green tests cannot hide a red CI pipeline.
23. As a release maintainer, I want generated files to compare identically on every supported host, so that generated-file verification is a meaningful release gate.
24. As a release maintainer, I want generated content drift still to fail verification, so that line-ending determinism does not weaken the generator contract.
25. As a CI operator, I want native harness failures to include scenario, phase, child exit status, elapsed wait and terminal transcript, so that I can distinguish product defects from harness or environment failure without rerunning blindly.
26. As a CI operator, I want startup readiness, interaction input, process exit and result-file collection to have distinct diagnostics, so that a missing result file does not erase the original failure.
27. As a CI operator, I want diagnostic artifacts retained on failure and cleaned up on success, so that debugging is possible without accumulating noise.
28. As a CI operator, I want all spawned native harness processes and pseudoconsole resources cleaned up even on failure, so that one failing scenario cannot poison later scenarios.
29. As a CI operator, I want intermittent paste-case failures investigated with captured evidence rather than declared fixed after one later pass, so that release confidence is honest.
30. As a contributor, I want feedback batching tests to use the existing controllable clock seam, so that test outcomes do not depend on scheduler timing.
31. As a contributor, I want asynchronous prompt tests to await provider completion, event-queue drainage or an observable output condition, so that a slow machine does not create false failures.
32. As a contributor, I want resize behavior tests driven through controlled resize notifications where possible, so that geometry logic is tested deterministically.
33. As a contributor, I want the small native polling smoke test to await the reflow condition with a bounded deadline, so that it proves the behavior rather than assuming a fixed delay was enough.
34. As a contributor, I want native PowerShell interactions to wait for prompt, help or restored-caret state, so that cold compilation or machine load is not mistaken for product failure.
35. As a contributor, I want platform-only tests to use explicit platform skip declarations, so that skipped coverage is visible rather than indistinguishable from a pass.
36. As a contributor, I want CI locale prerequisites provisioned or asserted, so that missing locale fixtures cannot silently remove numeric and date coverage.
37. As a contributor, I want public API inventory tests to compare meaningful sets or compile behavior rather than literal source ordering, so that harmless formatting or export-order changes do not create false failures.
38. As an accessibility-minded user, I want help, compact hints and protected content verified as behavior, but I do not want automated terminal tests presented as screen-reader qualification, so that accessibility claims remain truthful.
39. As a release maintainer, I want the independent interaction and colour gates to remain explicit blockers until their required human evidence exists, so that automation does not overclaim readiness.
40. As a release maintainer, I want one final verification battery spanning formatting, static analysis, tests, documentation links, tracker integrity, generated files, public API compilation and native terminal scenarios, so that the release decision is based on consistent evidence.

## Implementation Decisions

### Key gestures and CRLF decoding

- The Multiline key-gesture contract remains the one introduced by the finish-affordance work: CR inserts a newline while Edit is focused or activates a focused action; LF finishes immediately through validation and acceptance. Ctrl+J is the documented finish key gesture. Do not revert to LF-as-newline or reintroduce Ctrl+T.
- `SharedTerminalReader` remains the existing input-decoding seam. Do not add a second decoder or a component-specific parallel reader.
- CRLF normalization becomes input-event-local and deterministic: a `\r\n` pair observed together in one decoded input event is normalized to the CR key gesture, but CR state never persists across input events, read calls or elapsed time. A separately delivered LF reaches the component as the finish key gesture.
- This rule intentionally acknowledges a byte-stream limitation: if two physical keypresses are coalesced by a terminal into one unframed CRLF byte pair, they are indistinguishable from CRLF data. Framed paste is the lossless supported route for multiline pasted data; unframed paste remains documented as ambiguous.
- Bracketed paste remains atomic at the reader seam. Existing paste normalization continues to convert CRLF and CR inside framed paste into newline data before insertion, so framed paste must not trigger finish.
- Add a public regression through a theme instance and scripted terminal environment in rich interaction. It must deliver Enter, observe the resulting edit state without a fixed sleep, then deliver Ctrl+J separately and require `Accepted` with the trailing blank line preserved in the draft answer.
- Add explicit decoder or component coverage for same-event CRLF normalization, separately delivered CR then LF, and framed paste containing CRLF. Native ConPTY coverage must stage Enter and Ctrl+J as separate writes so native behavior is not inferred only from scripted input.

### F1 native scenarios and ConPTY diagnostics

- F1 is the only component help key gesture covered by these harnesses. The Windows console probe sends the actual F1 console key event; VT-oriented scenarios use the recognized SS3 or CSI F1 encodings. No release fixture sends Ctrl+T as help.
- The existing ConPTY function-key case is split into two meaningful contracts: an F1 case opens component help, Escape dismisses it, and subsequent ordinary input completes the answer; an unassigned-function-key control verifies that a key with no binding neither edits nor blocks the answer.
- The Windows TextInput help scenarios verify that F1 opens component help, secret text is not disclosed, repeated F1 does not nest help, Escape restores the prior screen and caret, and the chosen exit path still produces the expected outcome.
- The ConPTY runner grows staged input support rather than writing every byte blindly after startup. Stages wait for observable readiness or screen state before sending the next input. This support is harness infrastructure, not a new production seam.
- Native harness failure reporting becomes structured enough to diagnose failures after the fact: scenario name, phase, elapsed wait, child process exit status when available, expected result, captured terminal transcript, result-file presence and artifact location are reported together.
- Startup readiness, interaction deadlines, child process completion and result-file reading are distinct phases. A missing result file never replaces the original phase failure as the only diagnostic.
- Diagnostic artifacts are retained on failure and removed on success. Process handles, pseudoconsole handles and child processes are cleaned up on every path.
- After diagnostics exist, investigate the intermittent framed-multiline failure. A later passing run alone does not resolve that finding; the result must be either a fixed root cause or a recorded, bounded environmental explanation with the remaining risk explicit.

### Public native lifecycle coverage and CI

- Public native coverage means prompts created through exported theme instances over `TerminalEnvironment.nativeThemeDefault`, not direct component constructors or the internal compatibility barrel.
- Do not merely add a public switch or prefix to existing scenario names. First implement the specialized public fixture behavior needed by the matrix: correct rich/linear interaction selection, initial drafts for cursor and long-line editing, resize draft behavior, repeat/reacquisition, validation recovery, redirected or dumb-output behavior, password help, cancellation/interruption/EOF outcomes, and session retirement with a writer failure.
- The public session-retirement fixture uses theme-owned feedback coexisting with a prompt across the shared session. It must prove that writer failure retires the parked prompt and that native console state is restored.
- Once those routes exist, Windows release scenarios run through the public-route switch and POSIX PTY scenarios pass explicitly public scenario names. Scenario output names identify both route and behavior. Any legacy compatibility native execution that remains is labeled compatibility coverage and is not counted as public lifecycle evidence.
- Native coverage remains focused on behavior that requires a real terminal: acquisition/restoration, console or PTY input decoding, modal help, resize observation, output capability refusal, writer failure retirement and process-signal handling. It does not duplicate every component-level happy path already covered by Dart tests.
- Add a compact public-route lifecycle matrix to the Dart tests only where it exercises behavior through the public seam: reusable prompts, rich/linear outcomes, EOF, cleanup and reacquisition, feedback coexistence and failure recovery. Type-shape factory checks remain secondary and are not a substitute for behavior.
- The platform regression workflow runs the external public API checker as a required step. The positive fixture is analyzed as an external package and negative cases must fail with their expected diagnostic codes.
- The source-level public inventory test stops treating fixture source text as compilation. It may compare export target sets where order is not a contract, while compile acceptance and rejection belong to the external checker.

### Generated files and formatting

- Generated Dart files use UTF-8 with LF newlines as an explicit cross-platform policy. Generation enforces that policy after invoking the formatter, regardless of host newline defaults.
- Git checkout configuration declares LF for generated text targets so Windows `core.autocrlf` settings cannot reintroduce nondeterminism. A one-time normalization of existing generated targets is part of the implementation.
- The generated-diff checker continues to reject content drift. Once both generator output and checkout policy are LF, byte comparison is intentional rather than accidental; do not weaken it into a loose comparison that hides real differences.
- Generated test and theme files are never edited manually. Changes belong in their templates or generators.
- Apply the repository formatter to the files currently failing the formatting gate and keep formatting as a required pre-test gate. Review the resulting diff only to ensure no generated file was hand-edited and no unrelated behavior was changed.

### Test determinism and environment honesty

- Fixed sleeps that merely hope asynchronous work finished are removed from the identified asynchronous prompt and colour-input tests. Tests instead await a controlled provider completion, drain the event queue when that is the actual synchronization contract, or poll an observable output/state condition with a bounded failure deadline.
- MultiSpinner batching tests use the existing `FeedbackClock` seam. A test-controlled clock and timer decide when batching windows elapse; real milliseconds are not part of the behavior assertion.
- Resize tests use the existing terminal resize observer seam. Controlled notification streams drive notification behavior; the polling fallback retains only a small smoke test that waits for the observable reflow condition rather than sleeping for a fixed duration.
- Windows native interactions replace fixed post-key delays with bounded waits for the relevant prompt paint, help screen, dismissal or caret state. Startup waits distinguish console attachment/compilation readiness from interaction responsiveness.
- Platform guards become explicit test-platform declarations or explicit skips with reasons. A bare conditional return is not acceptable in the identified environment-dependent tests.
- CI provisions or controls the locale fixtures needed by numeric-convention and date-profile tests. When an expected fixture is absent in a job that declares that prerequisite, the test fails with a prerequisite diagnostic instead of passing silently.
- Exact terminal escape-sequence assertions remain where cursor placement, secret concealment, alternate-screen behavior or terminal restoration is the external contract. Do not replace them indiscriminately with loose substring checks.

### Documentation, version and release evidence

- User-facing README examples are migrated to the public theme-instance API. Internal compatibility examples are removed from user documentation or moved to contributor-oriented documentation with an explicit internal-test purpose; they are not presented as supported authoring usage.
- README text that still describes supplied answers, invocation-level output/session configuration, direct constructors or other removed public APIs is corrected. Scripted input is described honestly as an explicit stream environment, not as a supplied-answer equivalent.
- The changelog is rewritten for the actual release state: the package rename, the breaking theme-instance cutover, removed APIs, new key gestures, remaining instability and missing human evidence are distinct entries. It no longer claims that direct constructors or invocation configuration remain supported in the public API.
- The package version becomes `1.0.0-dev.1` while the API is unstable and the independent interaction and colour gates remain incomplete. The stable `1.0.0` version is restored only by a later release decision after those human gates pass. This is the consistent prerelease scope because an agent cannot produce the required human evidence.
- The public barrel, migration guide and README continue to state the unstable status during the prerelease, but that status now agrees with the package version.
- The exact `termunicode` pin remains intentional. Prior project decisions require audited Unicode 16 data not to change silently through a dependency upgrade, so the publish warning about an exact constraint is documented as an accepted tradeoff rather than fixed by loosening the constraint.
- The publishing-tool warning about the documentation directory name is also documented as accepted: the Git-backed documentation and issue-tracker layout is intentional project structure and must not be reorganized merely to satisfy a packaging convention.
- Release evidence records both accepted publish warnings separately from failures. Publish dry-run output is evidence, not authorization to publish.
- The independent interaction and colour release gates remain `ready-for-human`. Documentation may say what automated evidence exists, but must not claim stable interaction, accessibility qualification, actual screen-reader usability or real-terminal colour quality until those gates pass.

### Verification sequence for the implementing agent

The implementation is complete only when the following evidence is recorded in the implementing ticket or commit evidence:

1. Formatting, static analysis, documentation-link checking and tracker checking pass.
2. The full Dart test suite passes.
3. The generated-file checker passes byte-identically on the implementing host, with the LF policy in place.
4. The external public API checker passes its positive fixture and every negative case.
5. Windows native TextInput scenarios and the multiline ConPTY scenarios pass through their corrected public or explicitly named compatibility routes, as applicable.
6. POSIX PTY scenarios pass in CI on Linux and macOS through explicitly public routes.
7. The complete platform regression workflow is green on the candidate commit.
8. The prerelease documentation and version agree, and no stable or accessibility claim is made without the required human gate evidence.

## Testing Decisions

A good test observes external behavior through the same seam a caller or user crosses. It does not inspect private decoder state, private harness variables, line ordering that is not contractual, or implementation details that can change without affecting users. Byte-level terminal output is appropriate only where those bytes are themselves the external contract, such as cursor placement, secret concealment, alternate-screen handling or restoration.

The preferred seam hierarchy is:

1. **Public theme-instance seam** — construct an exported structural theme, supply a scripted or native terminal environment, invoke parameterless prompt/feedback methods and assert outcomes, visible behavior and lifecycle effects. This is the highest seam and is the default for new product regressions.
2. **Real terminal harness seam** — use the existing Windows console, Windows ConPTY and POSIX PTY harnesses for behavior that depends on native input events, terminal geometry, process signals, alternate screens or console restoration. These harnesses must exercise the public route when they are counted as public lifecycle evidence.
3. **External package seam** — use the external public API fixture and checker for compile-time public surface acceptance and rejection.
4. **Existing deterministic test seams** — use the existing feedback clock, resize observer and scripted terminal environment adapters to control time, geometry and input. Do not introduce replacement clocks, timers or decoder harnesses.
5. **Generator command seam** — test generated output by running the generators and generated-diff checker, not by asserting incidental source formatting inside generated files.

Modules and behavior to test:

- Multiline rich interaction through the public theme-instance seam: Enter then separately delivered Ctrl+J, trailing blank lines, validation failure preserving the draft answer, same-event CRLF normalization, framed paste with CRLF, and cancellation/interruption remaining distinct.
- The shared terminal reader only where decoder behavior cannot be isolated safely at the public seam. Its tests must assert emitted key gestures and ordering, not private flags.
- Windows native help scenarios: F1 opens component help, repeated F1 does not nest, input is modal, Escape restores the screen and caret, secrets remain hidden, and final outcomes remain correct.
- Windows ConPTY scenarios: framed paste, typed commands, editing, F1 help dismissal, unassigned function keys, application-navigation keys and staged Enter/Ctrl+J input.
- Public native lifecycle scenarios across Windows and POSIX: repeat acquisition, rich interaction, linear interaction where applicable, EOF, cancellation, interruption, validation recovery, resize, redirected output, dumb-terminal refusal and session retirement.
- Generated-file verification on a Windows host and at least one POSIX host in CI.
- Public API compilation through the external fixture, including negative cases for direct constructors, static factories, invocation configuration and supplied-answer types.
- Timing-sensitive feedback and resize behavior through deterministic clocks or controlled notifications, with only small bounded native smoke tests where real polling is the behavior under test.
- Documentation and tracker integrity through the existing doc-link and issue-tracker checkers.

Prior art already present in the repository:

- Public behavior and lifecycle tests in the public theme instance tests.
- Shared reader ownership and paste parsing tests in the shared terminal reader tests.
- Multiline Ctrl+J, validation and paste tests in the multiline tests.
- Theme session cleanup, writer-failure recovery and reacquisition tests.
- Existing feedback clock usage in public theme instance tests.
- Native Windows console, Windows pseudoconsole and POSIX PTY harnesses.
- External positive and negative public API checker fixtures.
- Generated theme factory and acceptance-matrix generators plus the generated-diff checker.

The generated acceptance matrices intentionally use the internal compatibility seam for component-level structural coverage. They remain useful, but they are not public integration evidence and must not be cited as a substitute for the public-route lifecycle checks.

## Out of Scope

- Performing the human interaction or colour release gates. Actual screen-reader use, Windows Terminal + NVDA evidence, macOS VoiceOver evidence and human light/dark terminal visual review remain `ready-for-human` work.
- Claiming accessibility qualification, stable interaction, stable colour behavior or stable public API compatibility before those human gates pass.
- Publishing to pub.dev or creating a real release. Publish dry-run output is evidence only.
- Reorganizing the documentation or Git-backed issue tracker to silence the packaging convention warning.
- Loosening the intentionally exact Unicode dependency pin without a new Unicode-data policy decision.
- Replacing the whole compatibility-path component test suite or duplicating it wholesale through native harnesses.
- Perfectly supporting unframed multiline paste. Without paste framing, a byte stream cannot reliably distinguish paste data from key gestures.
- Designing a third Windows terminal transport for mintty/Git Bash or expanding POSIX platform support beyond the existing best-effort contract.
- Broad refactors of prompt components, structural themes, colour themes or feedback components unrelated to the release-readiness findings.

## Further Notes

- No ADR directory currently exists in this repository; no ADR conflict was found. The exact Unicode pin is nevertheless an established tracked decision in the theming/backend tracker history and should not be reversed casually.
- The chosen seams use existing modules and harnesses. No new production seam is expected; the only new infrastructure should be harness diagnostics/staging and, if needed, shared test helpers that remove duplicated bounded-wait logic.
- The input-event-local CRLF rule is a deliberate tradeoff caused by adding distinct meaning to LF. It fixes the lost Ctrl+J gesture without pretending that unframed byte streams can perfectly distinguish physical keypresses from CRLF data.
- This spec intentionally does not close or modify the existing adaptive-theme interaction and colour gate tickets. It makes the agent-resolvable evidence honest so those human gates can evaluate a coherent prerelease candidate.
