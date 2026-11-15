# Trelis backend-first implementation specification
Status: planned
Acceptance: not verified

## Destination and ordering

Implement and validate the shared output-capability, Unicode measurement, typed rendering, event/input-routing and multi-region session foundation before starting named-theme integration. This is an executable implementation backlog, separate from the completed [theming decision map](../trelis-theming/map.md).

The backend gate is closed until [Accept the backend evidence gate](issues/16-backend-evidence-gate.md) is resolved against actual evidence. Creating this specification or passing only unit tests does not open it. The [theme integration handoff](../trelis-theme-integration/spec.md) remains blocked behind that gate.

No runtime work or dependency integration was performed to create this handoff. All requirements below start unverified.

## Authoritative design inputs

Do not copy behavior into theme implementations or reopen resolved choices. Consult the linked resolution for the exact contract:

- [Define compact guidance and full help for every component](../trelis-theming/issues/01-component-help-contract.md).
- [Define the declarative component presentation boundary](../trelis-theming/issues/02-declarative-presentation-boundary.md).
- [Specify structural-theme factories and colour configuration](../trelis-theming/issues/03-static-theme-api-and-colours.md).
- [Specify rich and linear presentations for the existing structures](../trelis-theming/issues/04-rich-and-linear-structure-contracts.md).
- [Specify the internal typed presentation and layout vocabulary](../trelis-theming/issues/06-internal-presentation-vocabulary.md).
- [Specify shared output capabilities and display measurement](../trelis-theming/issues/07-output-capabilities-and-measurement.md).
- [Specify shared multi-region output composition](../trelis-theming/issues/08-multi-region-output-composition.md).
- [Source API baseline](../trelis-theming/api-baseline.md), [expanded factory signatures](../trelis-theming/factory-signatures.md), and [current help inventory](../trelis-theming/help-inventory.md).
- [Primary-source capability/width research and executable probe findings](../../doc/research/trelis-output-capabilities-and-width.md).

Baseline production source revision: `80f4752e16a6e3b2451f2b87b9450e535ae3fa30`. Revalidate the inventory against the actual implementation revision. Do not overwrite unrelated working-tree changes or existing scratch/evidence artifacts.

## Scope

Build the shared modules and migrate the 38 existing components to them using a plain reference presentation. That reference path is necessary to exercise the backend with real components; it is not permission to roll out all fifteen named structural factories/layouts before acceptance. Implement backend-facing colour/semantic types where needed, without shipping the whole named palette/theme surface early.

Preserve answer types, command/literal/paste semantics, callback contracts, async freshness rules, explicit outcomes and feedback lifecycle. Public invocation additions are outputProfile and session as applicable. Constructor-facing presentation configuration follows the approved source-compatible interface; signature notation in the planning assets is not already implemented code.

The implementation has one active prompt and multiple feedback regions in explicit TerminalSession.run scopes. No multi-prompt focus manager, public grid/widget framework, automatic shared screen, package/import rename, global theme state or fabricated job outcomes.

## Tracker and execution conventions

Individual tasks live in issues/. Status is open, claimed or resolved. Blocked by contains local numeric file prefixes; a task becomes takeable only when all blockers are resolved. Claim before work, record validation/evidence on the task and resolve only when its acceptance is met. The dependency lists in tasks are authoritative; [dependencies](dependencies.md) is navigation.

Parallelizable dependencies do not authorize concurrent edits to the same shared Dart library without coordination. Keep commits/slices independently reviewable and retain a working public test seam. Do not wholesale regenerate snapshots to hide behavior regressions.

## Acceptance matrix

Each requirement needs an evidence pointer in the final gate report. A listed command, configured workflow, old report, skipped test or package source audit is not a current pass.

### B-BASE

Capture current public behavior, commands, source/inventory revision and relevant historical limitations. Run available baseline checks without changing production behavior. Classify failures/pending environments honestly and establish deterministic output, environment, clock, geometry and failure injection. Follow Dart part files, not just the public export. Existing unrelated artifacts are not disposable baseline noise.

### B-CAP

One resolver serves prompts and feedback. Test invocation/source/legacy/detection precedence, independent cursor/style/colour/glyph facts, selected stderr/stdout ownership, unknown and failed size queries, invalid declarations, dumb/redirected output and NO_COLOR absent/empty/nonempty. Profiles cannot bypass hard restrictions; supplied answers do not acquire a terminal. Rich-required versus automatic failure behavior remains explicit. Synthetic rich fixtures declare positive geometry; no invented virtual 80x24 screen.

### B-MEASURE

Pin termunicode exactly at 0.2.0 and document Unicode 16 basis, license and archive/lock evidence. Use its public scalar/property APIs behind the internal adapter and existing characters segmentation, not widthString/widthChars blindly. Freeze and test the supported cluster policy, visible escape representation and tab expansion policy before relying on them in layout. Cover ASCII/accented/decomposed text, CJK, narrow/wide ambiguity, combining-only/standalone format content, flags/modifiers/ZWJ, VS15/VS16 and keycaps with/without selectors, controls/bidi/tabs/newlines and unsupported sequences. Verify original-grapheme-to-display/caret mappings as well as widths; raw primitive width is not encoded display width. Keep hidden data out of geometry. Record terminal/font limitations instead of asserting universal agreement.

### B-RENDER

Use immutable typed bodies, semantic slots/styles and dedicated editable regions. Test actual composition inside bodies, wrapping of read-only content, caret-centred scrolling, stable geometry and structural chrome accounting. Insert omitted protected content into the shared safety area while declaration tests still flag the omission. Test opaque RGB/indexed/default colours, deterministic conversion/tie-breaking, complete immutable colour objects, component-local backgrounds and style restoration. Redirected real streams have no ANSI; explicit synthetic recording fixtures are distinct.

### B-EVENT

Current view and ordered presentation events are separate. Repaint/no-op/resize does not duplicate history; fresh help/validation occurrences are preserved despite identical text. Maintain region/source identity and ordered delivery across producers. One session-owned scripted reader/router supports sequential prompts without closing/resubscribing or losing buffered input, literal-command quoting or paste provenance. Do not infer submission or feedback success from snapshot diffs.

### B-SESSION

Implement TerminalSession.run/session attachment, typed configuration inheritance, standalone temporary sessions and ownership conflict errors. Acquire input lazily; allow one prompt plus many feedback regions; reject a second active prompt before input consumption. Serialize writes and retain stable registration order with prompt at the bottom. Preserve logical caret while regions move. Closed/retired generations cannot write or revive. Validate native/output alias limits honestly, not through assumed object equivalence.

### B-FEEDBACK

Preserve Progress/Spinner/MultiSpinner/Text task semantics, cadence and outcomes. Progress reaching its total is not success. Disposal and scope exit do not cancel application jobs or invent completion/failure/cancellation. Explicit outcomes commit once and remove the live region. MultiSpinner's existing all-task completion behavior remains intentional. Coordinate Text messages without corrupting an active editor.

### B-PARITY

Retain task and result coverage for all 34 interactive and 4 feedback components, including generics, decimal-string sliders, nullable number/colour answers, records and distinct cancelled/interrupted/input-ended/unavailable paths. Use distinguishable defaults, limits, validation and callbacks to detect forwarding mistakes. Preserve async generation/closure gates, source-stable SearchSelect references versus response-local Autocomplete candidates, segmented incomplete drafts and reserved key-capture behavior.

### B-HELP

Implement the component-help contract across families and stages, not only generic editor help. Include missing rich help paths without stealing capture gestures or turning literal secrets into commands. Show applicable primary actions/help access; preserve essential format cues, warnings, validation and review actions under every instruction policy. Full help is current-stage-first with broader formats/workflow available. Supplementary help augments rather than replaces built-ins. Maintain draft/focus/caret through help and fallback.

### B-SECRET

Use synthetic canaries, never real secrets. Test unmasked Password and hidden drafts without raw text/length/caret leakage into projections, frames, history or diagnostics; optional masking and prefill warnings stay explicit. Preserve generic secret-validator failure behavior. Do not stringify accepted values automatically or claim URL path/query/fragment is universally redacted: assert each component's approved output policy. Safely encode user/application control/bidi text without changing answer data.

### B-RESIZE

Exercise idle resize, coalescing, safe unknown/zero geometry and teardown of notifications/polling. Shrink padding/chrome and compact background feedback before the active prompt; preserve full important notices in history and truthful visible indicators. Preserve state during deferred geometry-dependent painting, with no duplicate transcript events or lost input. Test actual repaint/caret placement rather than only size arithmetic.

### B-MODAL

Session-wide help owns painting/alternate-screen transitions while background jobs keep updating. Dismissal restores the latest composite and valid prompt state, not a stale screenshot. Important notices survive modal intervals. Test unsupported temporary-screen transcript help, capture/secret exceptions and interruption/EOF/error exits.

### B-FAIL

Inject registration, local rendering, shared write, acquisition/restoration and callback failures. Isolate local faults where possible; a failed shared writer closes safely. Drain/retire registrations, stop watchers, release leases and restore received terminal state on every supported path. Preserve original failure context if cleanup also fails. Assert late updates cannot write after closure. Do not promise restoration after forcible process kill or unmanaged external mutation.

### B-COMPAT

Compile/check public additions against the source inventory, following part files. Keep direct constructors supported and invocation modes/results unchanged except documented migrations: shared session/profile options, explicit geometry for synthetic rich, plain/terminal-native default presentation, and deliberate instruction-copy/layout changes. Update examples/README/CHANGELOG truthfully, without a package rename. Review transcript changes against semantic assertions, not blind golden replacement.

### B-PLATFORM

Require fresh automated checks for Windows, Ubuntu and macOS CI runners at the accepted revision. Linux/macOS verification is CI-only: run real native PTY tests inside those runners; do not require physical access, human confirmation or local GUI checks on either platform. Windows has CI/native checks plus the local agent GUI evidence below. CI must exercise the new capability/session/resize/measurement paths, not just an unchanged legacy script. Keep run URLs/artifacts, runner/SDK versions and logs. A configured workflow or syntax-only Python compilation does not satisfy native execution.

### B-GUI

An agent uses the installed computer-use skill/version-matched guide to exercise a visible Windows terminal running the new backend. Cover keyboard editing, caret movement, concurrent feedback/informational writes, help/dismissal, narrow/idle resize, ASCII/no-colour fallback, secret-entry non-disclosure and cleanup/repeated sessions using synthetic data. Capture screenshots and expected-versus-observed notes at checkpoints; inspect NVDA speech where available and explicitly record absent/unavailable speech evidence. Agent-generated input is automation, not physical keyboard/human usability evidence. No human checkpoint is required, and this gate does not qualify whole-library accessibility. If visible GUI/tooling is unavailable, report the gate blocked; do not substitute only unit tests or mark it passed.

### B-GATE

A final audit checks every requirement, task resolution and evidence link at one accepted source revision. Re-run affected evidence after changes; stale successful runs cannot cover a newer backend. Record pending/failures and carry historical limitations forward. Only an explicit passed backend gate unblocks the separate theme integration handoff. It does not grant a release-wide accessibility claim.

## Evidence record

For each requirement record: status (pass/fail/pending/not-applicable with justification), source revision, date, environment/OS/terminal/SDK, selected input/output, mode and effective profile, relevant TERM/COLORTERM/NO_COLOR/geometry and width policy, command/scenario, expected/actual result, logs/screenshots/CI artifact URL and limitations. Use synthetic sensitive values and avoid copying them into user-facing runtime output. Do not count intended test counts as executed results.

Store implementation reports under doc/evidence/trelis-backend/ (or linked CI artifacts), with a final backend-acceptance.md report. The planned directory/report is not evidence until created by execution. Agent GUI evidence should include tool/version and input-generation method. Record NVDA version/configuration and speech source only when actually observed.

## Existing commands to retain and extend

```text
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart run tool/check_doc_links.dart
dart test --reporter expanded
dart test test/component_acceptance_matrix_test.dart --reporter expanded
python3 test/posix_terminal_pty.py
powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario <scenario> -Report <report-path>
powershell -NoProfile -ExecutionPolicy Bypass -File test/multiline_conpty_windows.ps1
```

The current .github/workflows/platform-regression.yml uses Dart 3.13.2 and all three OS runners. Extend its scenarios for new backend behavior. Existing Windows scenario/wrapper coverage is not exhaustive. Preserve exact native state received by the application, recognizing that the Dart launcher may already have changed state before main. Old reports, the known historical unexplained rich-input discrepancy and outstanding broad NVDA baseline are limitations to record, not fresh passes or blanket permission to waive regressions.

## Out of scope and next handoff

Named-theme rollout begins only after B-GATE. Its [separate handoff](../trelis-theme-integration/spec.md) defines the all-component/all-structure verification matrix and palette checks. Multiple interactive prompts, public grids, package renaming and whole-library accessibility qualification remain out of scope. No physical Linux/macOS check and no human verification appointment are required by this backlog.
