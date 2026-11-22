import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// FilePicker — one component, one structural theme (ChevronTheme),
/// one colour theme (ColorThemes.nordic).
///
/// Run: dart run example/chevron/file_picker.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'choose 1\r\r',
  (io) => ChevronTheme(io: io).filePicker(
    'Workspace',
    base: atlasSheetsPath,
    colors: ComponentColors.palette(ColorThemes.nordic),
  ),
);
