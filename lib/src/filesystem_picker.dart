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
  _PickerEntry(this.path, this.type, this.stat);
  final String path;
  final FileSystemEntityType type;
  final FileStat stat;

  bool get isCurrent {
    try {
      final current = Link(path).statSync();
      return current.type == stat.type &&
          current.mode == stat.mode &&
          current.size == stat.size &&
          current.changed == stat.changed &&
          current.modified == stat.modified;
    } on FileSystemException {
      return false;
    }
  }
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
      if (source is SuppliedAnswer) {
        return await input.prompt(source: source);
      }
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
      return await _browse(source, selected, input);
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
    var showHidden = false;
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    try {
      while (true) {
        scripted.output.writeln(
          '$label. Current directory: $current. Existing ${target.name} required.',
        );
        scripted.output.writeln(
          'Open N opens a directory; Choose N chooses an entry${target == PathTarget.directory ? '; Choose selects the current directory' : ''}. Path enters a literal path. Parent, Refresh, Hidden toggle are available.',
        );
        scripted.output.writeln(
          'Hidden entries: ${showHidden ? 'shown' : 'hidden'}. Links require explicit per-open approval. The base is not a sandbox.',
        );
        final entries = <_PickerEntry>[];
        try {
          final listed = await Directory(current)
              .list(followLinks: false)
              .toList();
          listed.sort((a, b) => a.path.compareTo(b.path));
          for (final entry in listed) {
            final attributes = _windowsAttributes(entry.path);
            final hidden =
                path.basename(entry.path).startsWith('.') ||
                (attributes != null && attributes & 0x2 != 0);
            if (!showHidden && hidden) continue;
            final stat = await Link(entry.path).stat();
            final linked =
                stat.type == FileSystemEntityType.link ||
                (attributes != null && attributes & 0x400 != 0);
            entries.add(
              _PickerEntry(
                entry.path,
                linked ? FileSystemEntityType.link : stat.type,
                stat,
              ),
            );
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
        if (command == 'refresh') continue;
        if (command == 'hidden') {
          showHidden = !showHidden;
          continue;
        }
        final match = RegExp(r'^(open|choose)(?: ([0-9]+))?( links)?$')
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
          if (!entry.isCurrent) {
            scripted.output.writeln(
              'Entry reference $reference is stale; refreshing instead of targeting a replacement.',
            );
            continue;
          }
          if (match[1] == 'open') {
            final linked = entry.type == FileSystemEntityType.link;
            if (linked && match[3] == null) {
              scripted.output.writeln(
                'Cannot open linked directory ${entry.path} without explicit opt-in; use open $reference links.',
              );
              continue;
            }
            if (!linked && match[3] != null) {
              scripted.output.writeln('Link approval only applies to links.');
              continue;
            }
            if (await FileSystemEntity.type(entry.path) !=
                FileSystemEntityType.directory) {
              scripted.output.writeln(
                'Cannot open ${entry.path}: not an accessible directory.',
              );
              continue;
            }
            try {
              final resolved = await Directory(entry.path)
                  .resolveSymbolicLinks();
              var ancestor = await Directory(current).resolveSymbolicLinks();
              while (true) {
                if (ancestor == resolved) {
                  scripted.output.writeln(
                    'Cannot open ${entry.path}: linked-directory cycle to $resolved; current directory retained.',
                  );
                  break;
                }
                final parent = path.dirname(ancestor);
                if (parent == ancestor) {
                  if (linked) {
                    scripted.output.writeln(
                      'Linked traversal approved for this open: ${entry.path}.',
                    );
                  }
                  current = entry.path;
                  break;
                }
                ancestor = parent;
              }
            } on FileSystemException catch (error) {
              scripted.output.writeln(
                'Cannot resolve linked directory ${entry.path}: ${error.message}; current directory retained.',
              );
            }
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

int? _windowsAttributes(String candidate) {
  if (!Platform.isWindows) return null;
  try {
    final kernel = DynamicLibrary.open('kernel32.dll');
    final attributes = kernel
        .lookupFunction<
          Uint32 Function(Pointer<Utf16>),
          int Function(Pointer<Utf16>)
        >('GetFileAttributesW');
    final name = candidate.toNativeUtf16();
    try {
      final result = attributes(name);
      return result == 0xffffffff ? null : result;
    } finally {
      calloc.free(name);
    }
  } catch (_) {
    return null;
  }
}
