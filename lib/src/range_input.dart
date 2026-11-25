part of 'text_input.dart';

/// Exact decimal slider input. Decimal values are represented as strings.
final class Slider {
  Slider(
    this.label, {
    required this.minimum,
    required this.maximum,
    required this.step,
    this.initialValue,
    this.precision,
    this.units,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty ||
        label.runes.any((c) => c < 32 || c == 127) ||
        (units != null && units!.runes.any((c) => c < 32 || c == 127))) {
      throw ArgumentError('Invalid label or units.');
    }
    final min = _decimal(minimum);
    final max = _decimal(maximum);
    final increment = _decimal(step);
    if (min == null ||
        max == null ||
        increment == null ||
        _compare(min, max) > 0 ||
        increment.$1 <= BigInt.zero ||
        (precision != null &&
            (precision! < 0 ||
                min.$2 > precision! ||
                max.$2 > precision! ||
                increment.$2 > precision!))) {
      throw ArgumentError('Invalid slider bounds or step.');
    }
    if (initialValue != null && _validate(initialValue!) != null) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }

  final String label;
  final String minimum;
  final String maximum;
  final String step;
  final String? initialValue;
  final int? precision;
  final String? units;
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;

  String get _unitsCue => units == null ? '' : ', units $units';

  String get _precisionCue => precision == null
      ? ''
      : ', maximum $precision decimal place${precision == 1 ? '' : 's'}';

  /// The active-format cue: bounds, step, units and precision.
  String get _cue =>
      'minimum $minimum, maximum $maximum, step $step$_unitsCue$_precisionCue';

  String get _description => '$label ($_cue)';

  /// The accepted format, kept available from every help stage.
  String get _formatCue =>
      'Accepted format: between $minimum and $maximum on the $step grid$_unitsCue$_precisionCue; entries are never rounded or clipped.';

  /// Component help for the requesting interaction stage.
  ///
  /// The opening sentence names the stage so adjustment, editing and submission
  /// do not share one undifferentiated paragraph; the bounds, step and units
  /// stay in the same block.
  String _help({required bool linear, int focus = 0}) {
    const dismissal = 'Escape cancels and Ctrl+C interrupts.';
    if (linear) {
      return 'Help: Entering the value. $_formatCue A value is required, so an empty line is refused; invalid entries keep the draft for correction. /cancel cancels. Exact /help and /cancel are commands; quote a command with a backslash.';
    }
    return switch (focus) {
      1 =>
        'Help: Editing the value. Type or correct exact decimal text in the editor; the draft is never rounded. Submit accepts only a value on the $step grid. $_formatCue $dismissal',
      2 =>
        'Help: Submit. Enter accepts the displayed value only when it is on the $step grid and inside the bounds; otherwise the error keeps the draft. $_formatCue $dismissal',
      _ =>
        'Help: Adjusting the value. Left/Right or Up/Down move the draft by $step inside the same bounds; a candidate outside them or off the grid is refused. Tab reaches Edit and Submit. $_formatCue $dismissal',
    };
  }

  String? _validate(String value) {
    final number = _decimal(value);
    final min = _decimal(minimum)!;
    final max = _decimal(maximum)!;
    final increment = _decimal(step)!;
    if (number == null ||
        (precision != null && number.$2 > precision!) ||
        _compare(number, min) < 0 ||
        _compare(number, max) > 0) {
      return 'Enter a value between $minimum and $maximum on the $step grid.';
    }
    final scale = [
      number.$2,
      min.$2,
      increment.$2,
    ].reduce((a, b) => a > b ? a : b);
    final n = number.$1 * BigInt.from(10).pow(scale - number.$2);
    final m = min.$1 * BigInt.from(10).pow(scale - min.$2);
    final s = increment.$1 * BigInt.from(10).pow(scale - increment.$2);
    return (n - m) % s == BigInt.zero
        ? null
        : 'Enter a value between $minimum and $maximum on the $step grid.';
  }

  bool _active = false;

  static const _focusNames = ['Slider', 'Edit', 'Submit'];

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
    if (session != null) {
      return session._promptRunner<String>(
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
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
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
            (nativeSource, nativeMode, _) =>
                _run(nativeSource, nativeMode, outputProfile: outputProfile),
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
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final value = source.value;
      if (value.isEmpty) {
        return Unavailable(
          'Supplied answer does not satisfy text constraints.',
        );
      }
      final error = _validate(value);
      return error == null ? Accepted(value) : Unavailable(error);
    }
    final scripted = source as ScriptedInput;
    var effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
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
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    var value = initialValue ?? '';
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: _textInputWidth(effectiveProfile),
      background: colors.background,
      border: colors.border,
      rich: mode == PromptMode.rich,
      session: session,
    );
    // Guidance follows the current output geometry, so a resize repaint wraps
    // to the observed width instead of the invocation width.
    void emit(
      String text, {
      bool closes = false,
      StageEvent event = StageEvent.body,
    }) {
      spine.width = _textInputWidth(effectiveProfile);
      spine.write(
        out,
        text,
        foreground: colors.foreground,
        closes: closes,
        event: event,
      );
    }

    void hint(String text) {
      spine.width = _textInputWidth(effectiveProfile);
      spine.hint(out, text, foreground: colors.foreground);
    }

    // The stage heading is the slider's own description; the current value is
    // body content, so a diagnostic heading never spells a value in capitals.
    void heading(
      String title,
      String body, {
      StageEvent event = StageEvent.body,
    }) {
      spine.width = _textInputWidth(effectiveProfile);
      spine.opening(
        out,
        title: title,
        body: body,
        foreground: colors.foreground,
        bodyForeground: colors.foreground,
        event: event,
      );
    }

    // A refusal or a validation notice is a typed warning, so a grammar that
    // spells typed labels shows it as one; ordinary guidance stays a body row.
    void notice(String text, {StageEvent event = StageEvent.body}) =>
        emit(text, event: event);
    heading(
      '$_description.',
      'Current value: ${value.isEmpty ? 'not set' : value}.',
      event: StageEvent.state,
    );
    hint(
      mode == PromptMode.linear
          ? 'Enter an exact value, then submit. /help explains the bounds; /cancel cancels.'
          : 'Tab moves through Slider, Edit and Submit; arrows adjust; Enter activates Edit or Submit; F1 opens help; Escape cancels; Ctrl+C interrupts.',
    );
    try {
      if (mode == PromptMode.linear) {
        while (true) {
          final edit = await _edit(
            inputKeys,
            value,
            out,
            linear: true,
            sequential: !effectiveProfile.supportsRichInteraction,
            clearHelpCommand: true,
            linearHelpText: _help(linear: true),
            outputProfile: effectiveProfile,
            structure: structure,
            session: session,
          );
          if (edit.action == 'cancel') return Cancelled();
          if (edit.action == 'interrupt') return Interrupted();
          if (edit.action != 'submit') return InputEnded();
          value = edit.value;
          if (value.isEmpty) {
            notice(
              'Required: enter a non-empty value and submit again.',
              event: StageEvent.warning,
            );
            continue;
          }
          final error = _validate(value);
          if (error != null) {
            notice(error, event: StageEvent.warning);
            continue;
          }
          return Accepted(value);
        }
      }
      var focus = 0;
      var help = false;
      void show() {
        spine.reset(out);
        heading(
          '$_description.',
          'Value: ${value.isEmpty ? 'not set' : value}.',
        );
        hint(
          'Focus: ${_focusNames[focus]}. Tab moves; arrows adjust Slider; Enter activates Edit or Submit; F1 opens help; Escape cancels; Ctrl+C interrupts.',
        );
      }

      show();
      session?._setPromptRepaint(show);
      final stopResize = _watchIdleResize(
        observer: scripted.resizeObserver,
        profile: () => effectiveProfile,
        onGeometry: (geometry) => effectiveProfile = geometry,
        repaint: show,
        keys: inputKeys,
        helpOpen: () => help,
      );
      try {
        while (true) {
          final key = await inputKeys.next();
          if (key == null || key == '\x1a') return InputEnded();
          if (key == '\x03') return Interrupted();
          if (key == '\x1b') {
            if (!help) return Cancelled();
            help = false;
            out.writeln('Help dismissed.');
            show();
            continue;
          }
          if (_isHelpGesture(key)) {
            help = true;
            notice(_help(linear: false, focus: focus));
            continue;
          }
          if (help) continue;
          if (key == '\t') {
            focus = (focus + 1) % _focusNames.length;
            show();
            continue;
          }
          if (focus == 0 &&
              (key == '\x1b[C' ||
                  key == '\x1b[A' ||
                  key == '\x1b[D' ||
                  key == '\x1b[B')) {
            if (_validate(value) == null) {
              final candidate = _addDecimal(
                value,
                step,
                key == '\x1b[C' || key == '\x1b[A' ? 1 : -1,
              );
              if (_validate(candidate) == null) value = candidate;
            } else {
              notice(
                'Edit a valid value before adjusting.',
                event: StageEvent.warning,
              );
            }
            show();
            continue;
          }
          if ((key == '\r' || key == '\n') && focus == 1) {
            notice('Edit value; Enter finishes editing.');
            final edit = await _edit(
              inputKeys,
              value,
              out,
              helpText: _help(linear: false, focus: 1),
              outputProfile: effectiveProfile,
              structure: structure,
              session: session,
              resizeObserver: scripted.resizeObserver,
            );
            if (edit.action == 'interrupt') return Interrupted();
            if (edit.action == 'cancel') {
              notice('Edit dismissed.');
              show();
              session?._setPromptRepaint(show);
              continue;
            }
            if (edit.action != 'submit') return InputEnded();
            value = edit.value;
            final error = _validate(value);
            if (error != null) notice(error, event: StageEvent.warning);
            show();
            session?._setPromptRepaint(show);
            continue;
          }
          if ((key == '\r' || key == '\n') && focus == 2) {
            final error = _validate(value);
            if (error == null) return Accepted(value);
            notice(error, event: StageEvent.warning);
          }
        }
      } finally {
        stopResize();
        if (session != null) session._setPromptRepaint(null);
      }
    } finally {
      if (keys == null) await inputKeys.close();
    }
  }
}

(BigInt, int)? _decimal(String text) {
  if (!RegExp(r'^-?[0-9]+(?:\.[0-9]+)?$').hasMatch(text)) return null;
  final parts = text.split('.');
  return (BigInt.parse(parts.join()), parts.length == 2 ? parts[1].length : 0);
}

int _compare((BigInt, int) a, (BigInt, int) b) {
  final scale = a.$2 > b.$2 ? a.$2 : b.$2;
  return (a.$1 * BigInt.from(10).pow(scale - a.$2)).compareTo(
    b.$1 * BigInt.from(10).pow(scale - b.$2),
  );
}

String _addDecimal(String value, String step, int direction) {
  final a = _decimal(value)!;
  final b = _decimal(step)!;
  final scale = a.$2 > b.$2 ? a.$2 : b.$2;
  final number =
      a.$1 * BigInt.from(10).pow(scale - a.$2) +
      b.$1 * BigInt.from(10).pow(scale - b.$2) * BigInt.from(direction);
  final negative = number.isNegative;
  var digits = number.abs().toString().padLeft(scale + 1, '0');
  if (scale > 0) {
    digits =
        '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
  }
  return '${negative ? '-' : ''}$digits';
}

/// An exact pair of slider endpoints.
final class RangeSlider {
  RangeSlider(
    String label, {
    required String minimum,
    required String maximum,
    required String step,
    this.minimumGap = '0',
    this.initialLower,
    this.initialUpper,
    int? precision,
    String? units,
    ColorTheme colors = ColorThemes.terminalDefault,
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : _slider = Slider(
         label,
         minimum: minimum,
         maximum: maximum,
         step: step,
         precision: precision,
         units: units,
         colors: colors,
         structure: structure,
         instructions: instructions,
         supplementaryHelp: supplementaryHelp,
       ) {
    final gap = _decimal(minimumGap);
    if (gap == null ||
        gap.$1.isNegative ||
        (precision != null && gap.$2 > precision)) {
      throw ArgumentError.value(minimumGap, 'minimumGap');
    }
    if ((initialLower == null) != (initialUpper == null) ||
        (initialLower != null &&
            _pairError(initialLower!, initialUpper!) != null)) {
      throw ArgumentError('Invalid initial range.');
    }
  }

  final String minimumGap;
  final String? initialLower;
  final String? initialUpper;

  ColorTheme get colors => _slider.colors;

  PromptStructure get structure => _slider.structure;

  InstructionDisplay get instructions => _slider.instructions;

  List<String> get supplementaryHelp => _slider.supplementaryHelp;

  String? _pairError(String lower, String upper) {
    final l = _slider._validate(lower);
    if (l != null) return 'Lower: $l';
    final u = _slider._validate(upper);
    if (u != null) return 'Upper: $u';
    if (_compare(
          _decimal(_addDecimal(lower, minimumGap, 1))!,
          _decimal(upper)!,
        ) >
        0) {
      return 'Lower and Upper must remain ordered with minimum gap $minimumGap.';
    }
    return null;
  }

  final Slider _slider;
  bool _active = false;

  static const _focusNames = [
    'Lower',
    'Upper',
    'Edit Lower',
    'Edit Upper',
    'Submit',
  ];

  String get _gapCue => 'minimum gap $minimumGap';

  /// Component help for the requesting interaction stage.
  ///
  /// The opening sentence names the stage; endpoint identity, the pair gap and
  /// the accepted format stay in the same block so adjustment, editing and
  /// submission are never separated from the fields they act on.
  String _help({required bool linear, int focus = 0}) {
    final formatCue = _slider._formatCue;
    const dismissal = 'Escape cancels and Ctrl+C interrupts.';
    if (linear) {
      return 'Help: Entering the endpoints. Lower is asked first, then Upper; both keep their endpoint roles and the pair is reviewed on an empty line before acceptance. $_gapCue. $formatCue /cancel cancels. Exact /help and /cancel are commands; quote a command with a backslash.';
    }
    final endpoint = focus == 1 || focus == 3 ? 'Upper' : 'Lower';
    return switch (focus) {
      2 || 3 =>
        'Help: Editing the $endpoint endpoint. Type or correct exact decimal text; the pair is reviewed and validated against the bounds and the $_gapCue before Submit. $formatCue $dismissal',
      4 =>
        'Help: Submit. The pair is reviewed here: Enter accepts Lower and Upper together only when both are on the step grid, inside the bounds and ordered with $_gapCue; otherwise the error keeps the pair as a draft. $formatCue $dismissal',
      _ =>
        'Help: Adjusting the $endpoint endpoint. Left/Right or Up/Down move it by the step inside the bounds; a move that would cross below or above the other endpoint or violate the $_gapCue is refused. Tab reaches the other endpoint, the edit actions and Submit, and the pair is reviewed there as one answer. $formatCue $dismissal',
    };
  }

  Future<PromptResult<(String, String)>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      return session._promptRunner<(String, String)>(
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
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
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
          return await _terminal<(String, String)>(
            selected,
            output ?? stdout,
            (nativeSource, nativeMode, _) =>
                _run(nativeSource, nativeMode, outputProfile: outputProfile),
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

  Future<PromptResult<(String, String)>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final parts = source.value.split(',');
      if (parts.length != 2) {
        return Unavailable(
          'Supply Lower,Upper as two decimal values separated by a comma.',
        );
      }
      final error = _pairError(parts[0], parts[1]);
      return error == null
          ? Accepted((parts[0], parts[1]))
          : Unavailable(error);
    }
    final scripted = source as ScriptedInput;
    var effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
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
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    final sequential = !effectiveProfile.supportsRichInteraction;
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: _textInputWidth(effectiveProfile),
      background: colors.background,
      border: colors.border,
      rich: mode == PromptMode.rich,
      session: session,
    );
    // Guidance follows the current output geometry, so a resize repaint wraps
    // to the observed width instead of the invocation width.
    void emit(
      String text, {
      bool closes = false,
      StageEvent event = StageEvent.body,
    }) {
      spine.width = _textInputWidth(effectiveProfile);
      spine.write(
        out,
        text,
        foreground: colors.foreground,
        closes: closes,
        event: event,
      );
    }

    void hint(String text) {
      spine.width = _textInputWidth(effectiveProfile);
      spine.hint(out, text, foreground: colors.foreground);
    }

    // The stage heading is the slider's own description; the endpoints are body
    // content, so a diagnostic heading never spells a value in capitals.
    void heading(String title, String body) {
      spine.width = _textInputWidth(effectiveProfile);
      spine.opening(
        out,
        title: title,
        body: body,
        foreground: colors.foreground,
        bodyForeground: colors.foreground,
      );
    }

    // A refusal or a validation notice is a typed warning, so a grammar that
    // spells typed labels shows it as one; ordinary guidance stays a body row.
    void notice(String text, {StageEvent event = StageEvent.body}) =>
        emit(text, event: event);
    var lower = initialLower ?? '';
    var upper = initialUpper ?? '';
    heading(
      '${_slider._description}, $_gapCue.',
      'Lower: ${lower.isEmpty ? 'not set' : lower}; Upper: ${upper.isEmpty ? 'not set' : upper}.',
    );
    hint(
      mode == PromptMode.linear
          ? 'Lower is asked first, then Upper; the pair is reviewed before submission. /help explains the bounds; /cancel cancels.'
          : 'Focus: Lower. Tab moves; arrows adjust endpoints; Enter activates Edit or Submit; F1 opens help; Escape cancels; Ctrl+C interrupts.',
    );
    try {
      if (mode == PromptMode.linear) {
        while (true) {
          notice('Lower endpoint:');
          final l = await _edit(
            inputKeys,
            lower,
            out,
            linear: true,
            sequential: sequential,
            clearHelpCommand: true,
            linearHelpText: _help(linear: true),
            outputProfile: effectiveProfile,
            structure: structure,
            session: session,
          );
          if (l.action == 'cancel') return Cancelled();
          if (l.action == 'interrupt') return Interrupted();
          if (l.action != 'submit') return InputEnded();
          lower = l.value;
          final lowerError = _slider._validate(lower);
          if (lowerError != null) {
            notice(lowerError, event: StageEvent.warning);
            continue;
          }
          while (true) {
            notice('Upper endpoint:');
            final u = await _edit(
              inputKeys,
              upper,
              out,
              linear: true,
              sequential: sequential,
              clearHelpCommand: true,
              linearHelpText: _help(linear: true),
              outputProfile: effectiveProfile,
              structure: structure,
              session: session,
            );
            if (u.action == 'cancel') return Cancelled();
            if (u.action == 'interrupt') return Interrupted();
            if (u.action != 'submit') return InputEnded();
            upper = u.value;
            final upperError = _slider._validate(upper);
            if (upperError != null) {
              notice(upperError, event: StageEvent.warning);
              continue;
            }
            final pairError = _pairError(lower, upper);
            if (pairError != null) {
              notice(pairError, event: StageEvent.warning);
              break;
            }
            notice('Review Lower $lower, Upper $upper. Submit: press Enter.');
            final confirm = await _edit(
              inputKeys,
              '',
              out,
              linear: true,
              sequential: sequential,
              outputProfile: effectiveProfile,
              structure: structure,
              session: session,
            );
            if (confirm.action == 'cancel') return Cancelled();
            if (confirm.action == 'interrupt') return Interrupted();
            if (confirm.action != 'submit') return InputEnded();
            if (confirm.value.isEmpty) return Accepted((lower, upper));
            notice('Enter an empty line to submit, or edit the pair.');
            break;
          }
        }
      }
      var focus = 0;
      var help = false;
      void show() {
        spine.reset(out);
        heading(
          '${_slider._description}, $_gapCue.',
          'Lower: ${lower.isEmpty ? 'not set' : lower}; Upper: ${upper.isEmpty ? 'not set' : upper}.',
        );
        hint(
          'Focus: ${_focusNames[focus]}. Tab moves; arrows adjust endpoints; Enter activates Edit or Submit; F1 opens help; Escape cancels; Ctrl+C interrupts.',
        );
      }

      show();
      session?._setPromptRepaint(show);
      final stopResize = _watchIdleResize(
        observer: scripted.resizeObserver,
        profile: () => effectiveProfile,
        onGeometry: (geometry) => effectiveProfile = geometry,
        repaint: show,
        keys: inputKeys,
        helpOpen: () => help,
      );
      try {
        while (true) {
          final key = await inputKeys.next();
          if (key == null || key == '\x1a') return InputEnded();
          if (key == '\x03') return Interrupted();
          if (key == '\x1b') {
            if (!help) return Cancelled();
            help = false;
            notice('Help dismissed.');
            show();
            continue;
          }
          if (_isHelpGesture(key)) {
            help = true;
            notice(_help(linear: false, focus: focus));
            continue;
          }
          if (help) continue;
          if (key == '\t') {
            focus = (focus + 1) % _focusNames.length;
            show();
            continue;
          }
          if (focus < 2 &&
              (key == '\x1b[A' ||
                  key == '\x1b[B' ||
                  key == '\x1b[C' ||
                  key == '\x1b[D')) {
            if (_pairError(lower, upper) == null) {
              final current = focus == 0 ? lower : upper;
              final next = _addDecimal(
                current,
                _slider.step,
                key == '\x1b[A' || key == '\x1b[C' ? 1 : -1,
              );
              if (_pairError(
                    focus == 0 ? next : lower,
                    focus == 1 ? next : upper,
                  ) ==
                  null) {
                if (focus == 0) {
                  lower = next;
                } else {
                  upper = next;
                }
              }
            } else {
              notice(
                'Edit both endpoints to valid values before adjustment.',
                event: StageEvent.warning,
              );
            }
            show();
            continue;
          }
          if ((key == '\r' || key == '\n') && (focus == 2 || focus == 3)) {
            notice('${_focusNames[focus]}: Enter finishes editing.');
            final edit = await _edit(
              inputKeys,
              focus == 2 ? lower : upper,
              out,
              helpText: _help(linear: false, focus: focus),
              outputProfile: effectiveProfile,
              structure: structure,
              session: session,
              resizeObserver: scripted.resizeObserver,
            );
            if (edit.action == 'cancel') {
              notice('Edit dismissed.');
              show();
              session?._setPromptRepaint(show);
              continue;
            }
            if (edit.action == 'interrupt') return Interrupted();
            if (edit.action != 'submit') return InputEnded();
            if (focus == 2) {
              lower = edit.value;
            } else {
              upper = edit.value;
            }
            final error = _pairError(lower, upper);
            if (error != null) notice(error, event: StageEvent.warning);
            show();
            session?._setPromptRepaint(show);
            continue;
          }
          if ((key == '\r' || key == '\n') && focus == 4) {
            final error = _pairError(lower, upper);
            if (error == null) return Accepted((lower, upper));
            notice(error, event: StageEvent.warning);
          }
        }
      } finally {
        stopResize();
        if (session != null) session._setPromptRepaint(null);
      }
    } finally {
      if (keys == null) await inputKeys.close();
    }
  }
}
