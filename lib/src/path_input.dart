part of 'text_input.dart';

/// The type of target expected by [PathInput].
enum PathTarget { any, file, directory }

/// Enters a literal native path without shell expansion or link resolution.
final class PathInput {
  PathInput(
    this.label, {
    this.base,
    this.initialValue = '',
    this.allowNonexistent = false,
    this.target = PathTarget.any,
  }) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (base != null &&
        (!path.isAbsolute(base!) ||
            (Platform.isWindows &&
                !RegExp(r'^(?:[a-zA-Z]:[\\/]|[\\/]{2}[^\\/]+[\\/][^\\/]+)')
                    .hasMatch(base!)))) {
      throw ArgumentError.value(base, 'base', 'Must be absolute');
    }
  }
  final String label;
  final String? base;
  final String initialValue;
  final bool allowNonexistent;
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
      final capturedBase = base ?? Directory.current.path;
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
                _run(source, mode, capturedBase, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, capturedBase);
    } finally {
      _active = false;
    }
  }

  String? _candidate(String value, String base) {
    if (value.isEmpty ||
        value.contains('\x00') ||
        value.contains('\r') ||
        value.contains('\n')) {
      return null;
    }
    if (Platform.isWindows && RegExp(r'^[a-zA-Z]:(?![\\/])').hasMatch(value)) {
      return null;
    }
    if (Platform.isWindows &&
        (value.startsWith(r'\') || value.startsWith('/')) &&
        !value.startsWith(r'\\') &&
        !value.startsWith('//')) {
      return '${path.rootPrefix(base)}${value.substring(1)}';
    }
    if (path.isAbsolute(value)) return value;
    return '$base${path.separator}$value';
  }

  Future<String?> _error(String? candidate) async {
    if (candidate == null) {
      return 'Enter a non-empty valid native path; drive-relative paths are not supported.';
    }
    if (allowNonexistent && target == PathTarget.any) return null;
    try {
      final type = await FileSystemEntity.type(candidate);
      if (type == FileSystemEntityType.notFound) {
        final failure = _pathInspectionFailure(candidate);
        if (failure != null) return failure;
        return allowNonexistent ? null : 'Target must exist.';
      }
      if (target == PathTarget.file && type != FileSystemEntityType.file) {
        return 'Target must be a file.';
      }
      if (target == PathTarget.directory &&
          type != FileSystemEntityType.directory) {
        return 'Target must be a directory.';
      }
      return null;
    } on FileSystemException catch (error) {
      return 'Cannot inspect target: ${error.message}';
    }
  }

  Future<PromptResult<String>> _run(
    PromptSource source,
    PromptMode mode,
    String base, {
    void Function()? beforeClose,
  }) async {
    if (source is SuppliedAnswer) {
      final candidate = _candidate(source.value, base);
      final error = await _error(candidate);
      return error == null ? Accepted(candidate!) : Unavailable(error);
    }
    final scripted = source as ScriptedInput;
    if (mode == PromptMode.rich && !scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = scripted.supportsRich ? PromptMode.rich : PromptMode.linear;
    }
    scripted.output.writeln(
      '$label. Base: $base. ${allowNonexistent ? 'Nonexistent targets permitted' : 'Existing target required'}; target type: ${target.name}.',
    );
    scripted.output.writeln(
      'Literal native path; no shell expansion. Returned paths do not guarantee later operations succeed.',
    );
    scripted.output.writeln(
      'Enter edits the path, then review and confirm. Escape cancels; Ctrl+C interrupts; Ctrl+T opens help.',
    );
    if (mode == PromptMode.linear) {
      scripted.output.writeln(
        r'Exact /help and /cancel are commands; quote them with a backslash. Double a leading backslash: enter three for a UNC pair. Identified paste is literal.',
      );
    }
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    var draft = initialValue;
    try {
      while (true) {
        final edit = await _edit(
          keys,
          draft,
          scripted.output,
          linear: mode == PromptMode.linear,
          sequential: mode == PromptMode.linear,
        );
        if (edit.action == 'cancel') return Cancelled();
        if (edit.action == 'interrupt') return Interrupted();
        if (edit.action != 'submit') return InputEnded();
        draft = edit.value;
        final candidate = _candidate(draft, base);
        final error = await _error(candidate);
        if (error != null) {
          scripted.output.writeln(
            'Base: $base. Candidate: ${candidate ?? draft}. $error',
          );
          continue;
        }
        scripted.output.writeln(
          'Base: $base. Resolved candidate: $candidate. Enter to accept, or type edit to correct.',
        );
        while (true) {
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
          if (review.value.isEmpty) return Accepted(candidate!);
          if (review.value == 'edit') break;
          scripted.output.writeln('Enter to accept, or type edit to correct.');
        }
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }
}

// Dart's type() maps filesystem errors to notFound. Probe again with native
// error codes and fail closed when the absence cannot be established.
String? _pathInspectionFailure(String candidate) {
  try {
    if (Platform.isWindows) {
      final kernel = DynamicLibrary.open('kernel32.dll');
      final attributes = kernel
          .lookupFunction<
            Uint32 Function(Pointer<Utf16>),
            int Function(Pointer<Utf16>)
          >('GetFileAttributesW');
      final lastError = kernel
          .lookupFunction<Uint32 Function(), int Function()>('GetLastError');
      final name = candidate.toNativeUtf16();
      try {
        final result = attributes(name);
        if (result != 0xffffffff) return 'Cannot inspect target type.';
        final code = lastError();
        if (code == 2) return null;
        if (code == 3) {
          // ERROR_PATH_NOT_FOUND also covers a regular file used as a parent.
          // Inspect raw prefixes without normalizing symlink-sensitive dots.
          var prefix = candidate;
          final rootLength = path.rootPrefix(candidate).length;
          while (prefix.length > rootLength) {
            final slash = prefix.lastIndexOf(RegExp(r'[\\/]'));
            if (slash < rootLength) {
              prefix = candidate.substring(0, rootLength);
            } else {
              prefix = prefix.substring(0, slash);
              if (prefix.length < rootLength) {
                prefix = candidate.substring(0, rootLength);
              }
            }
            final parentName = prefix.toNativeUtf16();
            try {
              final parent = attributes(parentName);
              if (parent != 0xffffffff) {
                return (parent & 0x10) != 0
                    ? null
                    : 'A path parent is not a directory.';
              }
              final parentError = lastError();
              if (parentError != 2 && parentError != 3) {
                return 'Cannot inspect target parent (Windows error $parentError).';
              }
            } finally {
              calloc.free(parentName);
            }
            if (prefix.length <= rootLength) break;
          }
          return 'Cannot inspect target parent.';
        }
        return 'Cannot inspect target (Windows error $code).';
      } finally {
        calloc.free(name);
      }
    }
    if (Platform.isLinux ||
        Platform.isAndroid ||
        Platform.isMacOS ||
        Platform.isIOS) {
      final libc = DynamicLibrary.process();
      final access = libc
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, int)
          >('access');
      final errno = libc
          .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
            Platform.isMacOS || Platform.isIOS
                ? '__error'
                : Platform.isAndroid
                ? '__errno'
                : '__errno_location',
          );
      final name = candidate.toNativeUtf8();
      try {
        if (access(name, 0) == 0) return 'Cannot inspect target type.';
        final code = errno().value;
        if (code == 2) return null;
        return 'Cannot inspect target (filesystem error $code).';
      } finally {
        calloc.free(name);
      }
    }
    return 'Cannot determine whether target exists on this platform.';
  } catch (_) {
    return 'Cannot determine whether target exists.';
  }
}
