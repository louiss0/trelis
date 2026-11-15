# Current Trelis component help inventory

Read-only source audit captured during theming charting. This records existing behavior, not approved replacement copy. Sources are relative to the repository root; line numbers are snapshot pointers.

## Shared editor

lib/src/text_input.dart:243–513 supplies generic rich editing help and linear command/quoting help. This is not a universal component-specific help menu. Temporary help screens depend on terminal capability; otherwise help remains in the transcript.

## Component findings

| Component/family | Existing opening and help considerations | Source |
|---|---|---|
| TextInput | Opening includes constraints and editing keys. Shared rich help omits Home/End advertised at opening. | text_input.dart:163–228 |
| Password | Hidden entry, separate submit/edit/clear/help/cancel stage. Masking discloses length; prefill retained in memory. These warnings are separate from help. | text_input.dart:1086–1173 |
| Confirm / Checkbox / Toggle | Default/draft and kind-specific keys; linear yes/no/empty-default workflow. Existing rich help. | text_input.dart:1269–1357 |
| Multiline | Newline and Finish/Insert tab workflow; linear list/edit/insert/remove/done commands and confirmation prompts. Component-specific rich help. | text_input.dart:1441–1671 |
| Select / Radio | Stable choice references, pages, selection/navigation keys. Existing rich help and linear command help. | text_input.dart:1866–2008 |
| MultiSelect | Selection limits, filter/select-visible/clear-visible/review and done commands. Workflow must remain discoverable. | text_input.dart:2092–2341 |
| Slider / RangeSlider | Adjustment and Edit/Submit controls; linear endpoint entry and pair review. | text_input.dart:2474–2577,2710–2905 |
| TreeSelect | Expansion/navigation and selectable-node workflow; linear open/up/choose plus reference prompts. | text_input.dart:3016–3266 |
| TimeInput | Segmented adjustment without wrapping; edit/submit actions and linear format guidance. | text_input.dart:3366–3492 |
| TagInput | Add/discard/edit/remove/finish workflow. Opening does not advertise help; shared rich help is not full tag help. | text_input.dart:3578–3650 |
| Autocomplete | Candidate inspect/accept versus text submit distinctions. Rich suggestion loop lacks dedicated help. | autocomplete.dart:66–179,195–315 |
| SearchSelect / CommandPalette / TimezoneSelect | Query/results focus; entering results does not accept. Focus-specific rich help. Wrappers reuse SearchSelect. | search_select.dart:298–421; command_palette.dart; timezone_select.dart |
| SortableSelect | Pick up/drop/move/submit and Escape revert semantics. Existing rich help; linear stable-reference move prompts. | sortable_select.dart:134–232 |
| MaskedInput | Slot rules, formatted/raw entry and template ambiguity workflow. Fixed rich slot loop lacks dedicated help. | masked_input.dart:236–362,533–568,783–826 |
| NumberInput | Numeric convention, separators, examples, digit repertoire, bounds and precision are in opening; help is generic editor help. | number_input.dart:600–649 |
| PortInput / IPAddressInput | Range/CIDR/zone interpretation and explicit absence of availability/reachability checks. Generic help. | network_input.dart:4–18,63–79 |
| EmailInput | Bare SMTP syntax, SMTPUTF8 conditions and no deliverability check; domain interpretation output. Generic help. | url_email_input.dart:193–205,273–300 |
| URLInput | Hidden draft avoids embedded-credential disclosure; no network check. Shared help exists but opening does not advertise access. | url_email_input.dart:117–171 |
| ColorInput | CSS sRGB syntax, alpha order and precision; explicitly approximate hex preview. Generic help. | color_input.dart:24–65 |
| DurationInput | Duration mode, grammar, sign/zero, precision and bounds; live interpretation. Generic help. | duration_input.dart:124–169 |
| CronInput | Profile, preview configuration and expression/edit/preview/submit review workflow. No dedicated cron-syntax help. | cron_input.dart:485–504,672–818 |
| DateInput | Calendar, order, digits, bounds, era, example, date-only semantics and review stage. Rich segmented editor lacks dedicated help. | date_input.dart:499–617,636–725 |
| PathInput | Base, requirements, literal path, no shell expansion, later-operation caveat, review and linear backslash rules. Generic help. | path_input.dart:116–189 |
| FilePicker / DirectoryPicker | Open/Choose/Path/Parent/Refresh/Hidden commands, directory context, explicit link approval, base not a sandbox. Rich also uses textual commands. No browser-specific full help. | filesystem_picker.dart:117–217,333 onward |
| Keypress / KeyChordInput | Capture/declare/remove/clear/submit; declaration unverified, reserved interruption keys and ambiguous modifiers. Rich action loop lacks dedicated help; linear opening omits /help. | key_capture.dart:21–28,164–309 |
| Text / Progress / Spinner / MultiSpinner | Feedback-only components; semantic prefixes and lifecycle/status output. No interaction help needed. | feedback.dart:7–35,43–389 |

All source filenames in the table are under lib/src/. Demo introductions and atlas sheet framing are excluded.

## Design implications, not yet resolved contracts

Separate instructions, compact hints, full help, context/state, warnings, validation, preview/interpretation, and action/review prompts. Do not simply hide all opening output. Some domain guidance must gain a home in full component help before opening guidance can safely be compacted. Help availability, access and dismissal need explicit coverage in both modes and at transient/review stages.
