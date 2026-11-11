# Ticket 03: TextInput output-profile evidence

**Status:** focused public behavior passed; partial backend-acceptance evidence, not a backend-gate pass  
**Recorded:** 2026-11-11  
**Source revision under test:** `fe759cedb2fe0961ec0a86bc02bbea32ecfd7908` (`feat: add TextInput output profiles`)  
**Branch:** `ticket/backend-03-output-profiles`

This record covers the approved immutable output-profile vocabulary and its
TextInput/scripted-source use. It does not claim the later shared renderer,
colour conversion, Unicode measurement, resize, session, feedback, CI, or GUI
acceptance requirements.

## Change under test

`OutputProfile` is the public immutable vocabulary for independent cursor,
alternate-screen, monochrome style, colour-depth, glyph, geometry, and
ambiguous-width declarations. `OutputGeometry.fixed` rejects non-positive
columns or rows with `ArgumentError`; automatic geometry is explicitly unknown.
`OutputProfile.resolve` resolves each field from invocation declaration,
scripted-source declaration, the legacy `supportsRich` cursor hint, and
conservative defaults. A rich scripted TextInput requires cursor support and
positive declared geometry. Legacy `supportsRich: true` no longer fabricates a
virtual 80x24 screen.

`TextInput.prompt(outputProfile: ...)`, `ScriptedInput(outputProfile: ...)`,
and the optional `TerminalIoOutputProfile` adapter boundary use that resolver.
A supplied answer stays on its validation path and does not acquire terminal
input or write output. Native output geometry is observed fallibly from the
selected stream and caps a caller request; known redirected/dumb native output
still follows its existing no-rich restriction. The existing `TerminalIo` lease
remains the sole acquisition/restoration owner.

The matrix fixture helper now declares a 100x30 synthetic profile for every
rich scripted fixture. Linear fixtures explicitly retain automatic geometry.
This is fixture configuration, not a claim about a real terminal's dimensions.

## Public-boundary observations

`test/output_profile_text_input_test.dart` uses only exported package APIs. It
observed the following deterministic results:

| Scenario | Expected and actual observation |
| --- | --- |
| Public vocabulary | All declared fields retain their supplied values; zero columns are rejected. |
| Source profile | Cursor support plus 100x30 geometry allows explicit rich TextInput and records cursor output. |
| Invocation/source/legacy order | Invocation `cursor: unsupported` overrides source cursor support while the source geometry remains available; automatic falls back to command-aware linear entry. |
| Legacy hint without geometry | Automatic falls back to linear; explicit rich returns `Unavailable` before writing. |
| Explicit synthetic request | Invocation cursor/geometry enables rich even with the legacy hint false; style/colour/glyph requests do not introduce colour SGR output. |
| Profiled terminal adapter | An adapter implementing `TerminalIoOutputProfile` supplies the selected output profile; public prompt acquisition and restoration remain exactly once. |
| Supplied answers | Literal `/cancel` is accepted as answer data and required validation still returns `Unavailable`, without terminal acquisition/output. |

The existing TextInput regression tests were migrated only where their direct
rich fixture intentionally simulates a terminal. The public component matrix
uses declared synthetic geometry for every rich fixture and passed in both
modes.

## Environment

- Windows 11 25H2: `Microsoft Windows NT 10.0.26200.0`
- Dart SDK 3.13.2 stable, `windows_x64`
- Host process input, stdout, and stderr were redirected during agent commands
- Host environment recorded by the preceding adapter evidence: `TERM=xterm-256color`, `COLORTERM=truecolor`, `NO_COLOR` absent
- Deterministic profile tests used `StringBuffer` scripted sinks and explicit
  100x30 geometry. They do not measure a terminal, font, colours, or glyphs.

## Executed verification

| Command | Actual result | Scope |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed .` | passed: `Formatted 124 files (0 changed)` | repository formatting at the tested code revision |
| `dart analyze` | passed: `No issues found!` | static analysis at the tested code revision |
| `dart test test/output_profile_text_input_test.dart test/text_input_test.dart test/terminal_io_test.dart --reporter expanded` | passed: 32 tests | new profile behavior, direct TextInput compatibility, and existing terminal adapter seam |
| `dart test test/component_acceptance_matrix_test.dart --reporter compact` | passed: 144 tests | public rich/linear component matrix with declared rich fixture geometry |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario repeat -Report doc/evidence/trelis-backend/ticket-03-text-input-repeat.txt` | passed; report says `result=alpha,alpha` and console state `503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1` | focused retained Windows native TextInput lifecycle |

| `dart test --reporter compact` | passed: 654 tests | complete package regression suite after the profile fixture migrations |
| `dart run tool/check_doc_links.dart` | passed: `Checked 152 relative links in 26 Markdown files.` | documentation-link integrity |

The formatter, analyzer, focused public seam tests, component matrix, full suite,
and link check above were rerun in this worktree on 2026-11-11. The report's
source revision identifies the runtime implementation under test; this evidence
file and the fixture migrations are recorded with the ticket completion commit.

## Acceptance mapping and limitations

- **B-CAP (partial):** public TextInput invocation, scripted source, optional
  terminal-adapter profile, legacy cursor hint, automatic fallback, and
  explicit-rich `Unavailable` behavior are covered. The tested resolver keeps
  cursor/style/colour/glyph/geometry facts independent and defaults unproven
  colour/glyph/style facts conservatively. Synthetic rich output has explicit
  positive geometry; no 80x24 default is used.
- **B-COMPAT (partial):** `ScriptedInput.supportsRich`, constructor defaults,
  result shapes, literal command behavior, supplied-answer validation, output
  ownership, and `TerminalIo` leasing are retained. Direct rich scripted
  fixtures now deliberately declare geometry; this tightening is tested and
  documented rather than hidden as legacy compatibility.
- **Not established:** selected stdout/stderr capability probes beyond the
  retained native lifecycle, `NO_COLOR` interpretation, colour rendering,
  terminal font/glyph agreement, Unicode cell/caret mapping, failed/zero size
  adapter injection, resize watching, feedback parity, sessions, non-Windows
  native execution/CI, visible-terminal GUI evidence, and accessibility claims.
  A profile is a declared compatibility assumption, not proof of physical
  terminal capabilities.
