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
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp),
       _input = TextInput(
         label,
         initialValue: initialValue,
         required: required,
         validate: validate,
         maxLength: maxLength,
         colors: colors,
         structure: structure,
         instructions: instructions,
         supplementaryHelp: supplementaryHelp,
       );

  final String label;
  final String initialValue;
  final bool required;
  final int? maxLength;
  final ColorTheme colors;
  final PromptStructure structure;
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
            return await SharedTerminalLease.run(terminal, () async {
              return _run(
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
              );
            });
          }
          return await _terminal<String>(
            selected,
            output ?? stdout,
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
    final effectiveProfile = _effectiveOutputProfile(source, outputProfile);
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
    final transcript = source.transcript;
    String safe(String value) => DisplayText.from(value).value;
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: _textInputWidth(effectiveProfile),
      background: colors.background,
      border: colors.border,
    );
    // An unframed component keeps its unwrapped event lines; a declared
    // structure frames and wraps them so rail/branch continuity or the
    // enclosure holds.
    void write(
      String text, {
      bool closes = false,
      StageEvent event = StageEvent.body,
    }) {
      if (!usesStructureFraming(structure)) {
        out.writeln(text);
        return;
      }
      spine.write(
        out,
        text,
        foreground: colors.foreground,
        closes: closes,
        event: event,
      );
    }

    _writeStructureIntro(
      spine,
      out,
      parts: _instructionIntroParts(
        instructions,
        hidden: (title: '${safe(label)}.', guidance: '/help for help.'),
        compact: (
          title: '${safe(label)}.',
          guidance: 'Enter a query; then a candidate number or /submit. /help for help.',
        ),
        expanded: (
          title: '${safe(label)}.',
          guidance: 'Enter a query; select a number, /submit, /edit, /help or /cancel.',
        ),
      ),
      foreground: colors.foreground,
      rawWhenUnframed: true,
    );
    final inputKeys = keys ?? _Keys(source.input.transform(utf8.encoder));
    var pending = initialValue;
    var editing = true;
    var candidates = <String>[];
    var generation = 0;
    var loading = false;
    var failed = false;
    var closed = false;
    var lastResultsSignature = '';
    QueryResultsPresentation projection({int? focus}) => _candidateProjection(
      label: label,
      query: pending,
      candidates: candidates,
      loading: loading,
      failed: failed,
      focus: focus,
    );
    void recordResults({int? focus}) {
      final current = projection(focus: focus);
      final signature = _presentationSignature(current);
      if (signature == lastResultsSignature) return;
      lastResultsSignature = signature;
      transcript?._event(
        TextInputPresentationEventKind.results,
        results: current,
      );
    }

    String stageHelp() {
      if (loading) {
        return 'Suggestions are still pending; none can be accepted.';
      }
      if (failed) {
        return 'Suggestions are unavailable; editing the query retries them.';
      }
      if (candidates.isEmpty) return 'No candidate matches the pending answer.';
      return '${candidates.length} candidates for the pending answer.';
    }

    String candidateHelp() => candidates.isEmpty
        ? 'Candidates are response-local suggestions; a number only copies the current response into the pending answer.'
        : 'Candidates are response-local suggestions; a number copies one from the current response into the pending answer: ${[for (var i = 0; i < candidates.length; i++) '${i + 1} ${safe(candidates[i])}'].join(', ')}.';
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
          transcript: transcript,
          session: session,
          outputProfile: effectiveProfile,
          structure: structure,
          allowCommandPrefixes: true,
          maxLength: editing ? maxLength : null,
          extraCommands: editing ? const {} : const {'/submit', '/edit'},
          linearHelpText: null,
          liveLinearHelpText: () => _joinHelp([
            editing
                ? 'Help: Autocomplete query. Enter requests suggestions; your text remains the pending answer. /cancel cancels.'
                : 'Help: Autocomplete results. A number copies a candidate into the pending answer; /submit validates and finishes; /edit changes the query.',
            stageHelp(),
            if (!editing) candidateHelp(),
            if (maxLength != null)
              'The answer is limited to $maxLength graphemes.',
            supplementaryHelp.map(safe).join(' '),
          ]),
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
            write('Text exceeds maximum length; edit and submit again.');
            pending = result.value;
            continue;
          }
          pending = result.value;
          candidates = [];
          failed = false;
          loading = true;
          final request = ++generation;
          void apply(List<String> items) {
            if (closed || request != generation) return;
            loading = false;
            failed = false;
            candidates = items
                .where((item) => !item.runes.any((r) => r < 32 || r == 127))
                .toList();
            write('${candidates.length} suggestions.');
            for (var i = 0; i < candidates.length; i++) {
              write('${i + 1}. ${safe(candidates[i])}');
            }
            recordResults();
          }

          void fail(Object error) {
            if (closed || request != generation) return;
            loading = false;
            failed = true;
            write('Suggestions unavailable.');
            recordResults();
          }

          void guarded(void Function() step) {
            try {
              step();
            } catch (error, stackTrace) {
              inputKeys.fail(error, stackTrace);
            }
          }

          try {
            final response = suggestions(pending);
            if (response is List<String>) {
              apply(response);
            } else {
              write('Loading suggestions.');
              Future<List<String>>.value(response).then(
                (items) => guarded(() => apply(items)),
                onError: (Object error) => guarded(() => fail(error)),
              );
            }
          } catch (error) {
            fail(error);
          }
          recordResults();
          write(
            'Pending answer: ${safe(pending)}. Choose a number or /submit, /edit, /help, /cancel.',
          );
          editing = false;
          transcript?._event(TextInputPresentationEventKind.resultsFocused);
        } else if (result.action == 'command' && result.value == '/submit') {
          final error = _error(pending);
          if (error != null) {
            write(safe(error));
            continue;
          }
          return Accepted(pending);
        } else if (result.action == 'command' && result.value == '/edit') {
          generation++;
          candidates = [];
          loading = false;
          failed = false;
          lastResultsSignature = '';
          editing = true;
        } else {
          final index = literal ? null : int.tryParse(result.value);
          if (index != null && index > 0 && index <= candidates.length) {
            final candidate = candidates[index - 1];
            if (maxLength != null && candidate.characters.length > maxLength!) {
              write('Candidate exceeds maximum length.');
              transcript?._event(TextInputPresentationEventKind.rejected);
              continue;
            }
            pending = candidate;
            write(
              'Accepted into pending answer: ${safe(pending)}. Use /submit to finish or /edit to change.',
            );
            // Candidates are response-local: the ordinal identifies a position
            // in this response, never a source-stable reference, so it is not
            // recorded in the reference slot.
            transcript?._event(
              TextInputPresentationEventKind.candidateAccepted,
              text: candidate,
            );
          } else {
            write('Choose a listed number or /submit, /edit, /help, /cancel.');
            transcript?._event(TextInputPresentationEventKind.rejected);
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
    final transcript = source.transcript;
    String safe(String value) => DisplayText.from(value).value;
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: _textInputWidth(effectiveProfile),
      background: colors.background,
      border: colors.border,
    );
    // An unframed component keeps its unwrapped event lines; a declared
    // structure frames and wraps them so rail/branch continuity or the
    // enclosure holds.
    void write(
      String text, {
      bool closes = false,
      StageEvent event = StageEvent.body,
    }) {
      if (!usesStructureFraming(structure)) {
        out.writeln(text);
        return;
      }
      spine.write(
        out,
        text,
        foreground: colors.foreground,
        closes: closes,
        event: event,
      );
    }

    _writeStructureIntro(
      spine,
      out,
      parts: _instructionIntroParts(
        instructions,
        hidden: (title: '${safe(label)}.', guidance: 'Ctrl+T for help.'),
        compact: (
          title: '${safe(label)}.',
          guidance: 'Type text; Tab accepts a suggestion; Enter submits the text. Ctrl+T help.',
        ),
        expanded: (
          title: '${safe(label)}.',
          guidance: 'Type text; Up/Down inspect suggestions; Tab accepts the first or active candidate; Enter accepts an active candidate or submits text; Escape dismisses suggestions, then cancels.',
        ),
      ),
      foreground: colors.foreground,
      rawWhenUnframed: true,
    );
    final inputKeys = keys ?? _Keys(source.input.transform(utf8.encoder));
    var value = initialValue;
    var query = '\u0000';
    var candidates = <String>[];
    var focus = -1;
    var generation = 0;
    var open = true;
    var loading = false;
    var failed = false;
    var closed = false;
    var lastResultsSignature = '';
    String? deferredNotice;
    var helpVisible = false;
    void notice(String text) {
      if (helpVisible) {
        deferredNotice = text;
      } else {
        write(text);
      }
    }

    QueryResultsPresentation projection({
      QueryResultsNotice? notice,
      bool idle = false,
    }) => _candidateProjection(
      label: label,
      query: query == '\u0000' ? value : query,
      candidates: candidates,
      loading: loading,
      failed: failed,
      focus: focus,
      idle: idle,
      notices: [?notice],
    );
    void recordResults({QueryResultsNotice? notice, bool idle = false}) {
      final current = projection(notice: notice, idle: idle);
      final signature = _presentationSignature(current);
      if (signature == lastResultsSignature) return;
      lastResultsSignature = signature;
      transcript?._event(
        TextInputPresentationEventKind.results,
        results: current,
      );
    }

    String stageHelp() {
      if (loading) {
        return 'Suggestions are still pending; none can be accepted.';
      }
      if (failed) {
        return 'Suggestions are unavailable; editing the query retries them.';
      }
      if (candidates.isEmpty) return 'No candidate matches the current text.';
      return '${candidates.length} candidates; ${focus < 0 ? 'none active' : 'active: ${safe(candidates[focus])}'}.';
    }

    void changed(String text) {
      if (text == query) return;
      query = text;
      focus = -1;
      open = true;
      candidates = [];
      loading = true;
      failed = false;
      recordResults();
      final request = ++generation;
      void apply(List<String> items) {
        if (closed || request != generation) return;
        loading = false;
        failed = false;
        candidates = items
            .where((item) => !item.runes.any((r) => r < 32 || r == 127))
            .toList();
        recordResults();
        notice('${candidates.length} suggestions; none active.');
      }

      void fail(Object error) {
        if (closed || request != generation) return;
        loading = false;
        failed = true;
        recordResults();
        notice('Suggestions unavailable.');
      }

      void guarded(void Function() step) {
        try {
          step();
        } catch (error, stackTrace) {
          inputKeys.fail(error, stackTrace);
        }
      }

      try {
        final result = suggestions(text);
        if (result is List<String>) {
          apply(result);
        } else {
          write('Loading suggestions.');
          Future<List<String>>.value(result).then(
            (items) => guarded(() => apply(items)),
            onError: (Object error) => guarded(() => fail(error)),
          );
        }
      } catch (error) {
        fail(error);
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
          structure: structure,
          transcript: transcript,
          transientHelp:
              effectiveProfile.alternateScreen == CapabilitySupport.supported,
          resizeObserver: source.resizeObserver,
          onChanged: changed,
          onHelpVisibilityChanged: (visible) => helpVisible = visible,
          onHelpDismissed: () {
            if (deferredNotice case final text?) write(text);
            deferredNotice = null;
          },
          maxLength: maxLength,
          liveHelpText: () => _joinHelp([
            'Help: Autocomplete. Tab accepts a candidate into editable text; Up/Down inspect candidates and Enter accepts the active candidate.',
            'Enter submits free text when no candidate is active. Escape dismisses suggestions or cancels; Ctrl+C interrupts.',
            stageHelp(),
            'Candidates are response-local: a replaced response cannot be accepted.',
            if (maxLength != null)
              'The answer is limited to $maxLength graphemes.',
            supplementaryHelp
                .map((text) => DisplayText.from(text).value)
                .join(' '),
          ]),
          intercept: (key, text) {
            if (key == '\x1b' && open && (loading || candidates.isNotEmpty)) {
              open = false;
              loading = false;
              focus = -1;
              generation++;
              candidates = [];
              recordResults(notice: QueryResultsNotice.dismissed, idle: true);
              write('Suggestions dismissed.');
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
              recordResults();
              write(
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
          write(safe(error));
          value = result.value;
          continue;
        }
        value = result.value;
        if (result.action == 'accept') {
          final candidate = candidates[focus < 0 ? 0 : focus];
          if (maxLength != null && candidate.characters.length > maxLength!) {
            write('Candidate exceeds maximum length.');
            transcript?._event(TextInputPresentationEventKind.rejected);
            continue;
          }
          value = candidate;
          query = value;
          focus = -1;
          open = false;
          generation++;
          candidates = [];
          write('Accepted into editable text: ${safe(value)}. Enter submits.');
          transcript?._event(
            TextInputPresentationEventKind.candidateAccepted,
            text: candidate,
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

/// The typed projection of one Autocomplete response.
///
/// Candidates are response-local: [QueryResultRow.reference] stays null so an
/// accepted position can never be mistaken for a source-stable identity from a
/// later response.
QueryResultsPresentation _candidateProjection({
  required String label,
  required String query,
  required List<String> candidates,
  required bool loading,
  required bool failed,
  int? focus,
  bool idle = false,
  Iterable<QueryResultsNotice> notices = const [],
}) => QueryResultsPresentation(
  component: 'Autocomplete',
  label: DisplayText.from(label),
  query: DisplayText.from(query),
  phase: idle
      ? QueryResultsPhase.idle
      : loading
      ? QueryResultsPhase.loading
      : failed
      ? QueryResultsPhase.failure
      : candidates.isEmpty
      ? QueryResultsPhase.empty
      : QueryResultsPhase.ready,
  identityModel: QueryResultsIdentityModel.responseLocalCandidate,
  totalResults: candidates.length,
  rows: [
    for (var i = 0; i < candidates.length; i++)
      QueryResultRow(
        label: DisplayText.from(candidates[i]),
        position: i + 1,
        focused: i == focus,
      ),
  ],
  notices: [if (failed) QueryResultsNotice.retryByEditing, ...notices],
);
