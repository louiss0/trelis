# Editable-default probe

This experimental probe is not an accessibility qualification. It requires
Windows console stdin and stderr, owns stdin for its duration, and does not
consume redirected stdin unless `--test-stream` is explicitly selected for
automated tests. Use only synthetic text and synthetic secrets. The agent's
NVDA observations below are not a human usability review or qualification.

The probe requests bracketed paste. Identified bracketed paste is literal data,
requires Enter, and control-containing paste is rejected. Without framing,
pasted bytes are indistinguishable from typed bytes and follow ordinary command
rules. A native console injection test supplies framed bytes; that test does not
prove which framing Windows Terminal sends for clipboard paste.

The Dart launcher itself enabled VT output when the native harness started it
with VT initially disabled (`503:3` became `503:7` even for `dart --version`).
The probe snapshots and restores the modes it receives; its native regression
uses the normal `503:7` launcher baseline. It cannot promise restoration to a
pre-launch output mode that the Dart launcher changed before `main`.

## Human Windows Terminal + NVDA task script

Record observations, not what should have happened. Never enter a real secret or record its length.

1. Record the environment using the template below. Start NVDA and Windows
   Terminal, open the repository in the recorded shell, and use `dart --version`.
2. For each mode, run `dart run bin/editable_probe.dart` (plain-rich) and
   `dart run bin/editable_probe.dart --linear` (linear). Without looking at this
   document's key descriptions, discover the label, initial value and help.
   Use Ctrl+T for help if necessary; Escape should dismiss help, and a second
   Escape at root should cancel. Verify the shell remains usable.
3. Restart in each mode. Correct the initial `alpha` using navigation and
   deletion; erase it, press Enter and check the required error remains
   discoverable; enter a replacement and submit. Check the status identifies
   the completed validation step.
4. Run linear mode with `--default=/cancel`, then with a leading-backslash
   default (quote it as required by the shell). Edit near the initial value and
   submit; confirm the accepted synthetic text is correct, with no extra
   representation backslash. Test `/help`, `/cancel`, and quoted literal
   `\/cancel`. Record whether clipboard paste of command-looking synthetic text
   is identified as literal; an unframed paste may follow command rules.
5. On the hidden secret stage, type a throwaway secret, press Enter, choose
   `edit`, revise it, then `submit`. Check no secret or length is exposed in
   output or status. Test `clear` and required-empty validation separately.
   Record NVDA's actual typing feedback without transcribing the secret.
6. Restart, open help and press Ctrl+C. Confirm interruption rather than
   acceptance. Separately test root Escape and a successful submission, and
   type a harmless shell command after each to check terminal usability. Repeat
   both modes. Report any failure or inability to complete a task; a failure
   blocks qualification.

## Environment and evidence template

- Date, tester role (no private information):
- Windows version/build; Windows Terminal version, profile and settings:
- Shell/version; Dart version; probe git revision; NVDA version and settings:
- Presentation and task number:
- Sanitized actions, expected outcome, observed outcome, pass/fail:
- Restoration and repeat-session observation:
- Follow-up (do not include secret text or length):

## Agent-observed Windows Terminal + NVDA evidence

An AI agent operated the GUI through Orca and observed actual NVDA `Speaking`
debug entries. This was not an experienced human usability review and does not
qualify the probe for accessibility. The environment was Windows 11 25H2
build 10.0.26200.9711 AMD64, Windows Terminal 1.24.12741.0 with Nushell
0.108.0, Dart 3.13.2 stable windows_x64, and probe revision
`5f7badeed2747b652aa76f753669ab576cd76e23`. NVDA was 2026.3 AMD64,
with the desktop keyboard layout and OneCore David en_US voice. Temporary
`--log-level=10` logging was used to observe speech; normal logging was restored.

In both plain-rich and linear presentations, the agent observed discoverable
instructions and help, help-layer Escape followed by root Escape cancellation,
erasure of the editable `alpha` default and recovery from the required error
with replacement `beta`, and bounded validation 1/2 and 2/2. Hidden synthetic
secret entry did not echo the secret or its length in speech or output. The
edit/revise/submit path and clear plus required-empty validation passed. Ctrl+C
while help was open interrupted the probe, and the shell was usable after exits.

In linear mode, exact `/help` and `/cancel` commands passed; `\/cancel` was
literal. Defaults of `/cancel` and `\alpha` (one leading backslash) were
submitted literally. A real clipboard paste of synthetic `/cancel` was framed
and treated as data; after editing it to `/cancelX`, the returned text was
literal. The standard observed framing was `ESC[200~`, `/cancel`, `ESC[201~`.
An initial paste rejection was reproducibly explained by a PowerShell pipeline
adding an unintended trailing newline to `--text-stdin`, not by an app defect.
Control-containing paste remains rejected; unframed paste retains the command
limitation described above.

## Clipboard framing check

In Windows Terminal with NVDA optional, run linear mode with an empty default:

```powershell
dart run bin/editable_probe.dart --linear --default=
```

Put the synthetic text `/cancel` on the Windows clipboard and use the configured
Windows Terminal paste gesture. Press Enter. If the probe opens hidden secret
entry, the paste was framed and treated as data; if it reports `cancel`, it was
unframed and treated as a command. Record the terminal version, profile and
paste settings. Do not infer framing from the native injection test; the
agent-observed clipboard result above applies only to that recorded environment.

Framed paste is limited to 4096 UTF-16 code units. Longer frames are discarded
as a unit; the previous draft remains. Linear mode prints reviewable sequential
states; plain-rich redraw uses the terminal's saved cursor position rather than
assuming grapheme count equals display width. Actual output and screen-reader
usability are subject to the manual verification above.