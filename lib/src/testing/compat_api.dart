/// Internal compatibility barrel for component-level tests.
///
/// This library is intentionally absent from `package:trelis/trelis.dart`.
/// It preserves the pre-cutover component construction seam for tests that
/// exercise real components directly; the public API is theme instances.
library;

export 'package:trelis/src/text_input.dart';
export 'package:trelis/src/feedback.dart';
export 'package:trelis/src/output_profile.dart';
export 'package:trelis/src/color_theme.dart';
export 'package:trelis/src/prompt_structure.dart';
export 'package:trelis/src/terminal_io.dart';
export 'package:trelis/src/testing/compat_themes/ascii_theme.dart';
export 'package:trelis/src/testing/compat_themes/block_theme.dart';
export 'package:trelis/src/testing/compat_themes/box_theme.dart';
export 'package:trelis/src/testing/compat_themes/bracket_theme.dart';
export 'package:trelis/src/testing/compat_themes/branch_theme.dart';
export 'package:trelis/src/testing/compat_themes/chevron_theme.dart';
export 'package:trelis/src/testing/compat_themes/colon_theme.dart';
export 'package:trelis/src/testing/compat_themes/double_theme.dart';
export 'package:trelis/src/testing/compat_themes/form_theme.dart';
export 'package:trelis/src/testing/compat_themes/ledger_theme.dart';
export 'package:trelis/src/testing/compat_themes/line_theme.dart';
export 'package:trelis/src/testing/compat_themes/minimal_theme.dart';
export 'package:trelis/src/testing/compat_themes/plain_theme.dart';
export 'package:trelis/src/testing/compat_themes/rail_theme.dart';
export 'package:trelis/src/testing/compat_themes/round_theme.dart';
