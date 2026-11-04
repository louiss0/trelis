# Choose Trelis’s shared accessible interaction contract

Type: grilling
Labels: wayfinder:grilling
Status: resolved
Blocked by: 01, 02, 03
Assignee: primary-agent
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Answer

Confirmed by the human after live discussion. This is the shared design contract, not evidence of implemented support.

### Modes and equivalence

- Every interactive component has rich and linear interactions with equivalent task outcomes, not necessarily identical gestures or visuals. Feedback components provide stable textual output.
- Rich interaction updates prompt state in place. Linear interaction uses sequential, reviewable questions and answers; it is not synonymous with noninteractive operation. Neither mode is presumed accessible without testing.
- Choose the mode before starting: current explicit user choice → saved user preference → application preference → automatic selection. Applications respect stronger user choices rather than silently overriding them.
- Automatic selection prefers rich only when required interactive terminal capabilities are available, otherwise linear. Capability detection is not screen-reader detection. Exact capabilities remain subject to validation.
- Explicitly requested rich mode fails clearly before prompting if its requirements are unavailable; suggest automatic or linear rather than silently downgrading.

### Streams and input availability

- Prompt text and feedback use stderr by default; callers may select streams. Stdout remains application-owned.
- Check capabilities on the actual prompt output stream independently of input. Redirected prompt output is stable text without cursor addressing or animation.
- Missing/redirected interactive input requires explicit caller policy: supplied answers or an opted-in line-input source. Do not consume pipes automatically, open a controlling terminal implicitly, or silently choose defaults.
- Exhausted input returns a distinct input-ended outcome; do not treat EOF as cancellation or submission of partial input/defaults. This contract does not select Dart result types.

### Actions

- Escape dismisses the current transient layer first; at the root it cancels the prompt. Ctrl+C interrupts the whole prompt from any layer, whether delivered through key input or process control.
- Cancellation and interruption do not accept an answer. They are distinct concepts, not an instruction for the library to terminate the application.
- Linear mode also requires a discoverable, collision-safe cancellation action besides Ctrl+C. Its shared command/literal-input grammar remains a separate decision; reserving a token without a literal escape route is unacceptable.
- Enter normally accepts/submits, with explicit component exceptions for activities such as newlines, tags, suggestion acceptance or directory navigation. Tab performs the advertised completion or internal traversal.
- Components explain overloaded keys and provide discoverable submission paths without mandatory enhanced key protocols. Printable input remains text while editing, not a global shortcut.
- Essential tasks cannot depend solely on a mouse, color, animation, decorative symbols or unavailable modifier combinations.

### Validation, feedback and secrets

- Invalid attempted submission retains input and yields a persistent textual error with correction guidance.
- Live validation feedback is optional and must avoid repeatedly announcing the same error. Pending or stale asynchronous checks cannot accept an unverified answer.
- Status output identifies the task, provides meaningful bounded updates and retains completion/failure. Nonanimated output is available; exact cadence belongs to the feedback decision.
- Never replay secrets in errors, summaries or transcripts. Input echo, masking disclosure and assistive-technology typing behavior still require dedicated verification.

### Lifecycle and evidence

- Restore terminal state before returning control on submission, cancellation, interruption, EOF and recoverable exceptions; verify repeated prompts in one process. Do not claim guaranteed cleanup after forced process termination or terminal failure.
- The library does not exit the application on the caller's behalf.
- A terminal/screen-reader support claim requires observed keyboard and screen-reader task completion in exact environments, including correction, cancellation and relevant complex controls. Record versions, settings and mode tested; involve experienced screen-reader users in usability review. Untested combinations remain explicitly unverified.
- Decoder tests, ANSI support, static HTML accessibility and upstream documentation cannot substitute for end-to-end evidence. Broad compatibility remains the design target.

### Follow-up context

- [Define the shared linear command and literal-input grammar](10-linear-command-grammar.md) must settle discoverable cancellation/help and arbitrary literal entry before interactive component contracts are finalized.
- [Choose the accessibility verification matrix and evidence gates](11-verification-matrix.md) must select exact initial environments, task coverage, capability evidence and how unsupported/unverified combinations are communicated before specification readiness.
- Component-family tickets decide exact bindings, parsing and state transitions under this contract. DateInput's slash-separated entry requirement remains in force.
- Root GLOSSARY.md captures rich interaction, linear interaction, prompt cancellation and prompt interruption.

## Question

Given the research evidence, which compatibility tiers, default/fallback interaction modes, keyboard conventions, cancellation/submission rules, validation announcements and assistive-technology verification requirements should all Trelis prompts follow? Resolve the trade-offs with the human; broad compatibility must not become an unverified universal-support claim.
