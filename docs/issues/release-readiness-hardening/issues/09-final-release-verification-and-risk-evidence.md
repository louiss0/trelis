# 09 Final verification battery and remaining-risk evidence

Status: claimed

**Blocked by:** [01](01-input-event-crlf-and-multiline-finish.md), [02](02-conpty-staging-and-diagnostics.md), [03](03-native-f1-help-contracts.md), [04](04-public-native-fixture-routes.md), [05](05-ci-public-native-lifecycle-coverage.md), [06](06-deterministic-tests-and-environment-honesty.md), [07](07-generated-files-formatting-and-public-api-ci.md), [08](08-prerelease-docs-version-and-release-evidence.md)

**What to build:** Run and record the complete release-verification battery on the integration branch: formatting, static analysis, documentation links, tracker integrity, full Dart tests, generated-file byte verification, external public API positive/negative checks, corrected Windows native scenarios, and available POSIX/native workflow evidence. Using the new diagnostics, investigate the intermittent framed-multiline paste failure and record either a fixed root cause or a bounded environmental explanation with remaining risk explicit. Confirm documentation/version agreement, absence of stable/accessibility overclaims, and that independent interaction and colour gates remain ready-for-human. Resolve any integration regressions uncovered by the battery. See the [spec](../spec.md), especially “Verification sequence for the implementing agent”.

## Acceptance criteria

- [ ] Formatting, analyzer, documentation-link checker, tracker checker, full Dart test suite, generated-file checker, and external public API checker all pass on the integration branch or explicit platform limits are recorded.
- [ ] Corrected Windows native TextInput and multiline ConPTY scenarios pass through public or explicitly named compatibility routes as applicable; POSIX evidence/status is accurately recorded.
- [ ] The intermittent framed-multiline failure is either root-caused/fixed or documented as a bounded environmental risk using captured diagnostics.
- [ ] Prerelease documentation/version agree and human interaction/colour gates remain explicit blockers.
- [ ] Final verification evidence is recorded in this ticket’s Answer with exact commands and outcomes.

## Comments
