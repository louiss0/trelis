# Ticket 24 — formatted-values migration evidence

- **Status:** partial local verification pass; backend gate remains pending.
- **Source revision:** recorded with the implementation commit for this ticket.
- **Environment:** Windows, repository Dart SDK; scripted `StringBuffer` outputs with explicit rich profiles (100×30, cursor support, indexed-256 colour) and linear mode.

## Executed public behavior

`dart test test/formatted_values_migration_test.dart test/number_input_test.dart test/network_input_test.dart test/email_input_test.dart test/color_input_test.dart test/duration_input_test.dart --reporter expanded` exercised NumberInput, PortInput, IPAddressInput, EmailInput, ColorInput and DurationInput. It checked rich and linear behavior, compact hidden instruction forwarding, supplemental component help, explicit palette forwarding, accepted typed values, validation correction, numeric precision/nullability, CIDR/zone host-bit retention, SMTPUTF8/IDNA handling, colour parsing/preview, and elapsed/calendar duration interpretations. The command passed 56 tests.

`dart analyze` reported no issues. The full test suite is executed after the implementation commit and integration merge.

## Limitations

This evidence is scripted/public-seam coverage only. It does not replace native PTY, visible-GUI, resize/short-screen, modal-help, or Linux/macOS CI evidence required by the final backend gate.
