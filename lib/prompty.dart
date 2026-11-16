/// Accessible, nonvisually reviewable terminal prompts for Dart.
///
/// The package exposes one prompt-session seam: every component returns a
/// sealed [PromptResult] of `Accepted`, `Cancelled`, `Interrupted`,
/// `InputEnded` or `Unavailable`, and every component supports a rich
/// in-place interaction and a sequential linear one.
///
/// See the `README.md` sections per component for keys, linear commands and
/// validation rules, and `doc/editable-probe.md` plus
/// `doc/ticket-31-regression-evidence.md` for the executed evidence and the
/// recorded limits. Accessibility qualification of the whole library remains
/// blocked pending the human Windows Terminal + NVDA baseline.
library;

export 'src/text_input.dart';
export 'src/feedback.dart';
export 'src/output_profile.dart';
export 'src/color_theme.dart';
export 'src/prompt_structure.dart';
export 'src/terminal_io.dart';
export 'src/themes/plain_theme.dart';
export 'src/themes/rail_theme.dart';
export 'src/themes/branch_theme.dart';
export 'src/themes/box_theme.dart';
export 'src/themes/round_theme.dart';
export 'src/themes/double_theme.dart';
export 'src/themes/minimal_theme.dart';
export 'src/themes/ascii_theme.dart';
export 'src/themes/chevron_theme.dart';
export 'src/themes/bracket_theme.dart';
export 'src/themes/form_theme.dart';
export 'src/themes/ledger_theme.dart';
export 'src/themes/colon_theme.dart';
