part of 'text_input.dart';

/// Selects an IANA zone identity from the bundled tzdata2025c snapshot.
/// Offset previews are not supplied; no local timezone or network is consulted.
final class TimezoneSelect {
  TimezoneSelect(
    String label, {
    String? defaultValue,
    Map<String, String> unavailable = const {},
  }) : _select = _createTimezoneSelect(label, defaultValue, unavailable);

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

SearchSelect<String> _createTimezoneSelect(
  String label,
  String? defaultValue,
  Map<String, String> unavailable,
) {
  final disabled = <String, String>{};
  for (final entry in unavailable.entries) {
    final name = _canonicalZone(entry.key);
    if (disabled.containsKey(name))
      throw ArgumentError("Duplicate unavailable zone identity.");
    disabled[name] = entry.value;
  }
  final choices = [
    for (final name in _ianaZones.keys)
      Choice(name, name.replaceAll('_', ' '), disabledReason: disabled[name]),
  ];
  return SearchSelect<String>(
    '$label (IANA tzdata 2025c; search identifiers, city names and aliases; no offset previews)',
    choices,
    defaultValue: defaultValue == null ? null : _canonicalZone(defaultValue),
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
