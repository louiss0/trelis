# Backend platform evidence — ticket 31

## Verdict: pending, not accepted

Runtime baseline: integration `de7ed84c9795de29c2b55d24717c17be4b113881`.
Tested harness revision: `23aff9b` (no production changes).
Environment: Windows 10.0.26200, Dart 3.13.2 windows_x64.

## Executed locally

- `dart test --reporter expanded`: 926 passed, exit 0.
- `dart analyze`: no issues.
- `dart format --output=none --set-exit-if-changed .`: 150 files, zero changes.
- `dart run tool/check_doc_links.dart`: 155 links in 54 Markdown files.
- `test/text_input_windows.ps1`: rich, linear-cursor, linear-long,
  help-text-linear, help-text-rich, help-password-linear,
  help-password-rich, help-password-interrupt-linear, help-text-eof-rich,
  redirected, dumb-auto, escape, interrupt, eof, error, repeat and
  session-retire passed. The linear-long scenario was rerun after the
  harness correction below; the other sixteen passed before that correction.
- `test/multiline_conpty_windows.ps1`: framed-command, typed-command,
  framed-multiline, editing, function-key and application-navigation passed.

Raw local artifacts: `%TEMP%/prompty-ticket31-native/` (not uploaded or
committed). Initial failure artifacts are retained separately in
`%TEMP%/prompty-final-native-de7ed84/`.

## Red/green harness corrections

The original password-help probe injected `secret` and searched for that
common word in help. This failed with `help disclosed hidden entry`.
Changing only the synthetic value and exact canary check to
`TrelisCanary7Q9` passed, with the expected accepted result and restored
console state. Generic secret-related help must not be mistaken for answer
content. No production secret rendering was changed.

The old long-line probe required the last `9` to remain visible following
an insertion at the viewport edge. The shared viewport reserves overflow
marker cells, and legitimately displayed `8X>` instead of `8X9`.
The screen assertion now accepts either truthful shape on the original
editor row; the existing exact accepted-answer assertion still requires
all 300 original characters plus the insertion. The rerun passed with
console state `503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1`.

## Required evidence still missing

No Windows, Ubuntu or macOS **CI** job was executed. `git remote -v`
returns no remotes; `gh repo view --json nameWithOwner,url` reports
`no git remotes found`. No repository destination was invented, created
or published. An authorized CI repository/remote and a run at the final
accepted revision are needed. Configured workflows are not execution.

Linux/macOS native PTY scenarios remain unexecuted. Local Windows probes
are not substitutes. The complete new profile/session/resize/failure
native matrix still needs an explicit coverage audit and final-revision
runs. This report does not claim whole-library native qualification.

Ticket 31 remains unresolved. Ticket 33 and theme integration remain
blocked; a native console probe is not visible GUI/NVDA evidence.
