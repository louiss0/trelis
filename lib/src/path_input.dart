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
    this.colors = ColorThemes.terminalDefault,
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
  final ColorTheme colors;
  bool _active = false;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      // The base is captured when the invocation starts so an attached session
      // and a later repaint both use the same stable location.
      final capturedBase = base ?? Directory.current.path;
      Future<PromptResult<String>> run(
        PromptSource source,
        PromptMode mode, {
        OutputProfile? outputProfile,
        _Keys? keys,
        TerminalSession? session,
      }) => _run(
        source,
        mode,
        capturedBase,
        outputProfile: outputProfile,
        keys: keys,
        session: session,
      );
      if (session != null) {
        return await session._promptRunner<String>(
          run,
          source: source,
          mode: mode,
          userPreference: userPreference,
          applicationPreference: applicationPreference,
          output: output,
          terminal: terminal,
          outputProfile: outputProfile,
        );
      }
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          if (terminal != null) {
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => run(
                ScriptedInput(
                  terminal.input,
                  terminal.output,
                  supportsRich: terminal.supportsRich,
                  outputProfile: _terminalOutputProfile(terminal),
                  hardColorDisabled:
                      terminal.environment['NO_COLOR']?.isNotEmpty == true,
                  resizeObserver: _terminalResizeObserver(terminal),
                ),
                selected,
                outputProfile: outputProfile,
              ),
              lease.restore,
            );
          }
          return await _terminal<String>(
            selected,
            output ?? stderr,
            (source, mode, _) =>
                run(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await run(source, selected, outputProfile: outputProfile);
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
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final candidate = _candidate(source.value, base);
      final error = await _error(candidate);
      return error == null ? Accepted(candidate!) : Unavailable(error);
    }
    final scripted = source as ScriptedInput;
    var effectiveProfile = _constrainToObservedGeometry(
      OutputProfile.resolve(
        invocation: outputProfile,
        source: scripted.outputProfile,
        supportsRich: scripted.supportsRich,
      ),
      scripted._observedGeometry,
    );
    if (scripted._hardColorDisabled) {
      effectiveProfile = effectiveProfile.copyWith(colorDepth: ColorDepth.none);
    }
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    final out = scripted.output;
    final width = _textInputWidth(effectiveProfile);
    final linear = mode == PromptMode.linear;
    void write(String text, TerminalColor foreground) {
      final wrapped = StringBuffer();
      _writeWrappedText(wrapped, DisplayText.from(text).value, width);
      for (final line in wrapped.toString().split('\n')) {
        if (line.isNotEmpty) {
          out.writeln(
            _colorText(line, foreground, colors.background, effectiveProfile),
          );
        }
      }
    }

    write(
      '$label. Base: $base. ${allowNonexistent ? 'Nonexistent targets permitted' : 'Existing target required'}; target type: ${target.name}.',
      colors.foreground,
    );
    write(
      'Literal native path; no shell expansion. Returned paths do not guarantee later operations succeed.',
      colors.muted,
    );
    write(
      linear
          ? r'Enter edits the path, then review and confirm. Exact /help and /cancel are commands; quote them with a backslash. Double a leading backslash: enter three for a UNC pair. Identified paste is literal. Escape cancels; Ctrl+C interrupts.'
          : 'Enter edits the path, then review and confirm. Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
      colors.muted,
    );
    final entryHelp = _pathEntryHelp(
      linear: linear,
      allowNonexistent: allowNonexistent,
      target: target,
      base: base,
    );
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    var draft = initialValue;
    try {
      while (true) {
        final edit = await _edit(
          inputKeys,
          draft,
          out,
          linear: linear,
          sequential: linear,
          clearHelpCommand: true,
          helpText: entryHelp,
          linearHelpText: entryHelp,
          outputProfile: effectiveProfile,
          session: session,
        );
        if (edit.action == 'cancel') return Cancelled();
        if (edit.action == 'interrupt') return Interrupted();
        if (edit.action != 'submit') return InputEnded();
        draft = edit.value;
        final candidate = _candidate(draft, base);
        final error = await _error(candidate);
        if (error != null) {
          write(
            'Base: $base. Candidate: ${candidate ?? draft}. $error',
            colors.warning,
          );
          continue;
        }
        write(
          'Base: $base. Resolved candidate: $candidate. Enter to accept, or type edit to correct.',
          colors.accent,
        );
        final reviewHelp = _pathReviewHelp(
          linear: linear,
          candidate: candidate!,
          allowNonexistent: allowNonexistent,
          target: target,
        );
        while (true) {
          final review = await _edit(
            inputKeys,
            '',
            out,
            linear: linear,
            sequential: linear,
            clearHelpCommand: true,
            helpText: reviewHelp,
            linearHelpText: reviewHelp,
            outputProfile: effectiveProfile,
            session: session,
          );
          if (review.action == 'cancel') return Cancelled();
          if (review.action == 'interrupt') return Interrupted();
          if (review.action != 'submit') return InputEnded();
          if (review.value.isEmpty) return Accepted(candidate);
          if (review.value == 'edit') break;
          write('Enter to accept, or type edit to correct.', colors.warning);
        }
      }
    } finally {
      if (keys == null) await inputKeys.close();
    }
  }
}

/// Component help for the path-entry stage, led by the current action.
///
/// It carries the interpretation and safety context that compact guidance
/// cannot: literal-path and escaping rules, the base and the existence/type
/// policy, and the absence of shell expansion, link canonicalization and
/// later-operation guarantees.
String _pathEntryHelp({
  required bool linear,
  required bool allowNonexistent,
  required PathTarget target,
  required String base,
}) {
  final existence = allowNonexistent
      ? 'Prospective paths are permitted, so a target that does not exist can be returned.'
      : 'The target must already exist.';
  final type = switch (target) {
    PathTarget.any => 'Any target type is accepted.',
    PathTarget.file => 'The target must be a file.',
    PathTarget.directory => 'The target must be a directory.',
  };
  final controls = linear
      ? r'Enter submits the path for review; an empty line submits the current draft. Exact /help and /cancel are commands, and /help is cleared instead of being typed into the path; enter \/help or \/cancel for those literal paths, double a leading backslash to enter one, and enter three for a UNC pair. Identified paste is literal; unframed paste cannot be distinguished from typing.'
      : 'Enter submits the path for review. Ctrl+T opens this help; Escape dismisses help or cancels; Ctrl+C interrupts.';
  return 'Help: PathInput accepts one literal native path relative to $base. Entry is not evaluated by a shell, so there is no variable, tilde or glob expansion, no quote stripping, no link canonicalization and no working-directory change; .. segments are retained and a drive-relative Windows path such as C:name is rejected. $existence $type A path with an unusable name, an uninspectable target, or a parent that is not a directory is rejected rather than assumed absent. FilePicker and DirectoryPicker browse the filesystem instead, and opening a link there requires explicit per-open approval. Review shows the resolved candidate before it is returned. Nothing is created, opened or changed, and the result is a snapshot: later filesystem operations can still fail. $controls';
}

/// Component help for the review stage of a typed path.
///
/// Review keeps the resolved candidate and the policy visible, restates that a
/// disabled-looking entry is a snapshot, and names the non-accepting return to
/// entry rather than implying that the first Enter always accepts.
String _pathReviewHelp({
  required bool linear,
  required String candidate,
  required bool allowNonexistent,
  required PathTarget target,
}) {
  final existence = allowNonexistent
      ? 'Nonexistent targets are permitted by this invocation.'
      : 'The target was required to exist at inspection time.';
  final type = switch (target) {
    PathTarget.any => 'no target type is required',
    PathTarget.file => 'a file target was required',
    PathTarget.directory => 'a directory target was required',
  };
  final controls = linear
      ? r'Enter accepts the reviewed candidate; type edit and press Enter to return to path entry without accepting. Exact /help and /cancel are commands, and /help is cleared instead of being accepted; enter \/help for that literal path. Escape cancels; Ctrl+C interrupts.'
      : 'Enter accepts the reviewed candidate; type edit to return to path entry without accepting. Ctrl+T opens this help; Escape dismisses help or cancels; Ctrl+C interrupts.';
  return 'Help: PathInput review. The candidate ${DisplayText.from(candidate).value} was resolved from the captured base and is returned only after this review. $existence, $type, and nothing was opened, created or changed. Existence and type are a snapshot rather than permission, so a later filesystem operation can still fail. $controls';
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
