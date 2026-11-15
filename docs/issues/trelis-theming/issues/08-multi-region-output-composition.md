# Specify shared multi-region output composition
Type: grilling
Labels: wayfinder:grilling
Status: resolved
Assignee: bvlou
Blocked by: 07

## Question

bvlou explicitly requires multiple live regions on one output, not a single-live-region restriction. How should a single stream-owned screen compositor register, arrange and update those regions while preserving the approved typed presentation, capability profile, caret, help and linear-history contracts? Define its public/session interface, region and frame identity, layout/size allocation and resize/overflow behavior, focus and input ownership (including whether multiple simultaneously interactive prompts are supported or only one prompt plus feedback), modal help/review and alternate-screen behavior, coordinated informational writes, profile/geometry conflicts between region requests, per-region lifecycle and failure isolation, output acquisition/restoration and teardown, and compatibility/migration from existing prompt/feedback entry points. Distinguish multiple live regions from independent concurrent terminal writers and from a public custom-layout framework. Backend capability/measurement and this compositor must be implemented and validated before theme integration. Define an implementation-ready contract and evidence requirements; do not implement it in the design map. Consult grilling, domain-modeling, codebase-design and Dart.

## Answer

Approved by bvlou through live decision rounds and explicit final confirmation of the TerminalSession interface and compositor contract. This resolves the required multi-region backend design, not its implementation.

### Scope

Support one interactive prompt plus multiple independently updating feedback regions in an explicit shared session. Do not implement several simultaneously interactive prompts, a cross-prompt focus manager, public grid/positioning or a general widget framework in this effort. Several regions never means several independent terminal writers.

Chosen policies: explicit sessions, automatic vertical stacking, session-wide modal help, prompt-priority overflow with important notices preserved, and outcome-neutral disposal of unfinished feedback.

### Public session interface

Expose TerminalSession.run<T> as a scoped asynchronous entry point. It accepts a FutureOr<T> Function(TerminalSession) callback, selected output, optional scripted source, mode/preferences and OutputProfile, and returns Future<T> containing the callback's result after coordinated output and cleanup. Session handles are supplied by run, not constructed as competing terminal owners.

The typed configuration shape is:

- StringSink? output; default to the scripted source's output when provided, otherwise stderr.
- ScriptedInput? source; absence permits the existing native-input path when a prompt actually needs input. Literal supplied answers remain per-component headless calls, not a reusable shared byte source.
- PromptMode? mode, userPreference and applicationPreference with existing precedence.
- OutputProfile outputProfile with automatic default and previously resolved source-profile inheritance.

If both output and a scripted source output are supplied, they must identify the same supported destination; reject conflicting destinations rather than reading one source and drawing elsewhere by accident. A valid input adapter remains required for interactive prompts; a feedback-only session does not acquire stdin.

Add session: to prompt(), Text.present() and feedback start(), not component constructors or structural-theme factories. The handle is a capability to join that session's coordinated output, not an independent renderer.

Attached invocations inherit output/input/mode/profile from the session. Non-default competing source/output/mode/preferences/profile or legacy capability configuration is an ArgumentError; do not negotiate conflicting physical output facts per region. Default/automatic parameter values do not count as competing explicit configuration. Per-component structural theme, colours, instructions and supplementary help remain independently configurable because those are presentation choices, not physical output ownership.

Example of approved interface (not implemented code):

```dart
await TerminalSession.run(
  (session) async {
    final status = PlainTheme.spinner('Background work');
    status.start(session: session);
    // Application-owned work updates and explicitly finishes status.
    return await RailTheme.textInput('Project name')
        .prompt(session: session);
  },
  output: stderr,
  outputProfile: profile,
);
```

The example's comment is significant: cleanup does not infer a successful result for the background work. Component factories and construction remain output-free.

### Standalone compatibility

Existing standalone prompt/present/start calls remain available and use temporary sessions through the same implementation, not a legacy renderer. A standalone feedback object's temporary session lasts until its explicit terminal lifecycle/disposal; MultiSpinner retains its existing all-tasks-finished behavior.

Do not automatically join an unrelated existing session merely because an output matches. A conflicting standalone/shared owner is rejected with a clear StateError telling the application to attach to the existing session. A small ownership registry is a guard, not an implicit global screen or shared mutable theme configuration.

Coordinate aliases where the backend can identify them; do not promise that arbitrary opaque sink wrappers or separate handles targeting the same physical terminal can always be inferred. Applications must use one shared session for writers to the same actual presentation. External processes and arbitrary print/Stdout.write calls bypassing the compositor remain outside the supported coordination guarantee.

The new shared run interface reports unusable explicitly requested output configuration as StateError before calling its body, consistent with a scoped output/session operation. Standalone prompt failure shapes and attached prompt input failures retain PromptResult semantics; feedback start retains StateError where already specified. No new successful result or task outcome is invented.

### Registration, identity and serialization

The session owns one stream-specific effective capability/profile context, terminal output acquisition, resize observation and serialized writer. The native backend remains the single mode/restoration owner; regions do not independently toggle VT, reset styles or open alternate screens.

Invocation implicitly registers the component's live region. Each registration has an opaque session-local identity and lifecycle generation, separate from its label or component value. Preserve stable registration order. A new invocation is a new registration even if a component instance/label is reused.

Compose the latest typed snapshots into one physical frame. Coalesce redundant repaint work, but preserve ordered semantic notices/outcomes. Global delivery order distinguishes events from different regions; repeated source event identities are not printed twice. Late/stale updates from a retired generation cannot resurrect its region or write after session teardown.

Any repaint restores the active prompt's physical caret from its logical editable-region anchor after all region positions are recomputed. Feedback updates cannot become key input, change focus, submit the prompt, or force the editor to reconstruct a draft from displayed text.

### Layout and overflow

Stack feedback above the active prompt in stable registration order. The prompt remains at the bottom of the live area. Each structure keeps its own internal framing and width rules; the session allocates a bounded region rectangle, not absolute positions chosen by the caller. New/removed feedback may move the prompt physically without changing its logical state.

At constrained heights, prioritize the active editor/caret, essential prompt context and required actions. Reduce feedback padding/chrome and compact lower-priority running feedback into labelled summaries before sacrificing prompt usability. Group remaining background state into an explicit summary when necessary; do not imply hidden work has completed. Registration order remains stable rather than constantly resorting by transient numeric progress.

Important warnings/errors/outcomes are emitted in full as coordinated reviewable history and retain relevant visible severity indicators when live content is compressed. They must not disappear into help or be silently truncated. When essential content itself exceeds the live area, preserve its full notice in history and a truthful visible cue near the active prompt. Terminal scrollback is a review path, not a new session-key navigation mode. Do not reserve scrolling keys that collide with the prompt's controls.

Normal sessions manage an owned live block and append history without clearing unrelated terminal content. Full-terminal alternate-screen behavior is limited to coordinated temporary help where supported, not a separate fullscreen screen per region. Unknown/zero geometry follows the capability contract: no guessed cursor placement; preserve logical state and safe history until a valid frame can be laid out.

### Input ownership

At most one attached interactive prompt is active. Reject a second overlapping prompt with StateError before consuming keys or acquiring another input lease; do not silently queue it or broadcast input. Feedback-only regions have no keyboard focus.

Acquire native input lazily for the active prompt and release its lease when the prompt ends. The session owns input routing/source lifetime so sequential prompts can consume one scripted stream in order without each region closing/re-subscribing the underlying source or dropping buffered source data. Preserve existing physical-input exclusivity across sessions; output profiles do not make concurrent stdin readers safe.

Input decoding, command/literal/paste provenance, cancellation/interruption and secret handling remain behavior-owned. Escape/help dismissal and capture exceptions follow the component-help contract. Cancellation/interruption returns the active prompt's existing result; the application's callback decides whether to continue, stop its jobs or end the wider workflow. No automatic job cancellation, global key broadcast or new application-level cancellation-token framework is introduced.

A native session with no active prompt does not claim input on behalf of feedback. Do not silently replace the application's normal process/signal policy with an invented feedback keyboard loop.

### Modal help and review

Only the session coordinates temporary help and alternate-screen transitions. Full prompt help is session-modal: pause ordinary live painting, not application work. Regions continue updating their latest state and reporting meaningful notices. Dismissal paints the latest composite screen and restores the prompt's logical stage/focus/caret rather than replaying a stale screenshot.

Preserve ordered significant notices during the modal interval; they are not lost just because numeric snapshots can coalesce. If temporary screens are unsupported, use the established transcript-help path through the same writer and resume safely. Feedback must not paint through the help text while it owns presentation. Required review/action stages remain part of the one prompt, not independent keyboard-owning regions.

### Coordinated informational output and linear mode

Text.present(session: session) writes a semantic informational block through the session writer, above/reconciled with the live area, and restores the latest active frame/caret. It is not a second live keyboard region. User labels/text remain safely encoded display content, not raw terminal instructions.

In linear mode, all regions share the same ordered writer and emit labelled event blocks with no cursor operations. Region identity/label makes interleaved status notices attributable. Meaningful progress cadence remains behavior-owned; neither repaint scheduling nor another region's update duplicates an earlier transcript event.

### Completion, failure and scope exit

An explicit feedback outcome is committed once to history, then the region leaves the live stack. Completed counters alone do not finish a region. Text/status messages do not change another region's lifecycle.

The callback's normal return or exception ends the scope: drain coordinated output, retire remaining registrations, dispose presentation/watchers/subscriptions, release input leases and restore owned terminal state/styles. Unfinished feedback retains/reports last-known or unfinished state; do not convert disposal into completed, failed or cancelled. The compositor neither cancels underlying application jobs nor waits for unregistered jobs forever. Callback exceptions propagate after cleanup; cleanup failures must remain observable without losing the original failure context.

Distinguish region-local presentation/behavior failure from shared writer/native-output failure. A local region fault is isolated/retired with safe diagnostics and the applicable existing prompt/lifecycle error shape; do not erase unrelated state or fake an operation failure outcome. A broken shared output or compositor invalidates the session: stop unsafe painting, release all owned resources and surface the failure. No stale generation may write through a closed handle.

New operations through a closed session are StateError. Previously retired component updates follow their existing finished/disposed no-op rules and cannot revive output. Terminal restoration is required on supported normal/error paths, not an impossible guarantee after forcible process termination or unmanaged external terminal mutation.

### Acceptance and handoff implications

Backend-first acceptance must exercise one real/synthetic input owner with many independently updated feedback regions, stable registration/removal, progress cadence, caret preservation during repaint, selected-output ownership/conflicts, sequential scripted prompts without source loss, mode/profile inheritance, standalone behavior, modal help during concurrent updates, narrow/short/zero geometry, full notices plus compressed summaries, linear event order/idempotence, local fault isolation, shared write failures and teardown on every prompt outcome/callback error.

Explicit session tests must distinguish disposing unfinished presentation from cancelling/completing application jobs. No dependency/theme integration is authorized by merely resolving this design.

[Define theming acceptance evidence and the implementation handoff](05-verification-and-design-handoff.md) is now unblocked and must make capability/measurement plus compositor implementation/validation prerequisites to theme integration. No new unresolved decision ticket surfaced.
