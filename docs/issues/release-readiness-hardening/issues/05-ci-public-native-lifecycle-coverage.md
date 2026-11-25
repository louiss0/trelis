# 05 Windows and POSIX CI public native lifecycle coverage

Status: ready-for-agent

**Blocked by:** [02](02-conpty-staging-and-diagnostics.md), [04](04-public-native-fixture-routes.md)

**What to build:** Switch Windows release scenarios to the public-route fixture behavior and make POSIX PTY scenarios invoke explicitly public scenario names. Scenario output names identify both route and behavior. Any remaining legacy compatibility execution is labeled compatibility coverage and is not counted as public lifecycle evidence. Keep native coverage focused on acquisition/restoration, input decoding, modal help, resize observation, output refusal, writer-failure retirement, and process-signal behavior rather than duplicating every component happy path. Update the platform regression workflow so Linux, macOS, and Windows evidence meaningfully exercises the exported route. See the [spec](../spec.md).

## Acceptance criteria

- [ ] Windows native lifecycle release jobs exercise public theme-instance routes and are named accordingly.
- [ ] POSIX PTY scenarios pass explicitly public scenario names on Linux and macOS.
- [ ] Legacy compatibility execution, if retained, is explicitly labeled and excluded from public lifecycle evidence.
- [ ] Workflow names, artifact names, and scenario output make route plus behavior clear.
- [ ] Platform regression workflow syntax is valid and relevant local/native checks pass or platform limitations are explicitly recorded.

## Comments
