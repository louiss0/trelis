part of 'text_input.dart';

/// Selects an IANA zone identity from the bundled tzdata2025c snapshot.
/// Offset previews are not supplied; no local timezone or network is consulted.
final class TimezoneSelect {
  TimezoneSelect(String label, {String? defaultValue})
    : _select = _createTimezoneSelect(label, defaultValue);

  final SearchSelect<String> _select;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) => _select.prompt(
    source: source,
    mode: mode,
    userPreference: userPreference,
    applicationPreference: applicationPreference,
    output: output,
  );
}

SearchSelect<String> _createTimezoneSelect(String label, String? defaultValue) {
  final choices = [
    for (final name in _ianaZones.keys) Choice(name, name.replaceAll('_', ' ')),
  ];
  return SearchSelect<String>(
    '$label (IANA tzdata 2025c; search identifiers, city names and aliases; no offset previews)',
    choices,
    defaultValue: defaultValue,
    search: (query) {
      final q = query.toLowerCase();
      return [
        for (final choice in choices)
          if (choice.value.toLowerCase().contains(q) ||
              choice.label.toLowerCase().contains(q) ||
              _ianaZones[choice.value]!.any(
                (alias) => alias.toLowerCase().contains(q),
              ))
            choice,
      ];
    },
  );
}
