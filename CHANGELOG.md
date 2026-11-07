## 1.0.0

- 38 prompt and feedback components over one public session seam: text and
  secret entry, multiline, autocomplete, tags, booleans, single and multiple
  choice, search, command palette, timezones, trees, ordering, sliders, time,
  paths, filesystem pickers, key capture, numbers, ports and addresses, URLs,
  e-mail, colour, masks, durations, dates, cron, and progress, spinner and
  multi-task feedback.
- Every component supports a rich in-place interaction and a sequential linear
  one, with editable defaults, persistent validation guidance, reviewable final
  state and the layered `Accepted`, `Cancelled`, `Interrupted`, `InputEnded` and
  `Unavailable` outcomes.
- Windows and POSIX terminal backends that own the selected input and output
  streams, check and restore native console state, reject concurrent sessions
  and refuse rich output on non-capable terminals such as `TERM=dumb`.
- Accessibility status: component-level automated and native checks are
  recorded in `docs/ticket-31-regression-evidence.md`; the whole-library
  Windows Terminal + NVDA baseline in `docs/nvda-inventory.md` has not been
  performed, so no accessibility qualification is claimed.
