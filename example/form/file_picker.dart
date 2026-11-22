import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// FilePicker — one component, one structural theme (FormTheme),
/// one colour theme (ColorThemes.nordic).
///
/// Run: dart run example/form/file_picker.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'choose 1\r\r',
  (io) => FormTheme(io: io).filePicker(
    'Workspace',
    base: atlasSheetsPath,
    colors: ComponentColors.palette(ColorThemes.nordic),
  ),
);
