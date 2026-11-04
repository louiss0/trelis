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
  }) async {
    final selected =
        mode ?? userPreference ?? applicationPreference ?? PromptMode.automatic;
    if (source is! ScriptedInput || selected != PromptMode.linear) {
      return PathInput(label, base: base, target: PathTarget.directory).prompt(
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
      );
    }
    final current = base ?? Directory.current.path;
    final input = PathInput(label, base: current, target: PathTarget.directory);
    final keys = _Keys(source.input.transform(utf8.encoder));
    try {
      while (true) {
        source.output.writeln(
          'Current directory: $current. Choose current directory: choose. Enter a path: path.',
        );
        final action = await _edit(
          keys,
          '',
          source.output,
          linear: true,
          sequential: true,
        );
        if (action.action == 'cancel') return Cancelled();
        if (action.action == 'interrupt') return Interrupted();
        if (action.action != 'submit') return InputEnded();
        var candidate = current;
        if (action.value == 'path') {
          source.output.writeln('Enter literal path:');
          final entry = await _edit(
            keys,
            '',
            source.output,
            linear: true,
            sequential: true,
          );
          if (entry.action == 'cancel') return Cancelled();
          if (entry.action == 'interrupt') return Interrupted();
          if (entry.action != 'submit') return InputEnded();
          final resolved = input._candidate(entry.value, current);
          if (resolved == null) {
            source.output.writeln('Invalid path: ${entry.value}');
            continue;
          }
          candidate = resolved;
        } else if (action.value != 'choose') {
          continue;
        }
        final error = await input._error(candidate);
        if (error != null) {
          source.output.writeln('Cannot choose $candidate: $error');
          continue;
        }
        source.output.writeln(
          'Choose $candidate. Enter to accept, or type edit to return.',
        );
        final review = await _edit(
          keys,
          '',
          source.output,
          linear: true,
          sequential: true,
        );
        if (review.action == 'cancel') return Cancelled();
        if (review.action == 'interrupt') return Interrupted();
        if (review.action != 'submit') return InputEnded();
        if (review.value.isNotEmpty) continue;
        final finalError = await input._error(candidate);
        if (finalError == null) return Accepted(candidate);
        source.output.writeln('Cannot choose $candidate: $finalError');
      }
    } finally {
      await keys.close();
    }
  }
}
