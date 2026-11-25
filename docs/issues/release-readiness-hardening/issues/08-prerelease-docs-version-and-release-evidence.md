# 08 Prerelease version, migration documentation, and honest release evidence

Status: ready-for-agent

**Blocked by:** [01](01-input-event-crlf-and-multiline-finish.md), [07](07-generated-files-formatting-and-public-api-ci.md)

**What to build:** Reconcile package versioning, changelog, README, migration guidance, examples, and release evidence with the implemented public API and open human gates. Change the package version to 1.0.0-dev.1 while interaction and colour gates remain incomplete. Rewrite changelog entries for the package rename, breaking theme-instance cutover, removed APIs, new key gestures, remaining instability, and missing human evidence. Migrate user-facing examples to exported theme instances and parameterless prompt methods; remove or clearly quarantine internal compatibility examples as contributor-only test material. Correct supplied-answer, invocation-level output/session configuration, direct-constructor, and static-factory claims. Document scripted input honestly as an explicit stream environment, the exact termunicode pin as an accepted Unicode-data policy, and documentation-directory publish warnings as accepted project-structure tradeoffs. Record publish dry-run output as evidence only and keep interaction/colour gates ready-for-human without stable/accessibility overclaims. See the [spec](../spec.md), especially “Documentation, version and release evidence”.

## Acceptance criteria

- [ ] `pubspec.yaml` version is `1.0.0-dev.1` and all public unstable-status messaging agrees with it.
- [ ] README and migration documentation teach only supported public theme-instance usage to package consumers; internal compatibility examples are absent or explicitly contributor/test scoped.
- [ ] Changelog accurately separates rename, breaking cutover, removed APIs, key gestures, prerelease instability, and missing human evidence; false compatibility claims are gone.
- [ ] Scripted input, exact Unicode pin, documentation-directory warning, publish dry-run evidence, and open interaction/colour human gates are documented truthfully.
- [ ] No stable API, accessibility qualification, screen-reader usability, or real-terminal colour-quality claim is made without required human evidence.
- [ ] Documentation-link and tracker checks plus focused tests pass.

## Comments
