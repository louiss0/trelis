# GUI example pass checkpoint

Revision: a9e7f1c. Native Windows Terminal via Orca; no scripted or redirected input. Screenshots in this directory. Existing earlier completed inventory reported by delegator: ascii/autocomplete.dart, ascii/checkbox.dart, ascii/text_input.dart and rail/checkbox.dart (last two post-fix). Root demos deliberately deleted by user; not run or restored.

| File | Command | Input | Observed result | Evidence |
|---|---|---|---|---|
| ascii/color_input.dart | `dart run example/ascii/color_input.dart` | Return with default #fff | Accepted: Instance of 'ColorValue'; shell ready | ascii-color-input-initial.png, ascii-color-input-outcome.png |
| ascii/command_palette.dart | `dart run example/ascii/command_palette.dart` | Down, Return | Save focused, Accepted: save; shell ready | ascii-command-palette-initial.png, ascii-command-palette-action.png, ascii-command-palette-outcome.png |
| ascii/confirm.dart | `dart run example/ascii/confirm.dart` | y, Return | Draft Yes; Accepted: true; shell ready | ascii-confirm-initial.png, ascii-confirm-action.png, ascii-confirm-outcome.png |

| ascii/cron_input.dart | `dart run example/ascii/cron_input.dart` | Paste `* * * * *`, Return | Accepted: Instance of 'CronExpression'; shell ready | ascii-cron-input-{initial,action,outcome}.png |
| ascii/date_input.dart | `dart run example/ascii/date_input.dart` | Full-date paste rejected; paste 29, Tab, 02, Tab, 2024, Return, Tab, Return | Review 2024-02-29; Accepted: Instance of 'CivilDate'; shell ready | ascii-date-input-{initial,action,outcome}.png |
| ascii/directory_picker.dart | `dart run example/ascii/directory_picker.dart` | `choose`, Return, Return | Reviewed and accepted atlas sheets directory; shell ready | ascii-directory-picker-{initial,action,outcome}.png |

| ascii/duration_input.dart | `dart run example/ascii/duration_input.dart` | Paste `1s`, Return | Preview 1000000 microseconds; Accepted: Instance of 'DurationValue'; shell ready | ascii-duration-input-{initial,action,outcome}.png |
| ascii/email_input.dart | `dart run example/ascii/email_input.dart` | Paste `Case@example.com`, Return | Accepted: Case@example.com; shell ready | ascii-email-input-{initial,action,outcome}.png |
| ascii/file_picker.dart | `dart run example/ascii/file_picker.dart` | `choose 1`, Return, Return | Reviewed and accepted atlas sheets/01-signal.png; shell ready | ascii-file-picker-{initial,action,outcome}.png |

| ascii/ip_address_input.dart | `dart run example/ascii/ip_address_input.dart` | Paste `192.0.2.7/24`, Return | Accepted: Instance of 'IPAddressValue'; shell ready | ascii-ip-address-input-{initial,action,outcome}.png |

| ascii/keypress.dart | `dart run example/ascii/keypress.dart` | c, a, Return | Reviewed A (observed); Accepted: Instance of 'KeyGesture'; shell ready | ascii-keypress-{initial,action,outcome}.png |

| ascii/key_chord_input.dart | `dart run example/ascii/key_chord_input.dart` | c, a, c, b, Return | Reviewed A and B (observed); Accepted two KeyGesture instances; shell ready | ascii-key-chord-input-{initial,action,outcome}.png |

| ascii/masked_input.dart | `dart run example/ascii/masked_input.dart` | Backspace, 3, Return | Draft changed 1-2 to 1-3; Accepted: Instance of 'MaskedValue'; shell ready | ascii-masked-input-{initial,action,outcome}.png |

| ascii/multiline.dart | `dart run example/ascii/multiline.dart` | Paste `Synthetic notes`, Tab (Finish), Return | Accepted: Synthetic notes; shell ready | ascii-multiline-{initial,action,outcome}.png |

| ascii/multi_select.dart | `dart run example/ascii/multi_select.dart` | Space, Down, Space, Return | Both selected; Accepted: [a, b]; shell ready | ascii-multi-select-{initial,action,outcome}.png |

| ascii/multi_spinner.dart | `dart run example/ascii/multi_spinner.dart` | None (feedback) | Download, Compile, Package completed; shell ready | ascii-multi-spinner-outcome.png |

| ascii/number_input.dart | `dart run example/ascii/number_input.dart` | Paste 12, Return | Accepted: Instance of 'NumericAnswer'; shell ready | ascii-number-input-{initial,outcome}.png |

| ascii/password.dart | `dart run example/ascii/password.dart` | Paste synthetic, Return, paste submit, Return | Accepted: synthetic; shell ready (synthetic only, helper prints value) | ascii-password-{initial,action,outcome}.png |

| ascii/path_input.dart | `dart run example/ascii/path_input.dart` | Return, Return | Reviewed and accepted resolved `draft` path; shell ready | ascii-path-input-{initial,action,outcome}.png |

| ascii/port_input.dart | `dart run example/ascii/port_input.dart` | Paste 443, Return | Accepted: 443; shell ready | ascii-port-input-{initial,outcome}.png |

| ascii/progress.dart | `dart run example/ascii/progress.dart` | None (feedback) | Download completed: 3 items; shell ready | ascii-progress-outcome.png |

| ascii/radio.dart | `dart run example/ascii/radio.dart` | Down, Return | Green selected; Accepted: b; shell ready | ascii-radio-{initial,outcome}.png |

| ascii/range_slider.dart | `dart run example/ascii/range_slider.dart` | Left, Tab, Right, Tab, Tab, Tab, Return | Lower 2 upper 6; Accepted: (2, 6); shell ready | ascii-range-slider-{initial,action,outcome}.png |

| ascii/search_select.dart | `dart run example/ascii/search_select.dart` | Down, Return | Apple focused; Accepted: a; shell ready | ascii-search-select-{initial,outcome}.png |

| ascii/select.dart | `dart run example/ascii/select.dart` | Down, Return | Second selected; Accepted: b; shell ready | ascii-select-{initial,outcome}.png |

| ascii/slider.dart | `dart run example/ascii/slider.dart` | Right, Tab, Tab, Return | Value 0.6; Accepted: 0.6; shell ready | ascii-slider-{initial,action,outcome}.png |

| ascii/sortable_select.dart | `dart run example/ascii/sortable_select.dart` | Down, Space, Up, Space, Return | B moved to first; Accepted: [b, a]; shell ready | ascii-sortable-select-{initial,action,outcome}.png |

| ascii/spinner.dart | `dart run example/ascii/spinner.dart` | None (feedback) | Connecting completed; shell ready | ascii-spinner-outcome.png |

| ascii/tag_input.dart | `dart run example/ascii/tag_input.dart` | Paste NewTag, Return, Tab, Return | Added and Accepted: [new-tag]; shell ready | ascii-tag-input-{initial,action,outcome}.png |

| ascii/text.dart | `dart run example/ascii/text.dart` | None (feedback) | Success: Configuration saved; shell ready | ascii-text-outcome.png |

| ascii/timezone_select.dart | `dart run example/ascii/timezone_select.dart` | Paste New_York, Down, Return | Accepted: America/New_York; shell ready | ascii-timezone-select-{initial,outcome}.png |

| ascii/time_input.dart | `dart run example/ascii/time_input.dart` | Down, Tab, Tab, Tab, Return | Draft 22:59; Accepted hour 22 minute 59; shell ready | ascii-time-input-{initial,action,outcome}.png |

| ascii/toggle.dart | `dart run example/ascii/toggle.dart` | Space, Return | Draft on; Accepted: true; shell ready | ascii-toggle-{initial,outcome}.png |

| ascii/tree_select.dart | `dart run example/ascii/tree_select.dart` | Up, Return | A selected; Accepted: a; shell ready | ascii-tree-select-{initial,outcome}.png |

| ascii/url_input.dart | `dart run example/ascii/url_input.dart` | Paste https://example.com/, Return | Accepted: https://example.com/; shell ready | ascii-url-input-{initial,outcome}.png |

| block/autocomplete.dart | `dart run example/block/autocomplete.dart` | Tab, Return | Suggestion Ada inserted; Accepted: Ada; shell ready | block-autocomplete-outcome.png |

ASCII pass complete including earlier reported autocomplete, checkbox and text_input. Automated native GUI replay inventory (command, inputs, asserted outcome, per-file screenshot) is `progress-automated.jsonl`; batches 1–5, all block files (autocomplete separately, rest PowerShell name sort), were visually inspected in contact sheets. GUI keys/pastes use Orca; console observation is read-only. The block/file_picker screenshot visibly confirms the full Accepted path; subsequent runs assert that full path. Batches 6–10 all box files visually inspected. Batches 11–15 all bracket files visually inspected. All branch files visually inspected in five contact sheets. All chevron files visually inspected in five contact sheets. All colon files visually inspected in five contact sheets. All double files visually inspected in five contact sheets. Next unrun: form/autocomplete.dart. Current terminal: PowerShell shell ready. GUI observations do not establish screen-reader or human qualification.
