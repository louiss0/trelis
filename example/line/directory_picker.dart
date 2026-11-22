import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// DirectoryPicker — one component, one structural theme (LineTheme),
/// one colour theme (ColorThemes.ink).
///
/// Run: dart run example/line/directory_picker.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'choose\r\r',
  (io) => LineTheme(io: io).directoryPicker(
    'Workspace',
    base: atlasSheetsPath,
    colors: ComponentColors.palette(ColorThemes.ink),
  ),
);
