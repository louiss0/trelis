# Trelis output capabilities and terminal-cell width

Research for backend design; no dependency selected or implementation prescribed. Source findings, limitations, and proposed policies are distinguished below.

## Dart output detection

**Official API contract.** Both `stdout` and `stderr` are `Stdout` objects. Inspect the stream actually selected for rendering—not always global `stdout`. `terminalColumns` and `terminalLines` return terminal dimensions and throw `StdoutException` if no terminal is attached. The documented implementations pass the object's `_fd` to the native dimension getters, supporting per-output-handle rather than process-global interpretation. Sources: [dart:io](https://api.dart.dev/dart-io/dart-io-library.html), [columns](https://api.dart.dev/dart-io/Stdout/terminalColumns.html), [lines](https://api.dart.dev/dart-io/Stdout/terminalLines.html).

`supportsAnsiEscapes` is explicitly **best-effort detection**, not a guarantee. The API mentions `TERM` containing `xterm` as evidence used in detection. Its Windows documentation identifies output support from the Windows 10 version 1511/build 10586 era, separately from input support at version 1607/build 14393. Do not equate an OS-version threshold with guaranteed support from every host or every escape sequence. Source: [Stdout.supportsAnsiEscapes](https://api.dart.dev/dart-io/Stdout/supportsAnsiEscapes.html).

**Recommended policy.** Query `hasTerminal`, ANSI support, and size through an adapter for the selected output. Treat size acquisition as fallible even after a terminal check; catch expected I/O failures and reject nonpositive dimensions. Preserve “size unknown” separately from a chosen fallback layout width. Avoid promising that one startup observation remains valid after resize or output replacement. Exact native exception behavior beyond the public contract should be checked against the project's pinned Dart SDK before implementation.

## Unicode segmentation is not terminal measurement

**Unicode specifications.**

- [UAX #11, East Asian Width](https://www.unicode.org/reports/tr11/) classifies characters as Narrow, Wide, Fullwidth, Halfwidth, Ambiguous, or Neutral. It explicitly warns that East Asian Width is **not an off-the-shelf solution for modern terminal emulators**: terminal implementations need tailoring and edge-case handling.
- [UAX #29, Unicode Text Segmentation](https://www.unicode.org/reports/tr29/) defines grapheme-cluster boundaries, not terminal-cell advances. A cluster can contain multiple code points, including combining marks or emoji sequences.
- Therefore, neither a Unicode scalar count nor an extended-grapheme count universally determines occupied terminal cells. **This conclusion follows from the distinct scopes of UAX #11 and #29**, not from a guarantee that all terminals implement some single alternative algorithm.

The existing `characters` dependency remains useful for editing boundaries. It cannot, by segmentation alone, supply terminal-cell widths. “Every non-ASCII character is width 2” is also not a defensible width model: non-ASCII includes narrow letters and combining marks, not only wide characters.

**Recommended policy.** Make cell measurement an explicit, replaceable policy with documented Unicode data/version and ambiguous-width behavior. Keep cursor/edit boundaries distinct from measured cell advances. Define behavior for combining-only clusters, variation selectors, flags, ZWJ sequences, tabs, control characters, and embedded escapes. Terminal-specific emoji rendering and ambiguous-width choices remain compatibility assumptions, even with a good width library.

## Dart package candidates—not a dependency decision

These are publisher documentation and registry observations, not independent conformance audits. Publication age is a maintenance signal, not a maintenance guarantee; recheck exact release dates before choosing.

| Candidate | Publisher-described scope | License / maintenance evidence | Decision caveat |
|---|---|---|---|
| [`terminal_core`](https://pub.dev/packages/terminal_core) | Grapheme-aware widths; combining marks, emoji modifiers, flags and common ZWJ emoji; configurable ambiguous width. Describes practical coverage rather than exhaustive Unicode conformance. | [MIT](https://pub.dev/packages/terminal_core/license); registry showed `0.2.0`, published approximately four months before lookup; [publisher repository](https://github.com/Atrac613/terminal_core). | Promising cluster-oriented candidate, but broader than a standalone width primitive. Review source, Unicode tables, tests, dependency footprint, and update mechanism. |
| [`termunicode`](https://pub.dev/packages/termunicode) | Character/string width, emoji and printable-character properties; `cjk` option for ambiguous width. | [MIT](https://pub.dev/packages/termunicode/license); registry showed `0.2.0`, approximately five months before lookup. | Do not assume string-width helpers correctly handle complete ZWJ/flag clusters merely because individual emoji are width 2; inspect implementation and regression tests. |
| [`string_width`](https://pub.dev/packages/string_width) | Unicode display-width helper; documentation says ANSI escape codes are ignored. | Apache-2.0 per registry; registry showed `0.1.5`, approximately three years before lookup. [API documentation](https://pub.dev/documentation/string_width/latest/). | Older release signal warrants checking Unicode-data freshness. Grapheme/emoji and ambiguous-width coverage were not sufficiently confirmed in this research. |

**Open verification:** exact Unicode versions, complete sequence handling, repository activity, and conformance-test coverage were not established for all candidates. Settle these with source/test inspection and a shared adversarial fixture suite before selecting a dependency. None can guarantee agreement with every terminal.

## NO_COLOR, Windows VT, color and glyphs

**Convention.** [`NO_COLOR`](https://no-color.org/) requests suppression of automatically added ANSI **color** when the variable is present and nonempty. It does not require disabling bold, underline, or other non-color styling. The convention allows explicit per-program configuration or command-line options to override the environment preference. An empty value does not trigger the convention.

**Windows contract.** [`ENABLE_VIRTUAL_TERMINAL_PROCESSING`](https://learn.microsoft.com/en-us/windows/console/setconsolemode) enables parsing of VT output sequences on a console screen-buffer handle. It is an output-mode setting, not proof of arbitrary color depth, font coverage, emoji support, or Unicode width agreement. Microsoft's [VT sequence documentation](https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences) describes extended-color requests and approximation to an available color table; parsing RGB syntax therefore must not be treated as a universal truecolor guarantee.

Glyph availability is a separate concern: Microsoft's [Console documentation](https://learn.microsoft.com/en-us/dotnet/api/system.console) explains that Unicode display depends on encoding and suitable font glyphs. Neither ANSI support nor UTF-8 encoding establishes that a terminal will render a desired symbol.

**Recommended policy.** Preserve independent decisions for terminal attachment, VT/control sequences, color, glyph repertoire, dimensions, and width policy. Do not infer “truecolor + emoji + width 2” from one ANSI boolean. Do not let `NO_COLOR` disable necessary cursor control or force ASCII; those are separate user choices.

## Proposed OutputProfile boundary

The following is **design policy**, not an external API guarantee:

- Produce an immutable effective profile from **observations plus typed overrides**.
- Observe the selected output handle, not an unrelated stream. Keep native Windows/POSIX detection behind the existing backend seam rather than adding a competing console-mode owner.
- Represent unknown capabilities explicitly. Separate observed evidence from resolved defaults where useful for diagnosis.
- Suggested override dimensions: terminal/control mode; color mode (`auto`, `never`, explicit supported level); glyph policy (`auto`, ASCII, Unicode); optional positive rows/columns; and a width-policy identifier/configuration.
- Resolve explicit overrides before automatic preferences. For automatic color, honor nonempty `NO_COLOR`; absence of it is not proof that color is supported.
- For unknown output, prefer plain/no-control automatic behavior. Keep glyph choice conservative and configurable. Do not claim an inferred color depth or universal emoji width.
- Resolve width deterministically under a declared policy; document that it is an estimate of terminal rendering, not a discovered physical fact.

### Deterministic synthetic tests

Inject environment, selected-output observations, dimensions/errors, and the width policy. Unit tests should not consult the developer's actual terminal, locale, font, or process environment.

Cover:

1. stdout redirected while stderr is terminal, and the reverse; verify the selected stream controls detection.
2. Missing terminal, dimension exception, zero/negative dimensions, and explicit size overrides.
3. `NO_COLOR` absent, empty, nonempty, plus explicit color overrides.
4. Independent combinations of VT, color level, and glyph policy, including unknown values.
5. ASCII, accented narrow text, decomposed accents, CJK wide text, ambiguous characters, combining-only clusters, variation selectors, flags, skin tones, and ZWJ emoji.
6. Explicit handling of controls, tabs, newlines and escapes; never assume an escape-stripping helper also defines their layout semantics.
7. Fixed expected widths **for the selected policy/version**, rather than claims of universal terminal truth.

Real-terminal smoke tests can complement these fixtures but cannot replace them or establish a universal width algorithm.

## Exact-version source audit: width dependency candidates

### Evidence and scope

Inspected actual extracted package source, manifests, licenses and tests, read-only—not web-search summaries. **No Dart code, tests or generators were executed.** Results below distinguish source facts from predicted behavior.

Exact audited artifacts, downloaded and SHA-256-verified by the delegating agent:

| Package | Primary artifact | SHA-256 |
|---|---|---|
| `terminal_core 0.2.0` | [Package archive](https://pub.dev/api/archives/terminal_core-0.2.0.tar.gz) | `06c39d16b35036f795dc8c2c1d1834e97b7f88b554fafa831d3286b366251a49` |
| `termunicode 0.2.0` | [Package archive](https://pub.dev/api/archives/termunicode-0.2.0.tar.gz) | `20ef06647ccaad83fcf9609901897ddb04ae904d9d16617347a2ee1adea6b6ce` |

Local audit root: `C:/Users/bvlou/AppData/Local/Temp/trelis-width-audit-hbfo14gt/`. Paths below are relative to each package directory within that root. The archives, rather than unverified moving repository branches, identify the exact inspected source.

### `terminal_core 0.2.0`

**Algorithm and Unicode provenance.** `lib/src/text/unicode_width.dart` contains literal wide, zero-width and ambiguous interval tables with binary-search lookup. No Unicode version or table-generation provenance is identified in that file; no generator/update tooling is included in the inspected archive. **Its precise Unicode table version and reproducible update path remain unconfirmed.**

Rune width special-cases NUL as zero and regional indicators as two, then checks zero-width, wide and optionally ambiguous tables; everything else is one. Consequently, most control characters—including newline and ESC—are counted as one by this helper. It does not parse ANSI sequences.

Cluster width:

- Any cluster containing **any ZWJ** or **any keycap enclosing mark U+20E3** returns two; this is not validation against recognized emoji sequences.
- A pair consisting exclusively of regional indicators returns two.
- Otherwise, it skips extenders—including variation selectors, combining marks, modifiers and tags—and takes the maximum remaining rune width.
- Combining-only clusters return zero, **except** the earlier blanket ZWJ/keycap rules.
- VS16 is ignored as an extender; it does **not** promote a narrow text symbol to emoji width.

`cellWidthForText` uses its own `GraphemeClusterSegmenter`, not `characters`. The implementation in `lib/src/text/grapheme_cluster_segmenter.dart` joins five combining-mark blocks, variation selectors, modifiers, tags and keycap marks; joins ZWJ and the following rune unconditionally; and pairs regional indicators. It is not a full UAX #29 implementation: for example, it has no Hangul syllable joining rules and no general script-property tables.

**Tests actually present.** `test/text/unicode_width_test.dart` asserts ASCII, Japanese wide characters, emoji, modifier sequences, flags, family ZWJ sequences, combining marks, ambiguous width and VS16-containing keycaps. `test/text/grapheme_cluster_segmenter_test.dart` covers basic combining, modifiers, flags and family ZWJ segmentation. Neither test file establishes VS16 promotion for narrow symbols, complete grapheme conformance or malformed/standalone extender behavior.

**Dependency/API suitability.**

- `pubspec.yaml`: SDK `^3.11.4`; **no runtime dependencies**.
- `lib/terminal_core.dart` exports terminal/buffer/input/model APIs, **not `UnicodeWidth`**.
- Its own width tests import `package:terminal_core/src/text/unicode_width.dart`. A width-only consumer would likewise depend on an internal `src` API.
- `LICENSE`: MIT, copyright 2026 Osamu Noguchi.

**Assessment:** unsuitable as the preferred width-only dependency. It combines an internal-only width API, unversioned tables, duplicate/incomplete grapheme segmentation and a concrete VS16 gap. Existing `characters 1.4.1` would not repair `cellWidthForText` because that function independently segments strings. Passing externally segmented clusters would avoid that segmentation path but still require an internal API and retain the width-rule limitations.

### `termunicode 0.2.0`

**Unicode version and regeneration.**

- `lib/src/table.dart` declares `unicodeUCD = '16.0.0'`.
- `tool/generator/constants.dart` likewise pins `version = '16.0.0'`.
- `tool/generator.dart` invokes the builder and emitter.
- `tool/generator/downloader.dart` downloads versioned Unicode EastAsianWidth, UnicodeData, emoji-data, DerivedCoreProperties and HangulSyllableType files.
- Existing downloaded files are reused without revalidation. Updating therefore requires changing the version **and clearing/replacing cached input files**, then regenerating.
- I did not regenerate the tables or independently verify their contents against Unicode source files.

`tool/generator/table_builder.dart` derives width from EAW, overrides combining categories `Mn`/`Me` and controls to zero, handles default-ignorables and Hangul V/T jamo, and special-cases U+115F and soft hyphen. It also promotes selected emoji-property characters to width two unless their width is ambiguous. These are package width policies, not universal terminal guarantees.

**Actual runtime algorithm.** `lib/src/unicode_lib.dart`:

- `widthCp` validates the scalar range, handles ASCII/control ranges, and looks up the generated table. Ambiguous width is selected by `cjk`.
- `widthString` delegates to `widthChars(value.characters)`.
- `widthChars` iterates `characters` grapheme clusters. **If a cluster contains VS16 anywhere, it adds two. Otherwise, it uses only the first code point’s table width.**
- There is no independent recognition of valid ZWJ emoji, flags, keycap sequences or modifier sequences. Common cases work through grapheme segmentation plus the first scalar’s width.
- Combining-only input without VS16 uses its first combining scalar’s width, ordinarily zero. A VS16-only cluster instead returns two.
- VS15 does not explicitly demote an otherwise-wide scalar to text width.
- ANSI sequences are not parsed or stripped.

**Tests actually present.** `test/unicode_lib_test.dart` asserts fullwidth text, controls, ambiguous widths, individual emoji, `👩‍🔬`, a VS16-containing emoji, individual combining marks, default-ignorables and jamo widths. Flag assertions in that file test **emoji detection**, not flag-string width. No width assertions were found there for VS16-only input, keycaps without VS16, combining sequences with multiple marks or comprehensive grapheme/emoji sequence coverage.

**Dependency/API suitability.**

- `pubspec.yaml`: SDK `>=3.9.2 <4.0.0`; sole runtime dependency **`characters: ^1.3.0`**, compatible with existing `characters 1.4.1`.
- Thus no additional runtime package is declared beyond the project's existing `characters`; no dependency resolution was executed.
- Public `lib/termunicode.dart` exports `src/unicode_lib.dart`, including `widthCp`, `widthString`, `widthChars` and `unicodeVersion`. Width-only use needs no internal import or terminal emulator.
- Runtime width code imports `characters` and its local tables; network/filesystem imports are in separate generator tooling.
- Manifest platform declarations list Linux/macOS only. The inspected width code is platform-neutral Dart, but **Windows support was not executed or established by that metadata**.
- `LICENSE`: MIT, copyright 2024 Nelson Fernandez.
- Repository declared in the manifest: [kascote/termkit, packages/termunicode](https://github.com/kascote/termkit/tree/main/packages/termunicode). No release-to-commit mapping was established.

### Deterministic fixture implications

These are **static predictions**, not executed results. Expectations such as emoji-presentation width two are proposed Trelis policy fixtures, not guarantees for every terminal.

| Fixture | `terminal_core` | `termunicode` |
|---|---|---|
| `abc` → 3; `e\u0301` → 1; combining-only `\u0301` → 0 | Supported by source rules; related assertions present | Supported by algorithm/table policy; individual combining assertion present |
| CJK/fullwidth → 2 each | Assertions present | Assertions present |
| Common modifier/ZWJ emoji → 2 | Explicit rules; assertions present | First-scalar policy; scientist ZWJ assertion present |
| Regional-indicator flag → 2 | Explicit rule and assertion | Predicted from first-indicator table-generation policy; width assertion absent |
| `\u2764\uFE0F` (❤️) → 2 | **Predicts 1** at default ambiguous setting | Predicts 2 |
| `1\u20E3` (keycap without VS16) → 2 | Predicts 2 | **Predicts 1** from first scalar `1` |
| Standalone VS16 → 0 | Predicts 0 | **Predicts 2** |
| Standalone ZWJ → 0 | **Cluster/text helper predicts 2**, although rune helper returns 0 | No blanket ZWJ rule; governed by generated first-scalar table |

### Recommendation

**Do not select either as an unqualified, drop-in solution for the full proposed fixture set.**

`termunicode` is the stronger **candidate for a constrained width adapter**: public isolated APIs, explicit Unicode 16 tables, regeneration tooling and reuse of `characters 1.4.1`. However, its blanket VS16 promotion and first-scalar algorithm have concrete edge cases; approving it requires explicit policy acceptance or upstream fixes, plus executed fixtures against the exact pinned version.

Reject `terminal_core` for width-only adoption unless its maintainer first exposes a supported width API and establishes table provenance/update policy, with VS16 and standalone-extender fixes. Neither inspected archive demonstrates universal terminal-width correctness.

### Delegating-agent executable probe

After the read-only source audit, the delegating agent executed a temporary Dart probe importing the extracted sources, using the project's existing package configuration for characters. No project dependencies or runtime source were changed. Command: `dart --packages=C:/Users/bvlou/projects/prompty/.dart_tool/package_config.json C:/Users/bvlou/AppData/Local/Temp/trelis-width-audit-hbfo14gt/width_probe.dart`.

Observed results matched the static edge predictions: terminal_core reported heart+VS16 as 1 and standalone ZWJ as 2; termunicode reported keycap-without-VS16 as 1 and standalone VS16 as 2. Both returned the proposed widths for ASCII, accented/decomposed text, CJK, combining-only input, a flag, skin-tone emoji and scientist ZWJ emoji. termunicode reported Unicode version 16.0.0. These are executed algorithm outputs, not a real-terminal/font conformance test.

bvlou selected the pinned termunicode-table strategy behind a Trelis-owned adapter. This is not approval to use widthString blindly or to claim full sequence coverage; dependency integration and adapter fixtures remain backend implementation work.
