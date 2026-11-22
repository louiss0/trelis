import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// FilePicker — one component, one structural theme (LineTheme),
/// one colour theme (ColorThemes.nordic).
///
/// Run: dart run example/line/file_picker.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'choose 1\r\r',
  (io) => LineTheme(io: io).filePicker(
    'Workspace',
    base: atlasSheetsPath,
    colors: ComponentColors.palette(ColorThemes.nordic),
  ),
);
