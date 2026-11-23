part of 'text_input.dart';

/// Searchable single choice. References always identify source choices.
final class SearchSelect<T> {
  SearchSelect(
    this.label,
    List<Choice<T>> choices, {
    this.defaultValue,
    this.search,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    this.presentation,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp),
       choices = List.unmodifiable(choices),
       _kind = 'SearchSelect',
       _matches = null {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (choices.map((c) => c.value).toSet().length != choices.length) {
      throw ArgumentError('Choice identities must be unique.');
    }
    if (defaultValue != null && !choices.any((c) => c.value == defaultValue)) {
      throw ArgumentError('Default identity is not a choice.');
    }
  }
  SearchSelect._palette(
    this.label,
    List<Choice<T>> choices, {
    this.defaultValue,
    this.search,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    this.presentation,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp),
       choices = List.unmodifiable(choices),
       _kind = 'CommandPalette',
       _matches = null {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (choices.map((c) => c.value).toSet().length != choices.length) {
      throw ArgumentError('Choice identities must be unique.');
    }
    if (defaultValue != null && !choices.any((c) => c.value == defaultValue)) {
      throw ArgumentError('Default identity is not a choice.');
    }
  }
  SearchSelect._timezone(
    this.label,
    List<Choice<T>> choices, {
    this.defaultValue,
    required this._matches,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    this.presentation,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp),
       choices = List.unmodifiable(choices),
       search = null,
       _kind = 'TimezoneSelect' {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (defaultValue != null && !choices.any((c) => c.value == defaultValue)) {
      throw ArgumentError('Default identity is not a choice.');
    }
  }
  final bool Function(Choice<T>, String)? _matches;
  final String label;
  final String _kind;
  final List<Choice<T>> choices;
  final T? defaultValue;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;

  /// Theme-owned state vocabulary, or null for the legacy textual markers.
  final ChoicePresentationConfig? presentation;
  final List<String> supplementaryHelp;

  /// Optional search policy. Results must use identities from [choices]; their
  /// labels and availability may change. Results retain source order and stable
  /// source references. Pending and obsolete responses cannot be accepted.
  final FutureOr<List<Choice<T>>> Function(String query)? search;
  bool _active = false;

  Future<PromptResult<T>> prompt({
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
        return await session._promptRunner<T>(
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
          return await _terminal<T>(
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

  Future<PromptResult<T>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      if (search != null) {
        return Unavailable(
          'Supplied references cannot verify dynamic search availability.',
        );
      }
      final n = int.tryParse(source.value);
      if (n == null ||
          n < 1 ||
          n > choices.length ||
          choices[n - 1].disabledReason != null) {
        return Unavailable('Supply an enabled choice reference.');
      }
      return Accepted(choices[n - 1].value);
    }
    final input = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(input, outputProfile);
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
    final out = input.output;
    final transcript = input.transcript;
    String safe(String value) => DisplayText.from(value).value;
    final additionalHelp = supplementaryHelp.map(safe).join(' ');
    final inputKeys = keys ?? _Keys(input.input.transform(utf8.encoder));
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: _textInputWidth(effectiveProfile),
      background: colors.background,
      border: colors.border,
      rich: mode == PromptMode.rich,
    );
    void write(
      String text, {
      bool closes = false,
      StageEvent event = StageEvent.body,
    }) {
      if (!usesStructureFraming(structure)) {
        out.writeln(text);
        // An unframed structure has no spine-owned row, so the spine is told
        // how many rows the stage drew: a rich repaint rewinds over the whole
        // presentation, not only over the rows it wrote itself.
        spine.countWrappedRow(text);
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

    var query = '';
    var focus = defaultValue == null
        ? -1
        : choices.indexWhere((c) => c.value == defaultValue);
    var preferred = focus;
    var page = 0;
    const size = 10;
    var current = <int, Choice<T>>{};
    var loading = false;
    var failed = false;
    var invalidIdentities = false;
    var closed = false;
    var generation = 0;
    String? requestedQuery;
    var invalidFocus = false;
    var hadResultsFocus = false;
    var helpVisible = false;
    var lastResultsSignature = '';
    // While the editor reports a change it has already ended the editable row
    // with a newline, so the cursor sits one row below the frame the spine
    // counted; the first repaint in that window rewinds one extra row. The
    // boundary callback clears the credit once the editor row is repainted.
    var repaintBelowEditor = false;
    String domainHelp() => switch (_kind) {
      'CommandPalette' =>
        'A reference identifies a command; accepting it does not run it.',
      'TimezoneSelect' => 'Matching covers IANA identifiers, city names and aliases; the canonical identity is returned and no offset or current time is consulted.',
      _ => '',
    };
    List<int> visible() => search == null
        ? [
            for (var i = 0; i < choices.length; i++)
              if (_matches?.call(choices[i], query) ??
                  choices[i].label.toLowerCase().contains(query.toLowerCase()))
                i,
          ]
        : [
            for (var i = 0; i < choices.length; i++)
              if (current.containsKey(i)) i,
          ];
    Choice<T> item(int i) => search == null ? choices[i] : current[i]!;
    List<int> displayed() => mode == PromptMode.linear
        ? visible().skip(page * size).take(size).toList()
        : visible();

    // The instruction policy is shared by the introduction and by every results
    // presentation, so the compact hint under a repainted frame is the same
    // text a reader already saw above it.
    final introParts = _instructionIntroParts(
      instructions,
      hidden: (
        title: '${safe(label)}.',
        // Hidden instructions omit optional detail, never the primary action
        // or the route to detailed help.
        guidance: mode == PromptMode.linear
            ? 'Enter a query, then a result reference. /help for help.'
            : 'Type a query; Enter opens results. Ctrl+T help.',
      ),
      compact: (
        title: '${safe(label)}.',
        guidance: mode == PromptMode.linear
            ? 'Enter a query, then a result reference. /help for help.'
            : 'Type a query; Enter enters results; Enter accepts a focused result. Ctrl+T help.',
      ),
      expanded: (
        title: '${safe(label)}.',
        guidance: mode == PromptMode.linear
            ? 'Enter a query, then a result reference. /search edits query; /next, /previous, /list, /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal; unframed paste cannot be distinguished from typing.'
            : 'Edit query; Enter or Up/Down enters results without accepting. Tab moves through query, results and Cancel action. Enter accepts a focused enabled result; typing edits query. Ctrl+T help; Escape cancels; Ctrl+C interrupts.',
      ),
    );

    // The typed projection is built before any output, and only for a current,
    // open presentation: stale responses are rejected above it.
    QueryResultsPresentation project() {
      final matches = visible();
      final phase = loading
          ? QueryResultsPhase.loading
          : failed
          ? QueryResultsPhase.failure
          : matches.isEmpty
          ? QueryResultsPhase.empty
          : QueryResultsPhase.ready;
      final rows = <QueryResultRow>[];
      for (var position = 0; position < displayed().length; position++) {
        final index = displayed()[position];
        final choice = item(index);
        rows.add(
          QueryResultRow(
            label: DisplayText.from(choice.label),
            position: position + 1,
            reference: index + 1,
            focused: index == focus,
            isDefault: defaultValue != null && choice.value == defaultValue,
            unavailableReason: choice.disabledReason == null
                ? null
                : DisplayText.from(choice.disabledReason!),
          ),
        );
      }
      final pageCount = mode == PromptMode.linear
          ? (matches.length + size - 1) ~/ size
          : null;
      return QueryResultsPresentation(
        component: _kind,
        label: DisplayText.from(label),
        query: DisplayText.from(query),
        phase: phase,
        identityModel: QueryResultsIdentityModel.sourceStableChoice,
        totalResults: matches.length,
        rows: rows,
        notices: [
          if (phase == QueryResultsPhase.failure) ...[
            if (invalidIdentities) QueryResultsNotice.invalidIdentities,
            QueryResultsNotice.retryByEditing,
          ],
          if (invalidFocus) QueryResultsNotice.focusedResultRemoved,
        ],
        page: pageCount == null ? null : page + 1,
        pageCount: pageCount,
      );
    }

    void recordResults() {
      final projection = project();
      final signature = _presentationSignature(projection);
      if (signature == lastResultsSignature) return;
      lastResultsSignature = signature;
      transcript?._event(
        TextInputPresentationEventKind.results,
        results: projection,
      );
    }

    void show() {
      if (repaintBelowEditor) {
        repaintBelowEditor = false;
        spine.countRows(1);
      }
      spine.reset(out);
      final projection = project();
      // The query is answer data, so it stays in the body rows: a diagnostic
      // heading never spells retained input in capitals.
      spine.opening(
        out,
        title: '${projection.label.value} ${projection.component}:',
        body:
            '${projection.totalResults} results for "${projection.query.value}".',
        foreground: colors.foreground,
        bodyForeground: colors.foreground,
      );
      switch (projection.phase) {
        case QueryResultsPhase.loading:
          write('Searching; results cannot be accepted yet.');
        case QueryResultsPhase.failure:
          if (projection.notices.contains(
            QueryResultsNotice.invalidIdentities,
          )) {
            write('Search returned unknown or duplicate identities.');
          }
          write('Search unavailable; edit the query to retry.');
        case QueryResultsPhase.empty:
          write('No matching choices; edit the query.');
        case QueryResultsPhase.idle || QueryResultsPhase.ready:
          break;
      }
      if (projection.notices.contains(
        QueryResultsNotice.focusedResultRemoved,
      )) {
        write(
          'Previously focused choice is removed or unavailable; navigate to choose another.',
        );
      }
      if (projection.pageCount != null && projection.totalResults > 0) {
        write('Page ${projection.page} of ${projection.pageCount}.');
      }
      if (projection.rows.isNotEmpty) spine.breathingRow(out);
      for (final row in projection.rows) {
        _writeChoiceRow(
          out,
          _ChoiceRow(
            reference: row.reference ?? 0,
            label: row.label.value,
            focused: row.focused,
            isDefault: row.isDefault,
            disabledReason: row.unavailableReason?.value,
            presentation: presentation,
          ),
          width: _textInputWidth(effectiveProfile),
          foreground: row.focused ? colors.accent : colors.foreground,
          colors: colors,
          profile: effectiveProfile,
          spine: spine,
        );
      }
      if (spine.encloses || spine.heads) {
        // An enclosure ends every results presentation: the bottom rule closes
        // the frame and the stage's compact hint stays outside it. A heading
        // structure keeps the same hint under its body rows, so a query, a
        // focus move or an acceptance is never written into an open frame.
        spine.hint(out, introParts.guidance, foreground: colors.foreground);
      }
    }

    void request(String text) {
      if (_matches != null && hadResultsFocus && focus >= 0) {
        if (!visible().contains(focus) ||
            choices[focus].disabledReason != null) {
          if (!invalidFocus) {
            write(
              'Previously focused choice is removed or unavailable; navigate to choose another.',
            );
          }
          invalidFocus = true;
        } else {
          invalidFocus = false;
        }
      }
      if (search == null || requestedQuery == text) return;
      requestedQuery = text;
      final requestId = ++generation;
      current = {};
      loading = true;
      failed = false;
      invalidIdentities = false;
      recordResults();
      void apply(List<Choice<T>> results) {
        if (closed || requestId != generation) return;
        final next = <int, Choice<T>>{};
        for (final candidate in results) {
          final index = choices.indexWhere((c) => c.value == candidate.value);
          if (index < 0 || next.containsKey(index)) {
            loading = false;
            failed = true;
            invalidIdentities = true;
            recordResults();
            if (!helpVisible) show();
            return;
          }
          next[index] = candidate;
        }
        current = next;
        loading = false;
        page = 0;
        if (hadResultsFocus &&
            focus >= 0 &&
            (!current.containsKey(focus) ||
                current[focus]!.disabledReason != null)) {
          invalidFocus = true;
        } else if (current.containsKey(focus)) {
          invalidFocus = false;
        }
        if (hadResultsFocus && focus < 0 && current.isNotEmpty) {
          final items = visible();
          final enabled = items.indexWhere(
            (i) => item(i).disabledReason == null,
          );
          focus = enabled < 0 ? items.first : items[enabled];
        }
        recordResults();
        if (!helpVisible) show();
      }

      void fail(Object error) {
        if (closed || requestId != generation) return;
        loading = false;
        failed = true;
        recordResults();
        if (!helpVisible) show();
      }

      // A projection or a write that fails in a detached continuation cannot
      // return a value to the awaiting prompt, so the failure ends the prompt
      // with its original error instead of being swallowed or retried against
      // a sink the session already lost.
      void guarded(void Function() step) {
        try {
          step();
        } catch (error, stackTrace) {
          inputKeys.fail(error, stackTrace);
        }
      }

      try {
        final response = search!(text);
        if (response is List<Choice<T>>) {
          apply(response);
        } else {
          Future<List<Choice<T>>>.value(response).then(
            (results) => guarded(() => apply(results)),
            onError: (Object error) => guarded(() => fail(error)),
          );
          write('Searching.');
        }
      } catch (error) {
        fail(error);
      }
    }

    void enterResults() {
      final items = visible();
      if (!loading && !invalidFocus && items.contains(preferred)) {
        focus = preferred;
      } else if (!loading &&
          !invalidFocus &&
          items.isNotEmpty &&
          !items.contains(focus)) {
        focus = items.indexWhere((i) => item(i).disabledReason == null);
        focus = focus < 0 ? (items.isEmpty ? -1 : items.first) : items[focus];
        if (preferred < 0) preferred = focus;
      }
      hadResultsFocus = true;
      write('Results focused.');
      transcript?._event(TextInputPresentationEventKind.resultsFocused);
      recordResults();
      show();
    }

    PromptResult<T>? accept(int index, {bool explicitReference = false}) {
      if (loading ||
          (!explicitReference && invalidFocus) ||
          !visible().contains(index)) {
        write('Choose a current result reference.');
        transcript?._event(
          TextInputPresentationEventKind.rejected,
          reference: index + 1,
        );
        return null;
      }
      final c = item(index);
      if (c.disabledReason != null) {
        write('Unavailable: ${safe(c.disabledReason!)}.');
        transcript?._event(
          TextInputPresentationEventKind.rejected,
          reference: index + 1,
          text: c.disabledReason,
        );
        return null;
      }
      write('Accepted: ${safe(c.label)}.');
      transcript?._event(
        TextInputPresentationEventKind.candidateAccepted,
        reference: index + 1,
        text: c.label,
      );
      return Accepted(c.value);
    }

    String stageHelp() {
      final projection = project();
      return switch (projection.phase) {
        QueryResultsPhase.loading => 'Searching; no result can be accepted until the current request completes.',
        QueryResultsPhase.failure =>
          'Search unavailable; editing the query retries it.',
        QueryResultsPhase.empty => 'No result matches the current query.',
        QueryResultsPhase.ready || QueryResultsPhase.idle =>
          '${projection.totalResults} current results${projection.pageCount == null ? '' : ', page ${projection.page} of ${projection.pageCount}'}.',
      };
    }

    String focusHelp() {
      final rows = project().rows;
      final focused = rows.where((row) => row.focused).toList();
      final defaults = rows.where((row) => row.isDefault).toList();
      final unavailable = rows.where((row) => !row.isAvailable).length;
      return [
        if (focused.isNotEmpty)
          'Focused: ${focused.first.label.value}${focused.first.unavailableReason == null ? '' : ' (unavailable: ${focused.first.unavailableReason!.value})'}.',
        if (defaults.isNotEmpty && focused.isEmpty)
          'Default: ${defaults.first.label.value}${defaults.first.unavailableReason == null ? '' : ' (unavailable: ${defaults.first.unavailableReason!.value})'}.',
        if (unavailable > 0)
          '$unavailable displayed results are unavailable; accepting one explains its reason.',
      ].join(' ');
    }

    session?._setPromptGeometry(effectiveProfile.geometry);
    session?._setPromptRepaint(show);
    _writeStructureIntro(
      spine,
      out,
      parts: introParts,
      foreground: colors.foreground,
      rawWhenUnframed: true,
    );
    try {
      if (mode == PromptMode.linear) {
        var editing = true;
        while (true) {
          var literal = false;
          final r = await _edit(
            inputKeys,
            editing ? query : '',
            out,
            linear: true,
            sequential: true,
            clearHelpCommand: true,
            transcript: transcript,
            structure: structure,
            extraCommands: editing
                ? const {}
                : const {'/search', '/next', '/previous', '/list'},
            onSubmit: (v) => literal = v,
            linearHelpText: null,
            liveLinearHelpText: () => editing
                ? _joinHelp([
                    'Help: $_kind query. Type to query; Enter opens matching results without accepting a choice.',
                    if (loading) 'A previous search is still pending; no result can be accepted yet.',
                    domainHelp(),
                    additionalHelp,
                  ])
                : _joinHelp([
                    'Help: $_kind results. Enter a source-stable reference to accept an enabled current result; the same reference identifies the choice across queries.',
                    stageHelp(),
                    focusHelp(),
                    '/search edits the query, /next and /previous change pages and /list reviews results.',
                    domainHelp(),
                    additionalHelp,
                  ]),
            session: session,
            outputProfile: effectiveProfile,
            onChanged: editing
                ? (v) {
                    query = v;
                    request(v);
                  }
                : null,
          );
          if (r.action == 'cancel') return Cancelled();
          if (r.action == 'interrupt') return Interrupted();
          if (r.action == 'eof') return InputEnded();
          if (editing) {
            query = r.value;
            request(query);
            page = 0;
            editing = false;
            enterResults();
            continue;
          }
          if (r.action == 'command') {
            switch (r.value) {
              case '/search':
                editing = true;
              case '/next':
                if ((page + 1) * size < visible().length) page++;
                recordResults();
                show();
              case '/previous':
                if (page > 0) page--;
                recordResults();
                show();
              case '/list':
                show();
            }
            continue;
          }
          final n = literal ? null : int.tryParse(r.value);
          final result = n == null || n < 1 || n > choices.length
              ? null
              : accept(n - 1, explicitReference: true);
          if (result != null) return result;
          if (n == null || n < 1 || n > choices.length) {
            write('Enter a current result reference.');
            transcript?._event(TextInputPresentationEventKind.rejected);
          }
        }
      }
      var editing = true;
      var actionFocus = false;
      var help = false;
      while (true) {
        if (editing) {
          final r = await _edit(
            inputKeys,
            query,
            out,
            session: session,
            outputProfile: effectiveProfile,
            structure: structure,
            resizeObserver: input.resizeObserver,
            transcript: transcript,
            transientHelp:
                effectiveProfile.alternateScreen == CapabilitySupport.supported,
            liveHelpText: () => _joinHelp([
              'Help: $_kind query. Type to query; Enter opens results without accepting.',
              'Tab or Up/Down also enters results. Escape dismisses help, then cancels; Ctrl+C interrupts.',
              if (loading) 'A previous search is still pending; no result can be accepted yet.',
              domainHelp(),
              additionalHelp,
            ]),
            onHelpDismissed: show,
            onHelpVisibilityChanged: (visible) => helpVisible = visible,
            onChanged: (v) {
              query = v;
              request(v);
              show();
            },
            onEditableRowBoundary: (below) => repaintBelowEditor = below,
            intercept: (key, text) {
              if (key == '\t' || key == '\x1b[A' || key == '\x1b[B') {
                return 'results';
              }
              return null;
            },
          );
          if (r.action == 'cancel') return Cancelled();
          if (r.action == 'interrupt') return Interrupted();
          if (r.action == 'eof') return InputEnded();
          query = r.value;
          editing = false;
          session?._setPromptRepaint(show);
          enterResults();
          continue;
        }
        final key = await inputKeys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          helpVisible = false;
          if (session != null) {
            session._dismissModalHelp(
              showTranscriptDismissal: true,
              repaintPrompt: show,
            );
          } else {
            write('Help dismissed.');
            show();
          }
          continue;
        }
        if (key == '\x14') {
          help = true;
          helpVisible = true;
          session?._openModalHelp(useAlternateScreen: false);
          transcript?._event(TextInputPresentationEventKind.help);
          write(
            _joinHelp([
              'Help: $_kind results.',
              'Tab traverses query, results and Cancel; arrows navigate results; Enter accepts a focused enabled result or Cancel; typing edits query; Escape dismisses help, then cancels; Ctrl+C interrupts.',
              stageHelp(),
              focusHelp(),
              domainHelp(),
              additionalHelp,
            ]),
          );
          continue;
        }
        if (help) continue;
        if (key == '\t') {
          if (actionFocus) {
            actionFocus = false;
            editing = true;
            write('Query focused.');
          } else {
            actionFocus = true;
            write('Cancel action focused; Enter cancels.');
          }
          continue;
        }
        if (actionFocus && (key == '\r' || key == '\n')) return Cancelled();
        if (actionFocus && (key == '\x1b[A' || key == '\x1b[B')) continue;
        final items = visible();
        if (key == '\x1b[A' || key == '\x1b[B') {
          final index = items.indexOf(focus);
          if (items.isNotEmpty) {
            invalidFocus = false;
            focus =
                items[(index + (key == '\x1b[A' ? -1 : 1)).clamp(
                  0,
                  items.length - 1,
                )];
            preferred = focus;
          }
          recordResults();
          show();
        } else if (key == '\r' || key == '\n') {
          final result = accept(focus);
          if (result != null) return result;
        } else if (key.startsWith('\x1b[200~')) {
          final data = key.substring(6, key.length - 6);
          if (data.runes.any((r) => r < 32 || r == 127)) {
            write('Paste rejected: single-line printable text only.');
            transcript?._event(TextInputPresentationEventKind.rejected);
          } else {
            query += data;
            actionFocus = false;
            editing = true;
          }
        } else if (!key.startsWith('\x1b') && key.codeUnitAt(0) >= 32) {
          query += key;
          actionFocus = false;
          editing = true;
        }
      }
    } finally {
      closed = true;
      generation++;
      try {
        session?._abortModalHelp();
        session?._setPromptRepaint(null);
      } finally {
        if (keys == null) await inputKeys.close();
      }
    }
  }
}
