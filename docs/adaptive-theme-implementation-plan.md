# Adaptive theme API: implementation plan

**Status:** Planning only. No implementation is authorized by this document. The behavioral decisions and release gates live in [the design](adaptive-theme-accessibility-design.md); research is in [screen-reader detection and locality](../assets/research/screen-reader-detection-and-locality.md). Names below are illustrative, not finalized public signatures.

## Target experience

```dart
// Illustrative only: these types and arguments are not yet the public API.
final theme = RailTheme(
  interaction: interactionPreferences,
  colors: colorPreferences,
  selectionStyle: selectionStyle,
  io: terminalEnvironment,
);
final name = theme.textInput('Name', colors: componentColors);
final answer = await name.prompt();
// Resources are released automatically when the last active component ends.
// Feedback components retain appropriate methods such as present/start.
```

A theme instance captures app-level configuration, fixes the structure, owns one I/O environment, and automatically manages shared resources during active component work. There is no public theme close method. Allowed named overrides belong to the component-creating methods, not `.prompt()`. A prompt is parameterless and may run sequentially more than once, starting from its configured initial value. One active prompt and coordinated feedback are allowed; overlapping active terminal ownership across themes must be rejected where the environment can identify the same terminal. Supplied-answer shortcuts and public direct component construction are removed with migration guidance; scripted input remains supported, but is not necessarily equivalent.

This is a **breaking package-wide change**: all 15 theme classes, 34 interactive component factories, four feedback factories, invocation signatures, tests, examples, and consumers need a coordinated cutover. No permanent second static API is planned. Existing preference prototype code is internal and does not yet implement the reviewed contract.

## Remaining design decisions adopted for planning

These fill in implementation details without changing the agreed behavior:

- Use immutable interaction and color preference values, a separate component-color override value composed inside theme colors, and an immutable resolved-interaction value. Keep state-machine transitions internal. Component methods accept only permitted overrides.
- Give I/O environments an explicit ownership identity for coordination. Native terminal environments should identify the actual selected native terminal where safely possible; custom environments should provide a stable shared identity when they wrap the same resource. Distinct unidentifiable wrappers cannot be guaranteed to refer to the same physical terminal: document this limitation rather than claim universal detection.
- Acquire shared resources lazily when an active period begins and restore and release them automatically when its last active component finishes. Prompts do not stop independently active feedback; feedback ends when stopped, completed, or failed. Serialize a new start racing cleanup, preserve committed outcomes, and report cleanup failures without silently losing a primary failure. There is no public theme close. Caller-owned streams are not closed by default, though cancelling a subscription can still invoke the stream's cancellation behavior; document and test that distinction.
- Resolve theme-wide interaction once per active period via a common asynchronous first-operation path, including feedback-first usage. An explicit screen-reader-on / rich-mode conflict prevents prompt and feedback output; unavailable explicit rich mode yields the existing `Unavailable` prompt outcome or a clear feedback error. Feedback `.present()` / `.start()` retain their names but may become asynchronous. After relevant availability checks, invoke the optional callback at most once per active period before first rendering; publish the value only after callback success and clear it after cleanup. A callback failure propagates after cleanup; a later invocation may start a fresh active period. Resolution does not itself assert screen-reader usability.
- Perform no implicit preference mutation: configured initial values, interaction preferences, and overrides are captured at creation. Component color overrides replace or layer over app values as described in the design; they cannot change background detection. Preserve hard `NO_COLOR` at the final output boundary.
- Treat exact public type names, cleanup error types, and concrete terminal identity mechanisms as implementation details to be verified against real callers and Dart constraints. Where evidence disproves a proposed detail, revise the plan rather than inventing an incompatible public contract.

## Dependency-ordered phases

Each phase must leave the repository buildable and tests passing. Work can span multiple logical changes; the breaking public cutover must update its consumers in the same buildable change set rather than leaving examples or generated code broken. The user explicitly deferred the earlier standalone editor-safety audit and generalization: do not begin those as separate preliminary phases. Preserve existing work; validate and address safety requirements when the affected component families are migrated, and do not claim those requirements complete until verified.

### 1. Internal configuration and resolution

- Replace or adapt the internal combined prototype into separate immutable interaction, theme-color, and component-color values, without publishing an incomplete API.
- Implement deterministic internal resolution: rich/linear plus a validated screen-reader flag; separate unavailable and conflict outcomes; affirmative app/native hints; explicit preference precedence; app/component palette layering; light/dark fallback; output color-depth degradation; and hard `NO_COLOR`.
- Preserve existing prototype tests as evidence, but replace legacy palette-precedence expectations with tests for the reviewed rule: a whole component palette replaces the effective app palette including app role overrides.
- Test all combinations with injected facts; do not call native APIs or query terminals in these tests.

**Exit:** resolver behavior is tested independently, impossible interaction combinations are rejected, and existing public calls still work during this internal phase.

### 2. Theme-owned environment and lifecycle foundation

- Introduce an internal theme owner that adapts `lib/src/terminal_io.dart` and the shared reader/feedback machinery in `lib/src/text_input.dart`. One I/O environment associates input, selected output, `OutputProfile`, acquisition/restoration, and ownership identity.
- Implement automatic last-component cleanup and restore coordination; preserve Windows native stdin handling and per-invocation leases. Test simultaneous primary/restoration failures and a new start racing cleanup; do not depend on garbage collection or a public theme close.
- Define and test async initialization for feedback-first and prompt-first usage, including unavailable operations, query failure, cancellation during initialization, and callback failure; do not emit feedback before a required background query has resolved or safely fallen back.
- Keep internal delegation from composite prompts distinct from a second external prompt so wrappers do not trip the concurrent-prompt guard.
- Route feedback through the owner; cancel producers/timers as well as retiring screen regions. Preserve modal help, resize, short-screen, failed-writer, and restoration behavior.
- Test sequential reuse and initial-value reset, EOF as `InputEnded`, concurrent prompts, prompt completion while feedback continues, last-component cleanup, reacquisition and re-detection in a later active period, callback failure, selected-output identity, two themes on one terminal, and caller-owned streams. Document cases where two wrappers cannot be identified as the same physical terminal.

**Exit:** lifecycle and feedback behavior are validated on scripted/fake environments without exposing a partial stable interaction API.

### 3. Coordinated public API and migration cutover

- Convert the 15 structural theme namespaces to instances with optional named interaction, color, selection-style, I/O, and callback configuration. Replace static component factories with instance methods and create all components through themes. Dart privacy is library-scoped: design a compilable construction seam, such as internal implementations behind public component interfaces or appropriate library reorganization, instead of assuming separate theme libraries can call private constructors. Test theme-created return types from an external-package fixture and verify direct construction is not publicly available.
- Bind components to their theme owner. Remove public invocation-time presentation, mode, source, output, profile, terminal, and session configuration; preserve the appropriate parameterless `.prompt()`, `.present()`, or `.start()` entry points. Ensure public result, choice, and value types remain usable even when constructors become internal.
- Remove the public `SuppliedAnswer` and `SuppliedTags` paths and direct component construction. The migration guide must explain moving existing answers into application logic where appropriate, or using a scripted environment where its behavior is suitable; do not describe scripted input as identical.
- Update `tool/generate_theme_factories.py`, `tool/generate_theme_tests.py`, generated theme files/tests, public export and negative API inventories, wrapper/delegated components, README, all `example/` scripts and support code, tool scripts, and native fixtures together. Examples should demonstrate automatic component cleanup, explicit completion of live feedback, defaults, and explicit color overrides; do not call a theme close method.
- Keep this change marked unstable until the interaction and color gates below are met; do not claim support across components based solely on the new signatures.

**Exit:** all 15 themes and all component families compile through the new public construction path; old static/direct/invocation-configuration paths are no longer public; migration documentation and tests pass. This is an unstable signature cutover, not a claim that the complete state, help, safety, or accessibility behavior has shipped. Preserve known safety behavior and tests while families migrate; phase 4 verifies and completes the designed behavior.

### 4. Presentation, help, and adaptive palettes

- Apply the chosen composable state vocabulary, single-selection style configuration, visible locked/unavailable reasons, focusability, default and disclosure indicators, and status labels. Audit each family rather than assuming the shared choice renderer covers all components.
- Implement essential rich bottom hints and screen-reader top instructions, component-safe help routes, expanded-instruction overrides, short-terminal priorities, and preserved drafts/focus/caret. Apply the agreed literal command/paste and short-limit behavior while migrating each relevant editor; verify independently of any earlier experimental fix.
- Author theme-specific light/dark default palettes following the approved Atelier/Sepia direction and recorded accent mapping. Preserve terminal backgrounds by default. Test authored known normal-text pairs against the 4.5:1 reference target; do not claim this guarantees actual terminal contrast.
- Update examples to demonstrate defaults rather than accidentally making their current per-component atlas palettes the defaults; include explicit overrides separately.

**Exit:** all component families demonstrate the designed rich/linear and state behavior in automated tests; palette and role layers, monochrome and ASCII cases, and contrast-reference checks pass. Actual accessibility and terminal checks are still required.

### 5. Native detection and coordinated background query

- Implement injectable screen-reader and locality observations first. Target documented Windows and macOS hints only where native bindings and real platform checks pass; Linux remains unknown until a suitable signal is established. Apply the agreed conservative remote/multiplexer/container heuristic, no container-detection subprocess, explicit overrides, and non-vetoing negative/unknown hints.
- Add an OSC background-response router owned by the existing input reader, not a competing stdin subscription. Query only eligible interactive color output with querying enabled. Preserve unrelated bytes in order, bound waiting with a fixed timeout, handle malformed, partial and late responses, and cache once per active period. Prefer explicit selection, then a valid response, then passive hints, then dark fallback.
- Test no-color and redirected output, timeouts, partial/late replies, keyboard and paste interleaving, SSH/multiplexer/container ambiguity, acquisition failure, and cleanup. Validate real native terminals and platform bindings separately from synthetic tests.

**Exit:** each native hint is enabled by default only after its platform binding and actual reader check; unsupported/failing queries remain unknown and nonblocking. Background detection never steals user input or blocks indefinitely in tested scenarios.

### 6. Release gates

- **Interaction API:** consistent across all interactive prompt families and theme-owned shared feedback; automated tests and actual screen-reader testing, including Windows Terminal + NVDA; document untested platforms and Narrator detection limitations. The approved ticket graph also requires both Windows and macOS native hints to be validated and enabled before this full gate passes; a missing platform blocks the gate, not unrelated implementation.
- **Color API:** independent gate covering theme defaults and overrides, `NO_COLOR`, output depth and background fallback, known contrast pairs, real-terminal visual review, and documented limitations.
- Run full formatter/analyzer/test suites, issue-tracker boundary checks if tracker work is created, generators and generated-diff checks, example compilation, native fixtures where available, and migration-document review. Record unperformed platform/human checks honestly; they cannot be replaced by synthetic tests.

## Working-tree and migration precautions

The current working tree contains substantial pre-existing changes, plus the explicitly internalized prototype, design document, research note, and throwaway palette study from this discussion. Inspect the index and working tree before each change; do not reset, overwrite, or commit unrelated work. The throwaway visual study is evidence, not a production theme. Decide its eventual archival only after the design and issue-tracking workflow warrant it; no branch or commit is created by this plan.

## Primary implementation seams

- `lib/src/text_input.dart`: current session, reader, prompt execution, editor and input parsing.
- `lib/src/terminal_io.dart`, `lib/src/output_profile.dart`: I/O leases, output capabilities and restrictions.
- `lib/src/feedback.dart`: one-shot and live feedback lifecycle.
- `lib/src/themes/`, `lib/src/color_theme.dart`, `lib/src/prompt_structure.dart`: generated theme factories, semantic colors and structures.
- `lib/trelis.dart`: public API and export boundary.
- `tool/generate_theme_factories.py`, `tool/generate_theme_tests.py`, `tool/generate_color_themes.py`: generators that must not reintroduce old APIs.
- `test/terminal_session*_test.dart`, `test/terminal_io_test.dart`, `test/public_compatibility_inventory_test.dart`, theme matrices, component tests and examples: migration and regression coverage.
