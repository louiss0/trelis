part of 'text_input.dart';

/// Selects an existing file.
final class FilePicker {
  FilePicker(this.label, {this.base});
  final String label;
  final String? base;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) => PathInput(label, base: base, target: PathTarget.file).prompt(
    source: source,
    mode: mode,
    userPreference: userPreference,
    applicationPreference: applicationPreference,
    output: output,
  );
}

/// Selects an existing directory.
final class DirectoryPicker {
  DirectoryPicker(this.label, {this.base});
  final String label;
  final String? base;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) => PathInput(label, base: base, target: PathTarget.directory).prompt(
    source: source,
    mode: mode,
    userPreference: userPreference,
    applicationPreference: applicationPreference,
    output: output,
  );
}
