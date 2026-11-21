# 32 Coordinate the breaking public API cutover

Status: claimed

**Blocked by:** [10](10-rail-ink-blue.md), [11](11-ascii-ink-blue.md), [12](12-double-ink-blue.md), [13](13-chevron-ink-blue.md), [14](14-colon-ink-blue.md), [15](15-box-rust.md), [16](16-bracket-rust.md), [17](17-block-rust.md), [18](18-branch-plum.md), [19](19-round-plum.md), [20](20-line-plum.md), [21](21-minimal-sepia.md), [22](22-plain-sepia.md), [23](23-form-sepia.md), [24](24-ledger-sepia.md), [25](25-text-secret-multiline.md), [26](26-boolean-and-basic-choices.md), [27](27-tree-search-order.md), [28](28-formatted-values.md), [29](29-filesystem-network.md), [30](30-key-capture.md), [31](31-feedback-components.md)

**What to build:** Replace static theme classes and public direct component constructors with reusable theme instances and instance methods, in one coordinated breaking cutover. Remove public invocation-level configuration, `SuppliedAnswer` and `SuppliedTags`; preserve public result and component-value types. Internal old/new coexistence is expand-migrate-contract only, not a permanent second public API. Migrate generators, generated files, all examples, tests, fixtures, exports and documentation together; never leave staged public breaks. Explain alternatives for supplied answers without promising scripted input is equivalent. This is an unstable signature cutover, not an accessibility claim. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
final theme = RailTheme(io: environment);
final prompt = theme.textInput('Name');
final result = await prompt.prompt();
// Last active component releases resources automatically.
```

## Acceptance criteria

- [ ] All 15 themes and every interactive and feedback family compile through instance methods; external-package fixtures verify return types and reject static factories and direct constructors.
- [ ] Public API inventory rejects invocation-time I/O, session, mode and presentation configuration, `SuppliedAnswer` and `SuppliedTags`; preserve result, choice and value types.
- [ ] Update and run theme factory and test generators, generated-diff checks, analyzer, tests, examples and native fixtures where available in the same buildable change set; record commands and results.
- [ ] Migration guidance covers constructors, parameterless prompt calls, feedback methods, color defaults, essential help and supplied-answer alternatives, explicitly noting scripted input is not always equivalent.
- [ ] Test reusable prompts reset their configured initial value; EOF returns `InputEnded`, concurrent prompts are rejected and feedback can outlive a prompt.
- [ ] Test automatic last-component cleanup, cleanup/start races, later reacquisition and re-detection, caller-owned streams, failures and callback behavior without a public close.
- [ ] Mark the API unstable pending independent interaction and colour gates; preserve safety behavior and record unverified native and human evidence.
