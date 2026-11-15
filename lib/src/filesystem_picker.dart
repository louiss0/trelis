part of 'text_input.dart';

/// Selects an existing file without opening or changing it.
final class FilePicker {
  FilePicker(
    this.label, {
    this.base,
    this.colors = ColorThemes.terminalDefault,
    this.instructions = InstructionDisplay.themeDefault,
    this.supplementaryHelp = const [],
  }) : _picker = _FilesystemPicker(
         label,
         base,
         PathTarget.file,
         colors,
         instructions,
         supplementaryHelp,
       );
  final String label;
  final String? base;
  final ColorTheme colors;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final _FilesystemPicker _picker;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) => _picker.prompt(
    source: source,
    mode: mode,
    userPreference: userPreference,
    applicationPreference: applicationPreference,
    output: output,
    terminal: terminal,
    outputProfile: outputProfile,
    session: session,
  );
}

/// Selects an existing directory without opening or changing it.
final class DirectoryPicker {
  DirectoryPicker(
    this.label, {
    this.base,
    this.colors = ColorThemes.terminalDefault,
    this.instructions = InstructionDisplay.themeDefault,
    this.supplementaryHelp = const [],
  }) : _picker = _FilesystemPicker(
         label,
         base,
         PathTarget.directory,
         colors,
         instructions,
         supplementaryHelp,
       );
  final String label;
  final String? base;
  final ColorTheme colors;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final _FilesystemPicker _picker;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) => _picker.prompt(
    source: source,
    mode: mode,
    userPreference: userPreference,
    applicationPreference: applicationPreference,
    output: output,
    terminal: terminal,
    outputProfile: outputProfile,
    session: session,
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
      final attributes = _windowsAttributes(path);
      final linked =
          FileSystemEntity.typeSync(path, followLinks: false) ==
              FileSystemEntityType.link ||
          (attributes != null && attributes & 0x400 != 0);
      final currentType = linked ? FileSystemEntityType.link : current.type;
      return currentType == type &&
          current.type == stat.type &&
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
  _FilesystemPicker(
    this.label,
    this.base,
    this.target,
    this.colors,
    this.instructions,
    this.supplementaryHelp,
  );
  final String label;
  final String? base;
  final PathTarget target;
  final ColorTheme colors;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  bool _active = false;

  String get _component =>
      target == PathTarget.directory ? 'DirectoryPicker' : 'FilePicker';

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
      final input = PathInput(
        label,
        base: base,
        target: target,
        colors: colors,
        instructions: instructions,
        supplementaryHelp: supplementaryHelp,
      );
      Future<PromptResult<String>> run(
        PromptSource source,
        PromptMode mode, {
        OutputProfile? outputProfile,
        _Keys? keys,
        TerminalSession? session,
      }) => _browse(
        source,
        mode,
        input,
        outputProfile: outputProfile,
        keys: keys,
        session: session,
      );
      if (source is SuppliedAnswer) {
        return await input.prompt(source: source);
      }
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

  Future<PromptResult<String>> _browse(
    PromptSource source,
    PromptMode mode,
    PathInput input, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    final scripted = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
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
    final linear = mode == PromptMode.linear;
    final out = scripted.output;
    final width = _textInputWidth(effectiveProfile);
    void write(String text, TerminalColor foreground) => _writeWrappedColorText(
      out,
      DisplayText.from(text).value,
      width,
      foreground: foreground,
      background: colors.background,
      outputProfile: effectiveProfile,
    );

    var current = base ?? Directory.current.path;
    var showHidden = false;
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    try {
      while (true) {
        write(
          '$label. Current directory: $current. Existing ${target.name} required.',
          colors.foreground,
        );
        write(
          'Open N opens a directory; Choose N chooses an entry${target == PathTarget.directory ? '; Choose selects the current directory' : ''}. Path enters a literal path. Parent, Refresh, Hidden toggle are available.',
          colors.muted,
        );
        write(
          'Hidden entries: ${showHidden ? 'shown' : 'hidden'}. Links require explicit per-open approval. The base is not a sandbox.',
          colors.warning,
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
                await FileSystemEntity.type(entry.path, followLinks: false) ==
                    FileSystemEntityType.link ||
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
            write(
              '${i + 1}. ${path.basename(entries[i].path)} [${entries[i].type == FileSystemEntityType.file
                  ? 'file'
                  : entries[i].type == FileSystemEntityType.directory
                  ? 'directory'
                  : 'link'}]',
              colors.foreground,
            );
          }
        } on FileSystemException catch (error) {
          write(
            'Cannot list $current: ${error.message}. Context retained; use Parent, Path or Refresh.',
            colors.warning,
          );
        }
        final browseHelp = _browseHelp(
          component: _component,
          linear: linear,
          target: target,
          current: current,
          showHidden: showHidden,
          entries: entries.length,
        );
        final action = await _edit(
          inputKeys,
          '',
          out,
          linear: linear,
          sequential: linear,
          clearHelpCommand: true,
          helpText: browseHelp,
          linearHelpText: browseHelp,
          outputProfile: effectiveProfile,
          session: session,
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
                inputKeys,
                mode,
                effectiveProfile,
                input,
                current,
                session: session,
              );
              if (result != null) return result;
              continue;
            }
            write('An entry reference is required.', colors.warning);
            continue;
          }
          if (reference < 1 || reference > entries.length) {
            write('Invalid entry reference; listing retained.', colors.warning);
            continue;
          }
          final entry = entries[reference - 1];
          if (!entry.isCurrent) {
            write(
              'Entry reference $reference is stale; refreshing instead of targeting a replacement.',
              colors.warning,
            );
            continue;
          }
          if (match[1] == 'open') {
            final linked = entry.type == FileSystemEntityType.link;
            if (linked && match[3] == null) {
              write(
                'Cannot open linked directory ${entry.path} without explicit opt-in; use open $reference links.',
                colors.warning,
              );
              continue;
            }
            if (!linked && match[3] != null) {
              write('Link approval only applies to links.', colors.warning);
              continue;
            }
            if (await FileSystemEntity.type(entry.path) !=
                FileSystemEntityType.directory) {
              write(
                'Cannot open ${entry.path}: not an accessible directory.',
                colors.warning,
              );
              continue;
            }
            try {
              final resolved = await Directory(entry.path)
                  .resolveSymbolicLinks();
              var ancestor = await Directory(current).resolveSymbolicLinks();
              while (true) {
                if (ancestor == resolved) {
                  write(
                    'Cannot open ${entry.path}: linked-directory cycle to $resolved; current directory retained.',
                    colors.warning,
                  );
                  break;
                }
                final parent = path.dirname(ancestor);
                if (parent == ancestor) {
                  if (linked) {
                    write(
                      'Linked traversal approved for this open: ${entry.path}.',
                      colors.accent,
                    );
                  }
                  current = entry.path;
                  break;
                }
                ancestor = parent;
              }
            } on FileSystemException catch (error) {
              write(
                'Cannot resolve linked directory ${entry.path}: ${error.message}; current directory retained.',
                colors.warning,
              );
            }
            continue;
          }
          if ((target == PathTarget.file &&
                  entry.type != FileSystemEntityType.file) ||
              (target == PathTarget.directory &&
                  entry.type != FileSystemEntityType.directory)) {
            write(
              'Cannot choose ${entry.path}: target must be a ${target.name}.',
              colors.warning,
            );
            continue;
          }
          final result = await _review(
            scripted,
            inputKeys,
            mode,
            effectiveProfile,
            input,
            entry.path,
            session: session,
          );
          if (result != null) return result;
          continue;
        }
        if (command == 'path') {
          write('Enter literal path:', colors.foreground);
          final pathHelp = _literalPathHelp(
            component: _component,
            linear: linear,
            target: target,
            current: current,
          );
          final entry = await _edit(
            inputKeys,
            '',
            out,
            linear: linear,
            sequential: linear,
            clearHelpCommand: true,
            helpText: pathHelp,
            linearHelpText: pathHelp,
            outputProfile: effectiveProfile,
            session: session,
          );
          if (entry.action == 'cancel') return Cancelled();
          if (entry.action == 'interrupt') return Interrupted();
          if (entry.action != 'submit') return InputEnded();
          final candidate = input._candidate(entry.value, current);
          final error = await input._error(candidate);
          if (error != null) {
            write('Cannot choose $candidate: $error', colors.warning);
            continue;
          }
          final result = await _review(
            scripted,
            inputKeys,
            mode,
            effectiveProfile,
            input,
            candidate!,
            session: session,
          );
          if (result != null) return result;
          continue;
        }
        write('Unknown action; listing and context retained.', colors.warning);
      }
    } finally {
      if (keys == null) await inputKeys.close();
    }
  }

  Future<PromptResult<String>?> _review(
    ScriptedInput scripted,
    _Keys keys,
    PromptMode mode,
    OutputProfile effectiveProfile,
    PathInput input,
    String candidate, {
    TerminalSession? session,
  }) async {
    final linear = mode == PromptMode.linear;
    final error = await input._error(candidate);
    if (error != null) {
      _writeWrappedColorText(
        scripted.output,
        DisplayText.from('Cannot choose $candidate: $error').value,
        _textInputWidth(effectiveProfile),
        foreground: colors.warning,
        background: colors.background,
        outputProfile: effectiveProfile,
      );
      return null;
    }
    final reviewHelp = _reviewHelp(
      component: _component,
      linear: linear,
      candidate: candidate,
      target: target,
    );
    final reviewMessage =
        'Choose $candidate. Enter to accept, or type edit to return.';
    _writeWrappedColorText(
      scripted.output,
      DisplayText.from(reviewMessage).value,
      _textInputWidth(effectiveProfile),
      foreground: colors.accent,
      background: colors.background,
      outputProfile: effectiveProfile,
    );
    final review = await _edit(
      keys,
      '',
      scripted.output,
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
    if (review.value.isNotEmpty) return null;
    final finalError = await input._error(candidate);
    if (finalError == null) return Accepted(candidate);
    final wrappedError = StringBuffer();
    _writeWrappedText(
      wrappedError,
      DisplayText.from('Cannot choose $candidate: $finalError').value,
      _textInputWidth(effectiveProfile),
    );
    for (final line in wrappedError.toString().split('\n')) {
      if (line.isNotEmpty) {
        scripted.output.writeln(
          _colorText(line, colors.warning, colors.background, effectiveProfile),
        );
      }
    }
    return null;
  }
}

/// Component help for the browse stage, led by the current location and stage.
///
/// It names every browser action, keeps displayed entry references distinct
/// from filesystem identity, and protects the link-approval, no-sandbox and
/// later-operation caveats that compact guidance can only abbreviate.
String _browseHelp({
  required String component,
  required bool linear,
  required PathTarget target,
  required String current,
  required bool showHidden,
  required int entries,
}) {
  final wanted = switch (target) {
    PathTarget.file => 'one existing file',
    PathTarget.directory => 'one existing directory',
    PathTarget.any => 'one existing target',
  };
  final controls = linear
      ? r'Enter runs the typed action; exact /help and /cancel are commands, and /help is cleared instead of being run. Quote a literal leading backslash with another backslash, and double both leading backslashes of a UNC pair. Identified paste is literal; unframed paste cannot be distinguished from typing. Escape cancels; Ctrl+C interrupts.'
      : 'Enter runs the typed action. Ctrl+T opens this help; Escape dismisses help or cancels; Ctrl+C interrupts.';
  return 'Help: $component browses $current and returns $wanted. The listing shows $entries entries and hidden entries are ${showHidden ? 'shown' : 'hidden'}. Actions: open <n> enters a listed directory; choose <n> chooses a listed entry and shows it for review${target == PathTarget.directory ? '; choose without a number reviews the current directory' : ''}; path enters one literal native path; parent moves to the containing directory; refresh relists and replaces the displayed references; hidden toggles hidden entries. An entry number identifies the displayed listing rather than a filesystem identity, so an entry replaced after it was listed is reported as stale and the listing is refreshed instead of targeting the replacement. Links are never followed implicitly: open <n> links approves exactly that one open, a linked cycle or an unresolvable link keeps the current directory, and link approval has no effect on a non-link entry. The base is not a sandbox, so parent and path can leave it. Nothing is created, opened for reading or changed, and the selection is re-inspected at review, so later filesystem operations can still fail. $controls';
}

/// Component help for the literal-path stage of a browser.
String _literalPathHelp({
  required String component,
  required bool linear,
  required PathTarget target,
  required String current,
}) {
  final wanted = switch (target) {
    PathTarget.file => 'The target must be an existing file.',
    PathTarget.directory => 'The target must be an existing directory.',
    PathTarget.any => 'Any existing target type is accepted.',
  };
  final controls = linear
      ? r'Enter submits the typed path for review; an empty line submits an empty path and is rejected. Exact /help and /cancel are commands, and /help is cleared instead of becoming the path; enter \/help for that literal path, quote a literal leading backslash with another backslash, and double both leading backslashes of a UNC pair. Identified paste is literal. Escape cancels; Ctrl+C interrupts.'
      : 'Enter submits the typed path for review. Ctrl+T opens this help; Escape dismisses help or cancels; Ctrl+C interrupts.';
  return 'Help: $component literal path. The path is literal and relative to $current, with no shell expansion, no quote stripping, no link canonicalization and no working-directory change; .. segments are retained and a drive-relative Windows path such as C:name is rejected. $wanted A path with an unusable name, an uninspectable target, or a parent that is not a directory is rejected rather than assumed absent. Review shows the resolved candidate before it is returned, this browser is not a sandbox, and a returned path is a snapshot: later filesystem operations can still fail. $controls';
}

/// Component help for the browser review stage.
String _reviewHelp({
  required String component,
  required bool linear,
  required String candidate,
  required PathTarget target,
}) {
  final wanted = switch (target) {
    PathTarget.file => 'that file',
    PathTarget.directory => 'that directory',
    PathTarget.any => 'that target',
  };
  final controls = linear
      ? r'Enter accepts the reviewed candidate; type edit and press Enter to return to the listing without accepting. Exact /help and /cancel are commands, and /help is cleared instead of being accepted. Escape cancels; Ctrl+C interrupts.'
      : 'Enter accepts the reviewed candidate; type edit to return to the listing without accepting. Ctrl+T opens this help; Escape dismisses help or cancels; Ctrl+C interrupts.';
  return 'Help: $component review. The candidate ${DisplayText.from(candidate).value} was re-inspected at review and is returned only when it is still $wanted. The listing is retained, so typing edit returns to the same directory context. Nothing was created, opened for reading or changed, and the result is a snapshot rather than permission, so later filesystem operations can still fail. $controls';
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
