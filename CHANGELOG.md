## 1.0.0

- The Dart package is renamed from `prompty` to `trelis` to match the
  project name. The package entry point moves from `lib/prompty.dart` to
  `lib/trelis.dart` and every import changes:
  `import 'package:prompty/prompty.dart';` ->
  `import 'package:trelis/trelis.dart';`.
- No component, API, behavior, theme, palette or outcome changed. This is a
  packaging and naming migration only.
- Migration guidance: `doc/evidence/trelis-package-rename/migration.md`.

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
- Presentation recording separates the current editable view from ordered,
  identified events. Query and results events carry a typed projection that
  states idle/loading/ready/empty/failure explicitly, keeps source-stable choice
  references distinct from response-local autocomplete candidates, and records a
  candidate acceptance separately from the prompt outcome. The projection is an
  internal contract observed through the transcript, not an exported authoring
  type.
- Compatibility with the pre-backend surface is preserved: direct constructors,
  generic parameters, callbacks, answer types, commands and the five prompt
  outcomes are unchanged. Invocation adds `terminal`, `outputProfile` and
  `session`; interactive constructors add `instructions`, `supplementaryHelp`
  and, where implemented, `colors`. Defaults stay the plain reference
  presentation with terminal-native colours, synthetic rich output must declare
  cursor support and positive geometry, and no package or import was renamed.
  Component help is component- and stage-specific in both interactions, keeping
  help access and protected content under every instruction policy.
- Windows and POSIX terminal backends that own the selected input and output
  streams, check and restore native console state, reject concurrent sessions
  and refuse rich output on non-capable terminals such as `TERM=dumb`.
- Accessibility status: component-level automated and native checks are
  recorded in `doc/ticket-31-regression-evidence.md`; the whole-library
  Windows Terminal + NVDA baseline in `doc/nvda-inventory.md` has not been
  performed, so no accessibility qualification is claimed.
- Corrections from the final backend review: a component colour is applied to
  each wrapped line instead of being measured as text, rejected answers use the
  palette error role, protected text is encoded by one display-escaping policy,
  feedback that has retired is not replayed after help, a running standalone
  feedback region truly owns its sink, and `terminalSgr`/`terminalStyledText`
  never invent a colour for a depth that cannot show one. Evidence is in
  `doc/evidence/trelis-backend/final-review-fixes.md`.
