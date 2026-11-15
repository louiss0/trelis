# 31: Run the complete automated Windows/macOS/Linux regression matrix

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Run the complete automated component and native integration suite after all component slices are present. Demonstrate public behavior for all 38 components in rich and linear modes, plus real platform-specific input/lifecycle checks on available Windows, macOS and Linux runners. Record exact revisions, versions, failures and unexecuted coverage without converting missing infrastructure into a pass or a user-owned manual OS task.

**Blocked by:**
- [04: Deliver Password](04-password.md)
- [05: Deliver Multiline](05-multiline.md)
- [06: Deliver Autocomplete](06-autocomplete.md)
- [07: Deliver TagInput](07-tag-input.md)
- [08: Deliver Confirm, Checkbox, and Toggle](08-boolean-components.md)
- [09: Deliver Select and Radio](09-select-radio.md)
- [10: Deliver MultiSelect](10-multi-select.md)
- [11: Deliver SearchSelect](11-search-select.md)
- [12: Deliver CommandPalette](12-command-palette.md)
- [13: Deliver TimezoneSelect](13-timezone-select.md)
- [14: Deliver TreeSelect](14-tree-select.md)
- [15: Deliver SortableSelect](15-sortable-select.md)
- [16: Deliver Slider and RangeSlider](16-sliders.md)
- [17: Deliver TimeInput](17-time-input.md)
- [18: Deliver PathInput](18-path-input.md)
- [19: Deliver FilePicker and DirectoryPicker](19-filesystem-pickers.md)
- [20: Deliver Keypress and KeyChordInput](20-key-capture.md)
- [21: Deliver NumberInput](21-number-input.md)
- [22: Deliver PortInput and IPAddressInput](22-port-ip-inputs.md)
- [23: Deliver URLInput and EmailInput](23-url-email-inputs.md)
- [24: Deliver ColorInput](24-color-input.md)
- [25: Deliver MaskedInput](25-masked-input.md)
- [26: Deliver DurationInput](26-duration-input.md)
- [27: Deliver DateInput](27-date-input.md)
- [28: Deliver CronInput](28-cron-input.md)
- [29: Deliver Text, Progress, and Spinner](29-text-progress-spinner.md)
- [30: Deliver MultiSpinner](30-multi-spinner.md)

**Status:** resolved

- [x] All 38 current components are exercised through the shared public prompt/presentation seam with rich/linear task coverage and contract-specific acceptance cases.
- [x] Native lifecycle/input/restoration checks use the exact selected backend on available platform runners, including submission, Escape, Ctrl+C, EOF, errors and repeated sessions.
- [x] Platform matrix records build/analysis results, actual terminal/stream behavior, clipboard/IME/layout/rendering coverage and explicit unexecuted environment limitations.
- [x] Any real platform failure is reported with reproduction/evidence and resolved or carried into the qualification blocker; no unexecuted check is marked passing.
- [x] The user's manual testing scope remains Windows Terminal + NVDA only; this ticket supplies engineering-owned automated platform evidence rather than assigning manual OS testing.
