part of 'text_input.dart';

/// Collects free-form text with suggestions.
final class Autocomplete {
  Autocomplete(
    this.label, {
    required this.suggestions,
    this.initialValue = '',
    this.required = false,
    this.validate,
    this.maxLength,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp),
       _input = TextInput(
         label,
         initialValue: initialValue,
         required: required,
         validate: validate,
         maxLength: maxLength,
       );

  final String label;
  final String initialValue;
  final bool required;
  final int? maxLength;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final String? Function(String)? validate;
  final FutureOr<List<String>> Function(String) suggestions;
  final TextInput _input;
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
      if (session != null) {
        return await session._promptRunner(
          _run,
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
              () => _run(
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
                _run(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<String>> _run(
    PromptSource promptSource,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (promptSource is SuppliedAnswer) return _input._run(promptSource, mode);
    final source = promptSource as ScriptedInput;
    var effectiveProfile = _constrainToObservedGeometry(
      OutputProfile.resolve(
        invocation: outputProfile,
        source: source.outputProfile,
        supportsRich: source.supportsRich,
      ),
      source._observedGeometry,
    );
    if (source._hardColorDisabled) {
      effectiveProfile = effectiveProfile.copyWith(colorDepth: ColorDepth.none);
    }
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    if (mode == PromptMode.rich) {
      return _rich(source, effectiveProfile, keys: keys, session: session);
    }
    final out = source.output;
    String safe(String value) => DisplayText.from(value).value;
    out.writeln(
      instructions == InstructionDisplay.hidden
          ? '${safe(label)}. /help for help.'
          : '${safe(label)}. Enter a query; select a number, /submit, /edit, /help or /cancel.',
    );
    final inputKeys = keys ?? _Keys(source.input.transform(utf8.encoder));
    var pending = initialValue;
    var editing = true;
    var candidates = <String>[];
    var generation = 0;
    var closed = false;
    try {
      while (true) {
        var literal = false;
        final result = await _edit(
          inputKeys,
          editing ? pending : '',
          out,
          linear: true,
          sequential: true,
          clearHelpCommand: true,
          session: session,
          outputProfile: effectiveProfile,
          allowCommandPrefixes: true,
          maxLength: editing ? maxLength : null,
          extraCommands: editing ? const {} : const {'/submit', '/edit'},
          linearHelpText:
              '${editing ? 'Help: Autocomplete query. Enter requests suggestions; your text remains the pending answer. /cancel cancels.' : 'Help: Autocomplete results. A number copies a candidate into the pending answer; /submit validates and finishes; /edit changes the query.'} ${supplementaryHelp.map(safe).join(' ')}',
          onSubmit: (value) => literal = value,
        );
        if (result.action == 'cancel') return Cancelled();
        if (result.action == 'interrupt') return Interrupted();
        if (result.action != 'submit' && result.action != 'command') {
          return InputEnded();
        }
        if (editing) {
          if (maxLength != null &&
              result.value.characters.length > maxLength!) {
            out.writeln('Text exceeds maximum length; edit and submit again.');
            pending = result.value;
            continue;
          }
          pending = result.value;
          candidates = [];
          final request = ++generation;
          void apply(List<String> items) {
            if (closed || request != generation) return;
            candidates = items
                .where((item) => !item.runes.any((r) => r < 32 || r == 127))
                .toList();
            out.writeln('${candidates.length} suggestions.');
            for (var i = 0; i < candidates.length; i++) {
              out.writeln('${i + 1}. ${safe(candidates[i])}');
            }
          }

          try {
            final response = suggestions(pending);
            if (response is List<String>) {
              apply(response);
            } else {
              out.writeln('Loading suggestions.');
              Future<List<String>>.value(response).then(
                apply,
                onError: (Object error) {
                  if (!closed && request == generation) {
                    out.writeln('Suggestions unavailable.');
                  }
                },
              );
            }
          } catch (_) {
            out.writeln('Suggestions unavailable.');
          }
          out.writeln(
            'Pending answer: ${safe(pending)}. Choose a number or /submit, /edit, /help, /cancel.',
          );
          editing = false;
        } else if (result.action == 'command' && result.value == '/submit') {
          final error = _error(pending);
          if (error != null) {
            out.writeln(safe(error));
            continue;
          }
          return Accepted(pending);
        } else if (result.action == 'command' && result.value == '/edit') {
          generation++;
          candidates = [];
          editing = true;
        } else {
          final index = literal ? null : int.tryParse(result.value);
          if (index != null && index > 0 && index <= candidates.length) {
            final candidate = candidates[index - 1];
            if (maxLength != null && candidate.characters.length > maxLength!) {
              out.writeln('Candidate exceeds maximum length.');
              continue;
            }
            pending = candidate;
            out.writeln(
              'Accepted into pending answer: ${safe(pending)}. Use /submit to finish or /edit to change.',
            );
          } else {
            out.writeln(
              'Choose a listed number or /submit, /edit, /help, /cancel.',
            );
          }
        }
      }
    } finally {
      closed = true;
      generation++;
      try {
        session?._setPromptRepaint(null);
      } finally {
        if (keys == null) await inputKeys.close();
      }
    }
  }

  Future<PromptResult<String>> _rich(
    ScriptedInput source,
    OutputProfile effectiveProfile, {
    _Keys? keys,
    TerminalSession? session,
  }) async {
    final out = source.output;
    String safe(String value) => DisplayText.from(value).value;
    out.writeln(
      instructions == InstructionDisplay.hidden
          ? '${safe(label)}. Ctrl+T for help.'
          : '${safe(label)}. Type text; Up/Down inspect suggestions; Tab accepts the first or active candidate; Enter accepts an active candidate or submits text; Escape dismisses suggestions, then cancels.',
    );
    final inputKeys = keys ?? _Keys(source.input.transform(utf8.encoder));
    var value = initialValue;
    var query = '\u0000';
    var candidates = <String>[];
    var focus = -1;
    var generation = 0;
    var open = true;
    var loading = false;
    var closed = false;
    String? deferredNotice;
    var helpVisible = false;
    void notice(String text) {
      if (helpVisible) {
        deferredNotice = text;
      } else {
        out.writeln(text);
      }
    }

    void changed(String text) {
      if (text == query) return;
      query = text;
      focus = -1;
      open = true;
      candidates = [];
      loading = true;
      final request = ++generation;
      void apply(List<String> items) {
        if (closed || request != generation) return;
        loading = false;
        candidates = items
            .where((item) => !item.runes.any((r) => r < 32 || r == 127))
            .toList();
        notice('${candidates.length} suggestions; none active.');
      }

      try {
        final result = suggestions(text);
        if (result is List<String>) {
          apply(result);
        } else {
          out.writeln('Loading suggestions.');
          Future<List<String>>.value(result).then(
            apply,
            onError: (Object error) {
              if (!closed && request == generation) {
                loading = false;
                notice('Suggestions unavailable.');
              }
            },
          );
        }
      } catch (_) {
        loading = false;
        notice('Suggestions unavailable.');
      }
    }

    try {
      while (true) {
        final result = await _edit(
          inputKeys,
          value,
          out,
          session: session,
          outputProfile: effectiveProfile,
          transientHelp:
              effectiveProfile.alternateScreen == CapabilitySupport.supported,
          resizeObserver: source.resizeObserver,
          onChanged: changed,
          onHelpVisibilityChanged: (visible) => helpVisible = visible,
          onHelpDismissed: () {
            if (deferredNotice case final text?) out.writeln(text);
            deferredNotice = null;
          },
          maxLength: maxLength,
          helpText:
              'Help: Autocomplete. Tab accepts a candidate into editable text; Up/Down inspect candidates and Enter accepts the active candidate. Enter submits free text when no candidate is active. Escape dismisses suggestions or cancels; Ctrl+C interrupts. ${supplementaryHelp.map((text) => DisplayText.from(text).value).join(' ')}',
          intercept: (key, text) {
            if (key == '\x1b' && open && (loading || candidates.isNotEmpty)) {
              open = false;
              loading = false;
              focus = -1;
              generation++;
              out.writeln('Suggestions dismissed.');
              return 'handled';
            }
            if ((key == '\x1b[B' || key == '\x1b[A') &&
                open &&
                candidates.isNotEmpty) {
              if (key == '\x1b[B') {
                focus = (focus + 1).clamp(0, candidates.length - 1);
              } else {
                focus = focus < 0
                    ? candidates.length - 1
                    : (focus - 1).clamp(0, candidates.length - 1);
              }
              out.writeln(
                'Active candidate, not accepted: ${safe(candidates[focus])}.',
              );
              return 'handled';
            }
            if (open &&
                candidates.isNotEmpty &&
                (key == '\t' || ((key == '\r' || key == '\n') && focus >= 0))) {
              return 'accept';
            }
            return null;
          },
        );
        if (result.action == 'cancel') return Cancelled();
        if (result.action == 'interrupt') return Interrupted();
        if (result.action == 'eof') return InputEnded();
        if (result.action == 'submit') {
          final error = _error(result.value);
          if (error == null) return Accepted(result.value);
          out.writeln(safe(error));
          value = result.value;
          continue;
        }
        value = result.value;
        if (result.action == 'accept') {
          final candidate = candidates[focus < 0 ? 0 : focus];
          if (maxLength != null && candidate.characters.length > maxLength!) {
            out.writeln('Candidate exceeds maximum length.');
            continue;
          }
          value = candidate;
          query = value;
          focus = -1;
          open = false;
          generation++;
          out.writeln(
            'Accepted into editable text: ${safe(value)}. Enter submits.',
          );
        }
      }
    } finally {
      closed = true;
      generation++;
      try {
        session?._setPromptRepaint(null);
      } finally {
        if (keys == null) await inputKeys.close();
      }
    }
  }

  String? _error(String value) {
    if (required && value.isEmpty) {
      return 'Required: enter a non-empty value and submit again.';
    }
    return validate?.call(value);
  }
}
