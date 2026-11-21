import 'package:trelis/src/testing/compat_api.dart';

Future<void> main(List<String> args) async {
  final mode = args[0].endsWith('linear') ? PromptMode.linear : PromptMode.rich;
  final result = args[0].startsWith('file')
      ? await FilePicker('File', base: args[1]).prompt(mode: mode)
      : await DirectoryPicker('Directory', base: args[1]).prompt(mode: mode);
  if (result is Accepted<String>) {
    print(result.value);
  } else {
    print('failure: ${result.runtimeType}');
  }
}
