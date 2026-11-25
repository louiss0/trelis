# 07 Generated-file determinism, formatting, and external public API CI

Status: ready-for-agent

**Blocked by:** none

**What to build:** Make generated Dart files byte-deterministic using UTF-8 with LF newlines after formatting, regardless of host defaults. Declare LF checkout policy for generated text targets and perform the one-time normalization. Keep generated-diff verification byte strict so content drift still fails. Apply repository formatting to files currently failing the formatting gate and keep formatting before analysis/tests in CI. Put the external public API checker into the platform regression workflow as a required step; analyze the positive fixture as an external package and require every negative case to fail with its expected diagnostic. Replace source-order/literal inventory assertions with meaningful set comparisons or compile behavior. See the [spec](../spec.md), especially “Generated files and formatting” and “Public native lifecycle coverage and CI”.

## Acceptance criteria

- [ ] Generators enforce UTF-8/LF output after formatting and generated targets are covered by LF checkout policy.
- [ ] Generated files are normalized through generator/template changes only; generated-diff verification remains byte strict and catches content drift.
- [ ] The repository formatting gate passes and is ordered before analysis/tests in CI.
- [ ] External public API positive fixture is analyzed as an external package, negative cases fail with expected diagnostic codes, and the checker is a required workflow step.
- [ ] Public inventory tests compare meaningful sets or compile behavior rather than literal fixture source ordering.
- [ ] Generator, generated-diff, public API checker, formatter, analyzer, and focused tests pass.

## Comments
