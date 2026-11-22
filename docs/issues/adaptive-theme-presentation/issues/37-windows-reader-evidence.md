# 37 Collect Windows Terminal and NVDA human evidence

Status: ready-for-human

**Blocked by:** [32](32-public-api-cutover.md), [35](35-windows-native-hint.md)

**What to build:** A human must exercise the cutover and gated Windows binding with actual Windows Terminal and NVDA. Record reproducible environment, setup, utterances and observed usability, not just synthetic detection tests. Do not enable the gate here. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```text
# PROPOSED NOT IMPLEMENTED: evidence record shape
terminal: Windows Terminal
reader: NVDA
result: pass | fail | not tested
```

## Acceptance criteria

- [ ] Record human tester, date, Windows, Windows Terminal, NVDA and package versions, settings, locality and exact reproduction steps.
- [ ] With NVDA on and off, verify and record the native parameter and selected interaction, including explicit on/off and rich override; distinguish signal from usability.
- [ ] Exercise representative actual interactive prompts, choices, errors, essential and detailed help, navigation and feedback; record what NVDA announces and any failures.
- [ ] Exercise prompt plus live feedback, cleanup and a later active period; report whether re-detection and interaction remain usable.
- [ ] Record relevant native fixture and automated test commands/results alongside actual human observations, without presenting simulations as reader evidence.
- [ ] Document Narrator limitation, untested terminals/readers and remote or ambiguous locality; failed or missing evidence blocks Windows enablement.

## Comments

2026-11-22: Partial agent-run fixture and automated evidence at `54d7af2`:

- Windows `10.0.26200.0`, Dart `3.13.2` on `windows_x64`.
- `dart run tool/windows_reader_fixture.dart`: binding available; fixture-only
  gate enabled; observation `ScreenReaderObservation.negative`. The production
  gate remains off. A negative parameter is not proof that no reader is active.
- `dart test test/hint_observations_session_test.dart test/windows_reader_hint_test.dart -r expanded`:
  14 tests passed, including simulated locality, explicit preferences, and
  observation after cleanup.
- The agent session had no computer-use tool or audio observation, and found no
  running NVDA or Windows Terminal process. No NVDA on/off run, utterances,
  interactive usability, terminal version or locality was verified. The native
  fixture and synthetic tests are not reader usability evidence.
- Narrator does not set this parameter. Other readers, terminals and remote or
  ambiguous locality remain untested in this run. Windows enablement remains
  blocked pending the required human evidence.

2026-11-22: Agent GUI check using Orca computer use, without NVDA:
opened Windows Terminal, ran `dart run example/rail/text_input.dart` from the
repository directory, entered `staging`, and pressed Enter. The screen showed
`Deployment target (Optional)`, keyboard instructions and `Accepted: staging`.
This is a visual smoke check only, not evidence of NVDA announcements, reader
usability, native signal selection or accessibility qualification. Windows
Terminal version and session locality were not established. No NVDA process was
observed. The required reader-on and reader-off comparison remains outstanding.
