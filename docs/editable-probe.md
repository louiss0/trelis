# Editable-default probe — work in progress

This is **not ready for NVDA evaluation** and establishes no accessibility
support. `dart run bin/editable_probe.dart --linear` selects the draft linear
presentation; omit `--linear` for the draft rich presentation. The explicit
`--test-stream` flag is only for automated input and does not qualify a real
console. Do not enter real secrets.

Known gaps blocking evaluation: Escape does not yet dismiss a transient layer;
editing is by Unicode scalar, not grapheme; paste provenance is not tracked per
range; terminal output mode and actual Windows Terminal paste framing have not
been verified; status is only a placeholder. The interaction and lifecycle
need further automated and native-console tests before a human task script can
be executed. Unframed paste cannot be distinguished from typing and follows
ordinary entry/command rules.

## Evidence template (not observed results)

- Date, tester identifier or role (no private information):
- Windows version/build; Windows Terminal version, profile and settings:
- Shell/version; Dart version; probe git revision; NVDA version and settings:
- Presentation and exact task:
- Sanitized actions, expected outcome, observed outcome, pass/fail:
- Restoration and repeat-session observation:
- Follow-up or failure (do not include entered secrets or secret length):

After the gaps above are resolved, a human NVDA tester must discover the
instructions and, in each presentation, edit and erase a default, correct a
validation error, enter command/backslash collisions, use literal paste, edit a
synthetic hidden secret, inspect bounded status, dismiss a transient layer with
Escape, cancel at root, interrupt with Ctrl+C, and confirm terminal usability
and repeat sessions. A failure blocks qualification; no result is implied here.

## Native-console blocker observed

The draft must not be used for NVDA tasks. On this Windows command host,
`powershell -NoProfile -ExecutionPolicy Bypass -File test/editable_probe_windows.ps1`
reported `editable FAIL console state changed: 503:3:25:1 -> 1008:7:25:1`.
The harness starts a fresh console, disables VT output before launching the
probe, injects a synthetic answer, and compares input/output mode and cursor
afterward. The input mode is still raw (1008) rather than the original 503.
This failure has not been diagnosed to a specific library or API cause.
A native input/lifecycle design that demonstrably restores the original state is
required before a human session. The harness does not exercise Windows Terminal
clipboard paste framing and cannot establish that it works there.
