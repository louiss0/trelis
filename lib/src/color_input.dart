part of 'text_input.dart';

/// An sRGB color and the original validated expression.
final class ColorValue {
  ColorValue._(this.source, this.red, this.green, this.blue, this.alpha);
  final String source;
  final double red;
  final double green;
  final double blue;
  final double alpha;
}

/// Textual sRGB color entry.
final class ColorInput {
  ColorInput(String label, {this.required = true, String initialValue = ''}) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (initialValue.isNotEmpty && _parseColor(initialValue) == null) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
    _input = TextInput(
      label,
      required: required,
      initialValue: initialValue,
      validate: (value) =>
          value.isEmpty && !required || _parseColor(value) != null
          ? null
          : 'Enter a valid sRGB color.',
    );
  }
  final bool required;
  late final TextInput _input;
  Future<PromptResult<ColorValue?>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    final result = await _input.prompt(
      source: source,
      mode: mode,
      userPreference: userPreference,
      applicationPreference: applicationPreference,
      output: output,
    );
    if (result is Accepted<String>)
      return Accepted(result.value.isEmpty ? null : _parseColor(result.value)!);
    if (result is Cancelled<String>) return Cancelled();
    if (result is Interrupted<String>) return Interrupted();
    if (result is InputEnded<String>) return InputEnded();
    return Unavailable((result as Unavailable<String>).reason);
  }
}

ColorValue? _parseColor(String value) {
  final function = RegExp(
    r'^rgba?\((.*)\)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (function != null) {
    final body = function[1]!;
    final legacy = body.contains(',');
    final List<String> parts;
    if (legacy) {
      if (body.contains('/')) return null;
      parts = body.split(',').map((x) => x.trim()).toList();
    } else {
      final slash = body.split('/');
      if (slash.length > 2) return null;
      parts = slash[0].trim().split(RegExp(r'\s+'));
      if (slash.length == 2) parts.add(slash[1].trim());
    }
    if (parts.length != 3 && parts.length != 4) return null;
    if (legacy && parts.take(3).map((x) => x.endsWith('%')).toSet().length != 1)
      return null;
    final channels = <double>[];
    for (var i = 0; i < parts.length; i++) {
      final token = parts[i];
      final percent = token.endsWith('%');
      final number = percent ? token.substring(0, token.length - 1) : token;
      if (!RegExp(r'^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$')
              .hasMatch(number) ||
          number.replaceAll(RegExp(r'[^0-9]'), '').length > 12)
        return null;
      final n = double.tryParse(number);
      final max = percent ? 100 : (i == 3 ? 1 : 255);
      if (n == null || !n.isFinite || n < 0 || n > max) return null;
      channels.add(n / max);
    }
    return ColorValue._(
      value,
      channels[0],
      channels[1],
      channels[2],
      channels.length == 4 ? channels[3] : 1,
    );
  }
  if (!RegExp(r'^#(?:[a-fA-F0-9]{3,4}|[a-fA-F0-9]{6}|[a-fA-F0-9]{8})$')
      .hasMatch(value))
    return null;
  var h = value.substring(1);
  if (h.length <= 4) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h += 'ff';
  return ColorValue._(
    value,
    int.parse(h.substring(0, 2), radix: 16) / 255,
    int.parse(h.substring(2, 4), radix: 16) / 255,
    int.parse(h.substring(4, 6), radix: 16) / 255,
    int.parse(h.substring(6, 8), radix: 16) / 255,
  );
}
