# Specify shared output capabilities and display measurement
Type: grilling
Labels: wayfinder:grilling
Status: resolved
Assignee: bvlou
Blocked by: 04

## Question

Under the approved [rich and linear structure policies](04-rich-and-linear-structure-contracts.md), how does one shared renderer/session module obtain and represent stream-specific cursor/style/colour/glyph capabilities, columns/rows and resize updates? Define positive evidence versus unknown, conservative defaults, NO_COLOR handling, prompt/feedback parity, and how ScriptedInput and test fixtures supply explicit facts without pretending supportsRich proves Unicode or colour support. Decide whether a supported caller override/profile is needed, its exact interface and precedence, and integration with the approved invocation methods without adding behaviour to static theme factories. Specify display-cell measurement and grapheme-to-display/caret mapping (combining characters, emoji/ZWJ, CJK, ambiguous-width and escaped controls), limits of terminal/font agreement, deterministic RGB/indexed conversion and unsupported-colour handling, plus unknown/zero geometry and explicitly requested rich-mode failure/fallback semantics. Preserve no-ANSI redirected output, terminal resource restoration, secret-safe geometry and existing task/result semantics. Define an implementation-ready interface and evidence requirements, not implementation or a universal Unicode/accessibility claim. Consult Dart and codebase-design. External factual questions that cannot be answered locally should become focused research work rather than guesses.

## Answer

Approved by bvlou through live decision rounds and explicit final confirmation of the capability/profile and measurement contract. Backend design, implementation and validation must precede theme integration. This ticket resolves capability/measurement policy, not the separate multi-region screen-composition contract or actual implementation.

### Public OutputProfile

Expose an immutable typed OutputProfile with automatic defaults for all configurable fields:

| Field | Public value vocabulary |
|---|---|
| cursor | CapabilitySupport.automatic / supported / unsupported |
| alternateScreen | CapabilitySupport.automatic / supported / unsupported |
| styles | CapabilitySupport.automatic / supported / unsupported for the supported monochrome SGR style set |
| colorDepth | ColorDepth.automatic / none / ansi16 / indexed256 / rgb |
| glyphs | GlyphSet.automatic / ascii / unicode |
| geometry | OutputGeometry.automatic or OutputGeometry.fixed(columns: ..., rows: ...) |
| ambiguousWidth | AmbiguousWidth.automatic / narrow / wide |

Default construction requests automatic resolution; it does not declare every feature supported. Geometry.fixed requires positive integer dimensions; invalid declared values are ArgumentError, not silently clamped to arbitrary positive sizes. A profile is configuration, not an I/O handle, renderer, terminal-state owner or theme.

Approved usage shape:

```dart
final profile = OutputProfile(
  cursor: CapabilitySupport.supported,
  alternateScreen: CapabilitySupport.unsupported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  glyphs: GlyphSet.unicode,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
  ambiguousWidth: AmbiguousWidth.narrow,
);
```

Add an outputProfile named parameter with automatic default to prompt invocation methods, feedback start()/Text.present(), and ScriptedInput. Keep mode/source/output parameters and their existing precedence/meaning intact. Supplied-answer validation does not acquire or probe a terminal simply because profile configuration exists. Static theme factories remain free of terminal profile/detection side effects.

### Resolution and evidence

Resolve fields independently: invocation profile -> scripted-source profile -> applicable legacy supportsRich hint -> selected-output observations/advertisements -> conservative defaults. Automatic fields inherit the next source; a fixed geometry is a complete geometry declaration, not a partially populated object. New explicit profile fields take priority over compatibility hints, but cannot bypass hard output restrictions.

- Inspect the actual selected Stdout/stderr handle, never a different stream. A generic StringSink is unknown unless explicitly declared synthetic/capable through its source/profile contract.
- Keep observations, caller declarations and effective defaults distinguishable for diagnostics/testing. Unknown is not the same as a demonstrated unsupported feature, and advertised protocol support is not verified physical font/display agreement.
- Known real-stream redirection means no ANSI: a profile or palette does not override it. TERM=dumb and failed native capability acquisition cannot be turned into a working rich terminal by a profile assertion.
- Honour nonempty NO_COLOR even when a colour palette/profile is explicit. Empty NO_COLOR does not trigger suppression. This is Trelis's deliberately conservative project precedence; the external convention permits explicit application overrides, but this interface does not provide a force-colour bypass.
- NO_COLOR controls colour only. Independently supported cursor operations, ASCII/Unicode policy and monochrome styling remain separate. A palette does not request rich mode.
- Native Windows VT activation is evidence for parsing supported control sequences, not proof of arbitrary colour depth or font glyphs. TERM/COLORTERM and similar advertisements are bounded detection hints, not universal guarantees; absent sufficient evidence, use monochrome/ASCII.
- Initial automatic detection is noninvasive and stream-specific. Do not consume prompt input to obtain unsolicited cursor/device reports or run a competing terminal-mode owner.
- glyphs automatic resolves conservatively to ASCII when glyph support is unknown. A caller's unicode declaration is an explicit compatibility assumption, not a claim that Trelis discovered the selected font.
- ambiguousWidth automatic resolves to narrow unless an explicit profile supplies wide. Do not guess the font's ambiguous-width behavior from a locale alone.

Both prompts and feedback use the same resolver. Input availability, raw-input decoding and prompt task semantics stay separate from output capabilities.

### Existing supportsRich compatibility and scripted migration

Keep existing supportsRich arguments source-compatible as legacy cursor/rich hints, not evidence for dimensions, glyphs, colour depth or alternate-screen support. Explicit profile declarations resolve before those hints, subject to hard restrictions.

bvlou selected explicit synthetic profiles, not a hidden legacy virtual 80x24 screen. Scripted rich fixtures/callers must declare sufficient capabilities and positive geometry. Without those facts, automatic can select linear; an explicit rich request is unavailable. Document and test this deliberate runtime tightening and update existing rich fixtures during backend migration. Do not treat the unchanged constructor shape as a promise that unspecified synthetic geometry now magically exists.

Synthetic recording sinks can intentionally capture terminal sequences under an explicit virtual output profile for deterministic tests. This is not permission to emit ANSI to a known redirected real Stdout/stderr. Wrapping a stream in an opaque sink does not make detection omniscient; an application's explicit synthetic declaration is its responsibility.

### Mode and geometry lifecycle

Preserve current mode precedence. Automatic may choose linear when safe rich operation cannot be established. Explicit rich remains a requirement: prompts return Unavailable with a reason; feedback start uses its existing StateError failure shape. Missing colour or Unicode alone does not fail rich mode when ASCII/monochrome cursor rendering and geometry are sufficient.

Query selected-output dimensions through a fallible adapter. Catch expected dimension failures, reject zero/negative observations as usable geometry, and represent unknown explicitly. Real measured bounds constrain a caller-requested viewport; explicit declarations can fill unknown facts but cannot enlarge a known physical output. Synthetic geometry is declared simulation state, not detected physical evidence. Do not use the layout's 80-column readability cap as a fabricated terminal measurement.

Resize observation belongs to the session/backend. Observe while idle using supported notifications and a bounded polling fallback; coalesce changes and repaint only on material geometry changes. Inject observation/clock inputs in tests. Refresh before painting, preserve logical drafts/focus/caret, and emit no new linear transcript events merely for resize. Fixed synthetic outputs require no host-terminal watcher.

Transient unusable/unknown resize geometry must not trigger guessed cursor placement or lost task state; defer geometry-dependent painting until a valid layout can be placed, while preserving cancellation/interruption and backend cleanup. Permanent output/acquisition errors follow the established failure/restoration path rather than inventing acceptance or a feedback outcome.

Stop watchers and release subscriptions/timers on success, cancellation, interruption, input-end, acquisition failure and rendering/write failure. The existing native session adapter remains the sole owner of mode changes/restoration; detection/width modules do not independently switch console modes. Multi-region ownership and teardown coordination are specified in the follow-up, not assumed to be one region per stream.

### Measurement foundation

bvlou selected an exact pinned termunicode 0.2.0 dependency behind a Trelis-owned internal adapter, not a drop-in string-width call and not terminal_core.

- Artifact: https://pub.dev/api/archives/termunicode-0.2.0.tar.gz
- Audited archive SHA-256: 20ef06647ccaad83fcf9609901897ddb04ae904d9d16617347a2ee1adea6b6ce
- Versioned table basis: Unicode 16.0.0; public scalar/property APIs, MIT license, sole runtime dependency characters ^1.3.0 compatible with the project's existing characters 1.4.1.
- Integrate with an exact package constraint/lock evidence during implementation. No package was added while resolving this decision. Do not silently upgrade the Unicode-data policy with a package update.

Use characters for edit/grapheme boundaries. The adapter owns cluster/display behavior and maps original grapheme positions to approved displayed runs/cells. Do not use termunicode.widthString/widthChars as an unqualified oracle: actual source and a temporary executed probe show known VS16/keycap edge cases. No internal package src imports or general terminal runtime is needed for the selected scalar APIs.

The declared policy must explicitly handle printable scalar width, base-plus-combining marks, wide/CJK, narrow/wide ambiguity, flags, modifiers, supported ZWJ/variation/keycap forms, isolated format/combining content, tabs and hard line boundaries. Regression anchors include ASCII=1 per character, accented/decomposed narrow text=1, CJK=2, common supported emoji clusters=2, heart+VS16=2 and keycap with/without VS16=2. Never apply an 'any ZWJ is width 2' or 'any VS16 is width 2' shortcut to arbitrary content.

Unsupported sequences and standalone unsafe/zero-advance presentation content require a deliberate visible safe representation with an explicit mapping, rather than silently guessing width or allowing marks/controls to attach to chrome. Distinguish raw width primitives from encoded display width: a standalone variation selector may have zero intrinsic advance but its visible escaped representation has measurable ASCII cells. Controls/bidi/escapes are displayed safely, never executed; literal answer data and validation semantics remain unchanged. Tabs are layout-controlled expansion rather than raw terminal tab execution, and newlines remain explicit layout/hard-line boundaries.

Specify the adapter's supported sequence/escape/tab fixtures as part of backend implementation acceptance, version them with the Unicode basis, and validate display mappings as well as total widths. The internal seam permits replacement/update without changing the public theme interface. Package source audit is evidence, not a universal-width or full-UAX-conformance claim. Actual terminal/font agreement needs recorded real-environment checks; native cursor anchoring remains preferable to unproven offset guesses where applicable.

### Colour conversion

Resolve TerminalColor requests only within effective output capability. Keep terminal-default as terminal-default; it has no guessed RGB value. Preserve supported indexed references rather than accidentally freezing user-customized ANSI slots into assumed RGB values.

Use a deterministic documented approximation policy: supported RGB requests remain RGB; for indexed256 targets, select the nearest standard xterm cube/grayscale entry by squared RGB distance with a stable lowest-index tie-break (avoid treating customizable base slots as measured colours). For ansi16 targets, use documented nominal ANSI16 colours for approximation, explicitly not a measurement of a user's customized palette; indexed 0..15 requests stay their slot references. Higher indexed entries can be mapped through their standard cube/grayscale RGB before reduction. With no effective colour support, emit semantic monochrome presentation and no colour selection sequences.

Only component/compositor-owned cells receive palette backgrounds; restore owned styles at output boundaries. The compositor decision controls coordinated writes, not per-region competing resets. Redirected real streams receive no ANSI, including non-colour styles/cursor controls. NO_COLOR may retain independently supported monochrome styles on a capable terminal.

### Evidence and implementation prerequisites

[Primary-source research, exact-version package audit and executed fixture findings](../../../../doc/research/trelis-output-capabilities-and-width.md) distinguish official API contracts, heuristics, proposed policy, source inspection and executed probes. Both candidate archives were downloaded outside the repo and SHA-256 verified. The probe ran source imports against existing characters configuration; it was not a backend implementation or real-terminal/font test.

Backend acceptance must cover selected stderr/stdout independence; redirected/dumb/unknown outputs; dimension exceptions and zero geometry; profile precedence and hard restrictions; synthetic-rich migration; NO_COLOR absent/empty/nonempty; independent cursor/style/colour/glyph combinations; idle resize/teardown; explicit versus automatic failures; colour conversion fixtures; cluster/display/caret mappings; secret-safe geometry; and prompt/feedback parity. Existing native state restoration tests remain mandatory.

### New decision: multiple live regions

bvlou rejected a single-live-presentation restriction and explicitly requires multiple live regions on one output. [Specify shared multi-region output composition](08-multi-region-output-composition.md) must define the stream-owned compositor, region registration/layout, input/focus scope, modal help, profile conflicts, coordinated writes and lifecycle/failure ownership. Multiple regions do not mean multiple independent terminal writers.

That ticket remains open; no assumptions about simultaneous interactive prompts or a public screen framework were silently made here. Implement and validate capability/measurement plus the chosen compositor foundation before integrating themes. The final handoff ticket is blocked on both backend decisions.

No project runtime source or dependencies were changed to resolve this ticket.
