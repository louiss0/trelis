part of 'text_input.dart';

/// Selects an IANA zone identity from the bundled tzdata2025c snapshot.
/// Offset previews are not supplied; no local timezone or network is consulted.
final class TimezoneSelect {
  TimezoneSelect(
    String label, {
    String? defaultValue,
    Map<String, String> unavailable = const {},
    ColorTheme colors = ColorThemes.terminalDefault,
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : _select = _createTimezoneSelect(
         label,
         defaultValue,
         unavailable,
         colors,
         structure,
         instructions,
         supplementaryHelp,
       );

  ColorTheme get colors => _select.colors;

  PromptStructure get structure => _select.structure;

  InstructionDisplay get instructions => _select.instructions;

  List<String> get supplementaryHelp => _select.supplementaryHelp;

  final SearchSelect<String> _select;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) => _select.prompt(
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

SearchSelect<String> _createTimezoneSelect(
  String label,
  String? defaultValue,
  Map<String, String> unavailable,
  ColorTheme colors,
  PromptStructure structure,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
) {
  if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
    throw ArgumentError.value(label, 'label');
  }
  final disabled = <String, String>{};
  for (final entry in unavailable.entries) {
    final name = _canonicalZone(entry.key);
    if (disabled.containsKey(name)) {
      throw ArgumentError('Duplicate unavailable zone identity.');
    }
    disabled[name] = entry.value;
  }
  final choices = [
    for (final name in _ianaZones.keys)
      Choice(name, name.replaceAll('_', ' '), disabledReason: disabled[name]),
  ];
  return SearchSelect<String>._timezone(
    '$label (IANA tzdata 2025c; search identifiers, city names and aliases; no offset previews)',
    choices,
    colors: colors,
    structure: structure,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
    defaultValue: defaultValue == null ? null : _canonicalZone(defaultValue),
    matches: (choice, query) {
      final q = query.toLowerCase();
      return choice.value.toLowerCase().contains(q) ||
          choice.label.toLowerCase().contains(q) ||
          _ianaZones[choice.value]!.any(
            (alias) => alias.toLowerCase().contains(q),
          );
    },
  );
}

String _canonicalZone(String identifier) {
  if (_ianaZones.containsKey(identifier)) return identifier;
  for (final entry in _ianaZones.entries) {
    if (entry.value.contains(identifier)) return entry.key;
  }
  throw ArgumentError.value(
    identifier,
    'defaultValue',
    'Unknown IANA zone in tzdata 2025c.',
  );
}
