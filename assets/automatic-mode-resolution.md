# How `PromptMode.automatic` chooses rich vs linear

This document explains, step by step, exactly what information the package
gathers and how each condition is evaluated when a prompt runs in the default
`automatic` mode. It is a read of the current source; the file/line references
name the live code locations.

---

## 1. The three modes

```dart
enum PromptMode { rich, linear, automatic }
```
(`lib/src/text_input.dart:279`)

- **rich** — in-place editing (cursor addressing; the editable row is redrawn).
- **linear** — sequential, reviewable events (every keystroke becomes a new
  line below, by design).
- **automatic** — decide between the two from capabilities.

---

## 2. Step 1 — mode precedence (before any capability check)

Every `prompt()` call resolves a `selected` mode:

```dart
final selected =
    mode ??                // the `mode:` argument passed to prompt()
    userPreference ??      // per-component constructor config
    applicationPreference ??
    PromptMode.automatic;
```
(`lib/src/text_input.dart:2317-2320`, and the same chain in `_feedbackRich` at
`:510-515`)

So the precedence is, strongest first:

1. **Explicit `mode:` on the `.prompt()` call.**
2. **`userPreference`** set on the component at construction.
3. **`applicationPreference`** set on the component at construction.
4. **`automatic`** — the default when none of the above is given.

This is the "respect stronger user choices" rule from the original spec
(`docs/issues/trelis-accessible-prompts/spec.md` §"Modes, streams and session
lifecycle", user story #17).

---

## 3. Step 2 — the rich-mode gate

If the resolved mode is `automatic`, it is turned into a concrete mode:

```dart
if (mode == PromptMode.automatic) {
  mode = effectiveProfile.supportsRichInteraction
      ? PromptMode.rich
      : PromptMode.linear;
}
```
(`lib/src/text_input.dart:2396-2397`)

The whole decision is `supportsRichInteraction`:

```dart
bool get supportsRichInteraction =>
    cursor == CapabilitySupport.supported && !geometry.isAutomatic;
```
(`lib/src/output_profile.dart:189-190`)

Two conditions, **both** required:

| # | Condition | Meaning |
|---|---|---|
| a | `cursor == CapabilitySupport.supported` | cursor addressing is positively available |
| b | `!geometry.isAutomatic` | a positive `(columns, rows)` size is known |

If **either** is false/unknown, `automatic` becomes `linear`.

Explicit `rich` is treated differently — it never silently downgrades:

```dart
if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
  return Unavailable(
    'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
  );
}
```
(`lib/src/text_input.dart:2391-2393`, and the same pattern in the POSIX/Windows
terminal paths at `:3447-3450` and `:3556-3559`)

---

## 4. Step 3 — how `cursor` is resolved

`OutputProfile.resolve` resolves every field independently, with this chain
(invocation wins, then source, then the legacy hint, then a conservative
default):

```dart
factory OutputProfile.resolve({ invocation, source, supportsRich }) {
  ...
  cursor: _resolveCapability(
    requested.cursor,   // the `outputProfile:` argument on the prompt call
    declared.cursor,    // the scripted source's declared profile
    supportsRich == null
        ? CapabilitySupport.unsupported
        : (supportsRich ? CapabilitySupport.supported
                        : CapabilitySupport.unsupported),
  ),
  ...
}
```
(`lib/src/output_profile.dart:126-160`)

`_resolveCapability` = first non-`automatic` value in that order, else the
fallback. So `cursor` becomes `supported` only if:

1. the invocation profile declares it, **or**
2. the source profile declares it, **or**
3. the legacy `supportsRich` boolean is `true`.

With no facts anywhere, the default is **`unsupported`**.

`supportsRich` itself is gathered as:

```dart
_source?.supportsRich ?? _terminalIo?.supportsRich ?? false
```
(`lib/src/text_input.dart:526`)

It is explicitly documented as a *legacy hint*: "It is not evidence of
dimensions, styles, colours, glyphs, or an alternate screen." So a `true`
`supportsRich` can satisfy condition (a) **cursor**, but never condition (b)
geometry.

---

## 5. Step 4 — how `geometry` is resolved

```dart
geometry: requested.geometry.isAutomatic
    ? declared.geometry
    : requested.geometry,
```
(`lib/src/output_profile.dart:143-145`)

- The invocation's declared geometry wins; otherwise the source's; otherwise
  `automatic` (unknown).
- `OutputGeometry.fixed(columns:, rows:)` **requires positive** dimensions and
  throws `ArgumentError` on `<= 0` (`lib/src/output_profile.dart:26-34`).
- `geometry.isAutomatic == true` means "no usable dimensions are known".

So condition (b) `!geometry.isAutomatic` is true only when a *complete,
positive* `(columns, rows)` pair is known — declared by the caller/source, or
observed from the actual stream (next section).

---

## 6. Step 5 — the native terminal path (the default when you pass nothing)

When you call `.prompt()` with no `source` and no `terminal`, it runs the
native path `_terminal(...)` (`lib/src/text_input.dart:2352`).

### 6.1 Input gate (must pass just to get a prompt at all)

```dart
if (!stdin.hasTerminal) {
  return Unavailable(
    'Interactive console input is unavailable; supply an explicit input source.',
  );
}
```
(`lib/src/text_input.dart:3542-3544`)

`stdin` must be a terminal, or the prompt refuses before doing anything.

### 6.2 Output capability — platform specific

The prompt's output defaults to **stdout**. So `outputStream` is `stdout` unless the caller passed
`output:`.

**POSIX** (`_posixTerminal`, `lib/src/text_input.dart:3438`):

```dart
final capable =
    outputStream.hasTerminal && Platform.environment['TERM'] != 'dumb';
```

**Windows** (`_terminal`, `lib/src/text_input.dart:3533`):

```dart
var capable =
    outputStream.hasTerminal && Platform.environment['TERM'] != 'dumb';
```

…and then it tries to enable virtual-terminal processing on the output handle:

```dart
if (console.getMode(output, outputMode) == 0 ||
    console.setMode(output, outputMode.value | 4) == 0) {
  if (mode == PromptMode.rich) {
    return Unavailable('Cannot enable terminal cursor addressing.');
  }
  capable = false;
  rich = false;
} else {
  outputAcquired = true;
  ...
}
```
(`lib/src/text_input.dart:3589-3600`; bit `4` is
`ENABLE_VIRTUAL_TERMINAL_PROCESSING`)

So on Windows, `capable` requires **three** things: the output stream is a
terminal, `TERM` is not `dumb`, and enabling VT output processing succeeds.

### 6.3 Geometry observation

`_nativeOutputProfile` (`lib/src/text_input.dart:3408-3432`):

```dart
OutputGeometry geometry = const OutputGeometry.automatic();
if (output.hasTerminal) {
  try {
    final columns = output.terminalColumns;
    final rows = output.terminalLines;
    if (columns > 0 && rows > 0) {
      geometry = OutputGeometry.fixed(columns: columns, rows: rows);
    }
  } on FileSystemException { /* geometry stays unknown */ }
    on UnsupportedError      { /* geometry stays unknown */ }
}
```

Geometry is `fixed` only when the actual selected output reports **both**
`columns > 0` and `rows > 0`. Otherwise it stays `automatic`, which makes
condition (b) false and forces `linear`.

### 6.4 Assembling the effective profile

The native path packages the gathered facts into a `ScriptedInput`:

```dart
ScriptedInput(
  ...,
  supportsRich: capable,       // feeds cursor (condition a)
  outputProfile: profile,      // carries cursor + observed geometry
  observedGeometry: profile.geometry,
  ...
)
```
(`lib/src/text_input.dart:3615-3626`)

Then `_effectiveOutputProfile` (`lib/src/text_input.dart:256-276`) combines the
invocation profile, the source profile, the legacy hint, the observed geometry,
and the `NO_COLOR` hard restriction into one effective profile, and
`supportsRichInteraction` is read from that.

---

## 7. Step 6 — the two outcomes of `automatic`

| Result | Condition |
|---|---|
| **rich** (in-place) | `cursor == supported` **and** `geometry` is positive/fixed |
| **linear** (append-at-bottom) | either `cursor` is not `supported`, or geometry is `automatic`/unknown |

`linear` is the *safe* fallback: sequential, reviewable, and it works on any
stream (including redirected/logged output).

---

## 8. What each gathered fact actually is

| Fact | What it is | How it is obtained |
|---|---|---|
| `stdin.hasTerminal` | the input stream is attached to an interactive terminal | Dart `dart:io`; POSIX ≈ `isatty(fd)`, Windows ≈ the handle is a console |
| `stdout.hasTerminal` / `stderr.hasTerminal` | the output stream is a terminal | same mechanism per stream |
| `TERM` | the terminal-type environment variable | `Platform.environment['TERM']` |
| `dumb` (in `TERM`) | a terminal type with no cursor addressing | literal `TERM=dumb` → forced linear |
| `terminalColumns` / `terminalLines` | the current terminal size in cells | Dart `dart:io`; POSIX ≈ `ioctl(TIOCGWINSZ)`, Windows ≈ `GetConsoleScreenBufferInfo`/ConPTY size |
| `ENABLE_VIRTUAL_TERMINAL_PROCESSING` (bit 4) | Windows console VT sequence processing | `SetConsoleMode(output, mode | 4)` |
| `NO_COLOR` | environment colour suppression | `Platform.environment['NO_COLOR']` — affects colour only, **not** mode |

Downstream, geometry also bounds layout: `_textInputTotalWidthCap = 120` and
`_textInputWidth = geometry.columns.clamp(1, 120)`
(`lib/src/text_input.dart:1178-1182`), and the editable-row budget reserves the
structural marker plus the two overflow markers.

---

## 9. Why it was designed this way (the research)

The decision is not arbitrary. The original accessibility spec
(`docs/issues/trelis-accessible-prompts/spec.md`) states the rationale as user
stories:

- **#18** — "rich mode chosen automatically only when its required capabilities
  exist, so that capable terminals receive rich interaction and others receive
  linear interaction."
- **#17** — mode selection respects the user's explicit choice and saved
  preference (accessibility preferences are never silently overridden).
- **#19** — an explicitly requested but unavailable rich mode fails *before*
  partial setup, never a hidden downgrade.
- **#44–45** (linear/screen-reader section) — linear must be **sequential and
  reviewable**: "questions, entered answers, errors and final outcomes remain
  reviewable, so that I can recover context without interpreting a changing
  screen position."
- **#58** — "errors and outcomes retained rather than disappearing with a
  redraw."

The capability policy was resolved separately in
`docs/issues/trelis-theming/issues/07-output-capabilities-and-measurement.md`:

> "Inspect the actual selected Stdout/stderr handle, never a different stream.
> … Unknown is not the same as a demonstrated unsupported feature …
> TERM=dumb and failed native capability acquisition cannot be turned into a
> working rich terminal by a profile assertion."

In short: rich mode erases-and-redraws, which requires real cursor addressing
and a known size to do safely; linear mode never erases, so it is the honest,
always-safe, screen-reader-friendly fallback. `automatic` exists to give capable
terminals rich and everyone else linear, without guessing.
