# 34: Ctrl+T is the universal help gesture and collides with host bindings

Status: claimed

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

## Report

`Ctrl+T` (`\x14`) opens help in every rich prompt component — text input,
multiline, password, select/multi-select, date/time, cron, masked, path,
filesystem picker, autocomplete, tree ordering, and key capture itself
(14+ dispatch sites in `lib/src/`). A reporter asks for a different
gesture: Ctrl+T is already claimed by common host environments (new tab in
browsers and many terminal emulators; transpose-chars in readline/bash),
so an embedding application or the surrounding terminal can own the chord
before the prompt sees it, and callers cannot offer it as a keybind of
their own.

Inside `KeyCapture` the conflict is already visible: while raw capture is
armed, Ctrl+T is a candidate gesture and help is unreachable — help only
opens "before or after a capture" (`lib/src/key_capture.dart` ~2018). Every
component shares one hard-coded help byte with no override.

## Modifier survey (raw control bytes consumed today)

| Gesture | Byte | Role |
| ------- | ---- | ---- |
| Ctrl+A | `\x01` | Home / select-visible (multi-select) |
| Ctrl+B | `\x02` | Move focus back (field prompts) |
| Ctrl+C | `\x03` | Interrupt — reserved everywhere |
| Ctrl+D | `\x04` | Mapped to EOF (`\x1a`) by `_posixInput` |
| Ctrl+E | `\x05` | End of line |
| Ctrl+H/I/J/M | `\x08`/`\x09`/`\x0a`/`\x0d` | Indistinguishable from Backspace, Tab, LF, CR — cannot be separate gestures |
| Ctrl+R | `\x12` | Review (multi-select) |
| Ctrl+T | `\x14` | Help — this report |
| Ctrl+X | `\x18` | Discard draft / clear visible |
| Ctrl+Z | `\x1a` | EOF — used everywhere |

Free control bytes: F `\x06`, G `\x07`, K `\x0b`, L `\x0c`, N `\x0e`,
O `\x0f`, P `\x10`, Q `\x11`, S `\x13`, U `\x15`, V `\x16`, W `\x17`,
Y `\x19`.

Convention traps among the free set: Ctrl+Q/Ctrl+S are XON/XOFF flow
control (terminal freeze; `cfmakeraw` disables it locally but scripted
sources and outer terminals still swallow them); Ctrl+D is EOF; Ctrl+Z is
suspend. Readline conventions occupy Ctrl+F/B (char motion — B already
taken), Ctrl+P/N (history), Ctrl+U/W (kill line/word), Ctrl+Y (yank),
Ctrl+L (clear screen).

Decision: **F1 is the help gesture** in every component — the universal
help key across terminals and GUIs, arriving as an escape sequence
(`\x1bOP` or `\x1b[11~`) that the existing tokenizer already parses, and
colliding with no readline, terminal, or library convention. `\x14` is
retired entirely: Ctrl+T must not remain the help gesture anywhere, not
even as a secondary binding — a retired binding is exactly what frees it
for caller-declared keybinds in `KeyCapture`. Each dispatch site swaps a
byte check for a sequence check.

Ctrl-byte fallbacks, ranked by least user disruption: Ctrl+O `\x0f`
(bash's obscure operate-and-get-next), Ctrl+G `\x07` (emacs abort; Escape
already covers cancel), Ctrl+N `\x0e` (readline next-history). Avoid
Ctrl+U/W/K/Y (kill/yank editing), Ctrl+P/F (history/motion), Ctrl+L
(clear screen), Ctrl+V (paste/literal-next), Ctrl+Q/S (XON/XOFF),
Ctrl+H/I/J/M (identical to Backspace/Tab/LF/CR — not separate gestures).

## Acceptance criteria

- [ ] Bind F1 (`\x1bOP` and `\x1b[11~` spellings) as the help gesture at
      every `\x14` dispatch site; remove the Ctrl+T byte check from all
      components with no secondary binding left behind.
- [ ] Migrate all help/guidance strings consistently, keeping
      interruption (`\x03`) and EOF (`\x1a`) reserved.
- [ ] Verify `KeyCapture` accepts a declared Ctrl+T binding once `\x14`
      is no longer consumed — the conflict resolves by the removal itself.
- [ ] Update the shared accessibility contract documentation for the
      chosen gesture.
