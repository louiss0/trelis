# Adaptive themes and accessible component presentation

Status: implemented-unstable
Labels: ready-for-agent
Implementation: complete for agent-resolvable tickets; interaction and colour
release gates and native/human evidence remain open

## Purpose and authority

Replace the static structural-theme factory API with reusable theme instances, adapt theme-specific colour defaults to terminal conditions, express component state with accessible non-colour indicators, and support reliable linear screen-reader presentation. The approved [design](../../adaptive-theme-accessibility-design.md) is the behavioral contract; the [implementation plan](../../adaptive-theme-implementation-plan.md) supplies sequencing and validation detail. The [native-detection research](../../../assets/research/screen-reader-detection-and-locality.md) records bounded evidence and platform limitations.

This work supersedes the older theming and accessible-prompt specifications where they require static theme factories, public direct component construction, invocation-level I/O/session configuration, terminal-default omitted palettes, hidden essential hints, or supplied-answer/tag APIs. Do not modify or close those earlier tracker items as part of publishing these tickets. Preserve existing domain types, task outcomes and safety behavior except where the new design explicitly changes the public contract.

## Target usage (illustrative, not implemented)

```dart
final theme = RailTheme(
  interaction: interactionPreferences,
  colors: colorPreferences,
  selectionStyle: selectionStyle,
  io: terminalEnvironment,
);

final name = theme.textInput(
  'Name',
  colors: ComponentColors.palette(customPalette),
);
final result = await name.prompt();
// No theme.close(): resources are released after the last active component.
```

Theme constructors have optional named configuration; a theme owns I/O and automatic shared-resource coordination. Theme methods create reusable components and accept allowed named overrides; `.prompt()` does not accept runtime configuration. One active prompt can coexist with live feedback. The prompt may be reused sequentially from its configured initial value. A spinner or other live feedback remains active until stopped, completed, or failed; terminal resources are restored automatically after the final active component ends. Automatic detection and the resolution callback run at most once per active period and can run again in a later period. Caller-owned streams remain open by default. A new operation racing cleanup must not reuse a partially released owner.

One environment binds input, selected output, and its output profile. Remove `SuppliedAnswer` and `SuppliedTags` from the supported public API; scripted I/O is not necessarily an equivalent replacement. Input exhaustion returns `InputEnded`. Replace static factories and public direct component construction with theme instances, supply migration guidance, and do not maintain a second permanent public API. Preserve public result and component-value types.

## Presentation contract

- Interaction preferences, colour preferences, and component colour overrides are separate immutable values. Theme-level colour preferences compose component colour overrides plus background/query controls; component calls cannot change terminal detection or I/O.
- The internal interaction state is rich/linear plus a validated screen-reader flag; screen-reader-active requires linear. Conflicts and unavailable outcomes are distinct. Explicit on/off wins; any eligible positive application or native hint may enable automatic screen-reader presentation. An explicit rich request is not overridden by automatic detection.
- Each structural theme has adaptive light/dark defaults. Explicit palette replacement and shared/variant-specific role overrides follow theme default → app replacement and roles → component replacement and roles. A whole component palette replaces the complete effective app palette. Non-empty `NO_COLOR` is a hard restriction. Unknown background falls back to dark.
- Adaptation respects the selected output's capabilities. A bounded background query uses the owned input reader, preserves unrelated input, occurs at most once per eligible active period, and is skipped for disabled colour; explicit choice takes precedence, then valid query, passive hint, and dark fallback.
- The family is Atelier warm ink, with Atelier Sepia as the light starting direction; exact values remain to be refined. Primary accents: ink blue for Rail, ASCII, Double, Chevron, Colon; rust for Box, Bracket, Block; plum for Branch, Round, Line; sepia for Minimal, Plain, Form, Ledger. Preserve the terminal background; target 4.5:1 for known authored normal-text/reference-background pairs, without claiming actual terminal contrast is guaranteed.
- Focus uses Unicode `→` or ASCII `>` and a restrained highlight. Multi-selection checked/unchecked uses `✓` / `○`, ASCII `x` / `-`; single-selection offers circles by default plus squares, triangles, dots-in-circles, and checkmarks, with tested distinct ASCII pairs. Default marker `★` / `D` is independent. Tree disclosure is `▾` / `▸` or `v` / `>` in a separate aligned position. Locked `[L]` and unavailable `[!]` choices remain focusable but not selectable, with visible reasons. Status messages include text labels and symbols, not colour alone.
- Interactive prompts always show the compact primary-action/help hint; screen-reader presentation uses concise essential text before each prompt. Hidden-instruction settings do not remove the essential hint. Detailed help preserves draft, focus and caret; secret and key-capture routes cannot reinterpret literal content or steal captured gestures. Feedback does not display artificial help.
- Automatic screen-reader hints initially target documented Windows and macOS signals only after native binding and actual reader checks; Linux stays unknown until a suitable signal exists. Positive native signals apply only under the agreed conservative locality heuristic. Known OpenSSH, multiplexer, RDP or positively identified container context is ambiguous; no subprocess container detection. A failed required native locality check is ambiguous. Missing indicators cannot prove locality.

## Sequencing and gates

Use internal expand–migrate–contract: introduce and test seams while existing public calls remain buildable, migrate theme and component families behind those seams, then perform a coordinated breaking public cutover with generators, tests, examples and migration guide. The earlier standalone editor-safety audit and generalization were explicitly deferred; preserve existing safety work and verify the relevant behavior as affected families migrate, not as a separate preliminary project. The interaction and colour release gates are independent. For this ticket plan, the approved full interaction release gate additionally waits for both Windows and macOS native hints to be validated and enabled; lack of platform evidence blocks that full gate, not unrelated implementation. Automated scripted tests do not replace native-terminal, human screen-reader, or real light/dark visual evidence. Record missing platform evidence rather than claiming qualification.

## Ticket conventions

Tickets are numbered in dependency order. Status uses the repository triage vocabulary; human evidence gates use `ready-for-human`. Blockers are links to concrete tickets. Code snippets are explicitly illustrative future API examples requested by the user, not claims of current functionality. Acceptance criteria are checked against the authoritative design and plan.
