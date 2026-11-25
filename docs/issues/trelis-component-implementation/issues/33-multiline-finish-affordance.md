# 33: Multiline finish is undiscoverable; expected finish chord does nothing

Status: claimed

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md); delivered by [05](05-multiline.md)

## Report

A user cannot finish a `Multiline` prompt. Pressing Enter inserts a newline
(as designed), and pressing Ctrl+Enter does nothing, leaving no obvious way
to submit the accumulated lines.

The designed finish path exists but is undiscoverable: Tab cycles the
focused action through Edit → Finish → Insert tab, and Enter activates the
focused action (see `_openingParts`/`_help` and the action cycle at
`lib/src/text_input.dart` ~4813-4830 and ~5327-5340). A user who never
presses Tab can type forever with no route to acceptance and no on-screen
affordance naming the finish gesture.

## Proposed mechanism: split CR from LF

The rich loop currently collapses both bytes
(`key == '\r' || key == '\n'`, ~line 5332). Splitting them adds a real
finish chord while keeping every existing path:

- **`\r` (CR)** keeps today's behaviour: activates the focused action
  (Finish / Insert tab) or inserts a newline while Edit is focused. Enter
  delivers CR on POSIX raw input and Windows console, so
  Tab → Finish → Enter is unchanged.
- **`\n` (LF)** finishes immediately: validate and accept regardless of
  the focused action. LF is delivered by **Ctrl+J** on every POSIX
  terminal, and **Ctrl+Enter** reports character 0x0A on the Windows
  console input path — one byte gives both chords.

Safe inputs: bracketed paste arrives framed as a single `\x1b[200~…\x1b[201~`
key and is consumed before this branch, so pasted newlines stay literal;
the reader's `_afterCarriageReturn` collapse keeps CRLF on the `\r` path.

## Risks

- **Unframed paste** cannot be distinguished from typing; a multi-line
  paste without markers would hit `\n` and submit prematurely. Either
  gate the LF-finish binding behind detection/config, or accept and
  document the regression — must be decided here.
- Terminals delivering LF for Enter invert the two meanings (Enter would
  finish). Rare in raw mode but needs evidence before shipping.
- Windows Ctrl+Enter with VT input enabled may arrive as an enhanced
  escape sequence instead of 0x0A; Ctrl+J remains the guaranteed chord.
- Alternative: keep Enter semantics untouched and fix discoverability
  only (always-visible action bar naming Finish).

## Acceptance criteria

- [ ] Decide whether the finish affordance is a defect (users cannot
      complete the prompt) or a discoverability gap, and whether Enter's
      newline behaviour should remain unconditional.
- [ ] Either bind a documented finish chord (e.g. LF/Ctrl+J with the CR/LF
      split above, verified against paste and `\x1a` EOF handling) or make
      the focused action/Finish visible without requiring a Tab press.
- [ ] Update opening guidance and help text to name the real finish gesture.
