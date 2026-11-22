# Ticket 06 — Unicode TextInput mapping evidence

**Status:** focused automated evidence; not a terminal/font conformance claim.

## Source, dependency and policy

- Source base: `abe1c6e`; this record is committed with the implementation.
- Environment: Windows 10.0.26200, Dart 3.13.2 stable.
- `termunicode` is pinned as direct dependency to **0.2.0**. `pubspec.lock` resolves archive SHA-256 `20ef06647ccaad83fcf9609901897ddb04ae904d9d16617347a2ee1adea6b6ce`.
- The package declares Unicode UCD 16.0.0 and MIT license (copyright 2024 Nelson Fernandez), as audited in `assets/research/trelis-output-capabilities-and-width.md`.
- `TextDisplayMap` retains `characters` grapheme segmentation and calls only public termunicode scalar/property APIs (`widthCp`, `isNonPrintableCp`); it does not use `widthString` or `widthChars`.
- Policy: normal supported clusters use their leading scalar under a declared narrow/wide ambiguous policy; keycaps and visible VS16 clusters are two cells; selector-only/combining-only clusters are zero; unsupported controls, formats, bidi controls and a terminal ZWJ are visible `\u{XXXX}` text. Tabs are represented visibly, never expanded/emitted as terminal tabs.

## Executed checks

`dart test test/text_measurement_test.dart test/text_input_test.dart --reporter expanded`

Expected/actual: mapping fixtures cover decomposed accent, CJK, narrow/wide ambiguity, flags, modifier and ZWJ emoji, VS15/VS16 keycaps, standalone combining/format content, tabs/newlines/ESC/bidi controls, original grapheme caret offsets, and public TextInput acceptance. The public case retains the exact original Unicode answer while unsafe terminal-format content is visibly encoded.

## Limitation

These deterministic fixture widths are the Trelis policy for Unicode 16 data, not a promise that every terminal emulator, locale or font allocates the same cells. No physical terminal/font measurement is asserted.
