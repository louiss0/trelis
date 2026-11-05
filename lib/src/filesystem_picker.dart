part of 'text_input.dart';

/// Selects an existing file without opening or changing it.
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
  }) => _FilesystemPicker(label, base, PathTarget.file).prompt(
    source: source,
    mode: mode,
    userPreference: userPreference,
    applicationPreference: applicationPreference,
    output: output,
  );
}

/// Selects an existing directory without opening or changing it.
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
  }) => _FilesystemPicker(label, base, PathTarget.directory).prompt(
    source: source,
    mode: mode,
    userPreference: userPreference,
    applicationPreference: applicationPreference,
    output: output,
  );
}

final class _PickerEntry {
  _PickerEntry(this.path, this.type);
  final String path;
  final FileSystemEntityType type;
}

final class _FilesystemPicker {
  _FilesystemPicker(this.label, this.base, this.target);
  final String label;
  final String? base;
  final PathTarget target;
  bool _active = false;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final input = PathInput(label, base: base, target: target);
      if (source is SuppliedAnswer) return input.prompt(source: source);
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          return await _terminal<String>(
            selected,
            output ?? stderr,
            (source, mode, restore) =>
                _browse(source, mode, input, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return _browse(source, selected, input);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<String>> _browse(
    PromptSource source,
    PromptMode mode,
    PathInput input, {
    void Function()? beforeClose,
  }) async {
    final scripted = source as ScriptedInput;
    if (mode == PromptMode.rich && !scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = scripted.supportsRich ? PromptMode.rich : PromptMode.linear;
    }
    var current = base ?? Directory.current.path;
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    try {
      while (true) {
        scripted.output.writeln(
          '$label. Current directory: $current. Existing ${target.name} required.',
        );
        scripted.output.writeln(
          'Open N opens a directory; Choose N chooses an entry${target == PathTarget.directory ? '; Choose selects the current directory' : ''}. Path enters a literal path. Parent, Refresh, Hidden toggle are available.',
        );
        final entries = <_PickerEntry>[];
        try {
          final listed = await Directory(current)
              .list(followLinks: false)
              .toList();
          listed.sort((a, b) => a.path.compareTo(b.path));
          for (final entry in listed) {
            final type = await FileSystemEntity.type(
              entry.path,
              followLinks: false,
            );
            entries.add(_PickerEntry(entry.path, type));
          }
          for (var i = 0; i < entries.length; i++) {
            scripted.output.writeln(
              '${i + 1}. ${path.basename(entries[i].path)} [${entries[i].type == FileSystemEntityType.file
                  ? 'file'
                  : entries[i].type == FileSystemEntityType.directory
                  ? 'directory'
                  : 'link'}]',
            );
          }
        } on FileSystemException catch (error) {
          scripted.output.writeln(
            'Cannot list $current: ${error.message}. Context retained; use Parent, Path or Refresh.',
          );
        }
        final action = await _edit(
          keys,
          '',
          scripted.output,
          linear: mode == PromptMode.linear,
          sequential: mode == PromptMode.linear,
        );
        if (action.action == 'cancel') return Cancelled();
        if (action.action == 'interrupt') return Interrupted();
        if (action.action != 'submit') return InputEnded();
        final command = action.value.toLowerCase();
        if (command == 'parent') {
          current = path.dirname(current);
          continue;
        }
        if (command == 'refresh' || command == 'hidden') continue;
        final match = RegExp(r'^(open|choose)(?: ([0-9]+))?$')
            .firstMatch(command);
        if (match != null) {
          final reference = match[2] == null ? null : int.parse(match[2]!);
          if (reference == null) {
            if (match[1] == 'choose' && target == PathTarget.directory) {
              final result = await _review(
                scripted,
                keys,
                mode,
                input,
                current,
              );
              if (result != null) return result;
              continue;
            }
            scripted.output.writeln('An entry reference is required.');
            continue;
          }
          if (reference < 1 || reference > entries.length) {
            scripted.output.writeln(
              'Invalid entry reference; listing retained.',
            );
            continue;
          }
          final entry = entries[reference - 1];
          if (match[1] == 'open') {
            if (entry.type != FileSystemEntityType.directory) {
              scripted.output.writeln(
                'Cannot open ${entry.path}: not an accessible directory or is an unapproved link.',
              );
              continue;
            }
            current = entry.path;
            continue;
          }
          if ((target == PathTarget.file &&
                  entry.type != FileSystemEntityType.file) ||
              (target == PathTarget.directory &&
                  entry.type != FileSystemEntityType.directory)) {
            scripted.output.writeln(
              'Cannot choose ${entry.path}: target must be a ${target.name}.',
            );
            continue;
          }
          final result = await _review(scripted, keys, mode, input, entry.path);
          if (result != null) return result;
          continue;
        }
        if (command == 'path') {
          scripted.output.writeln('Enter literal path:');
          final entry = await _edit(
            keys,
            '',
            scripted.output,
            linear: mode == PromptMode.linear,
            sequential: mode == PromptMode.linear,
          );
          if (entry.action == 'cancel') return Cancelled();
          if (entry.action == 'interrupt') return Interrupted();
          if (entry.action != 'submit') return InputEnded();
          final candidate = input._candidate(entry.value, current);
          final error = await input._error(candidate);
          if (error != null) {
            scripted.output.writeln('Cannot choose $candidate: $error');
            continue;
          }
          final result = await _review(scripted, keys, mode, input, candidate!);
          if (result != null) return result;
          continue;
        }
        scripted.output.writeln(
          'Unknown action; listing and context retained.',
        );
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }

  Future<PromptResult<String>?> _review(
    ScriptedInput scripted,
    _Keys keys,
    PromptMode mode,
    PathInput input,
    String candidate,
  ) async {
    final error = await input._error(candidate);
    if (error != null) {
      scripted.output.writeln('Cannot choose $candidate: $error');
      return null;
    }
    scripted.output.writeln(
      'Choose $candidate. Enter to accept, or type edit to return.',
    );
    final review = await _edit(
      keys,
      '',
      scripted.output,
      linear: mode == PromptMode.linear,
      sequential: mode == PromptMode.linear,
    );
    if (review.action == 'cancel') return Cancelled();
    if (review.action == 'interrupt') return Interrupted();
    if (review.action != 'submit') return InputEnded();
    if (review.value.isNotEmpty) return null;
    final finalError = await input._error(candidate);
    if (finalError == null) return Accepted(candidate);
    scripted.output.writeln('Cannot choose $candidate: $finalError');
    return null;
  }
}
