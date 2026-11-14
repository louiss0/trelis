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
export 'src/presentation.dart'
    show
        DisplayText,
        QueryResultRow,
        QueryResultsIdentityModel,
        QueryResultsNotice,
        QueryResultsPhase,
        QueryResultsPresentation;
export 'src/feedback.dart';
export 'src/output_profile.dart';
export 'src/color_theme.dart';
export 'src/terminal_io.dart';
