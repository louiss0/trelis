# 32: Qualify the whole library with Windows Terminal + NVDA

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Perform and record the whole-library Windows Terminal + NVDA accessibility baseline for all 38 components in plain-rich and linear modes. Real users complete representative tasks, correction, review and safe exit in the exact recorded environment, with experienced NVDA usability review. Produce an explicit pass/block qualification verdict and known-limitations record, not a universal accessibility claim.

**Blocked by:**
- [31: Run the complete automated Windows/macOS/Linux regression matrix](31-cross-platform-regression-matrix.md)

**Status:** claimed

- [ ] Every one of the 38 components completes its applicable nonvisual representative task suite in both plain-rich and linear modes, including no-color/nonanimated and error/cancellation behavior.
- [ ] The qualification manifest records actual Windows/terminal/shell/NVDA versions/settings, layout/IME, locale, protocols, rendering profile, application/backend/provider revisions and exact test cases.
- [ ] Experienced NVDA usability review and sanitized observed evidence distinguish successful completion, workaround use, failure, unavailable configuration and unverified combinations; no raw secrets are retained.
- [ ] A failed or incomplete required baseline task blocks the whole-library claim and reopens the relevant design/backend decision rather than silently weakening it.
- [ ] A passing verdict limits claims to the exact qualified environment/profiles, retains impact-based regression/release-smoke requirements, and does not imply other layouts/readers/OSes are supported.

## Progress note (agent)

Engineering-side deliverables are in place on branch `ticket/32-nvda-qualification`
(merged with `integration/trelis-components`): the private manifest generator,
380-case inventory with embedded protocols, 34 risk subchecks, the
`bin/nvda_fixtures.dart` public-component runner, `bin/nvda_session.py` for
recording declared observations one case at a time, `bin/nvda_validate.py` for
integrity and declared-completeness checks, the workflow guide in
`docs/nvda-inventory.md`, and automated checks (811 Dart tests, 22 Python tests,
plus a CI qualification-tooling job).

Nothing in the checklist above is checked: no human case has been observed, so
the verdict remains blocked. The remaining work is the tester's NVDA session in
Windows Terminal, then the experienced usability review, sanitization review and
claim-scope/limitations record. Run `--gaps` to see exactly which declarations
are still placeholders.
