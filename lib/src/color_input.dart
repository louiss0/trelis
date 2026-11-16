part of 'text_input.dart';

/// An sRGB color and the original validated expression.
final class ColorValue {
  ColorValue._(
    this.source,
    this.red,
    this.green,
    this.blue,
    this.alpha, [
    this.hue,
  ]);
  final String source;
  final double red;
  final double green;
  final double blue;
  final double alpha;

  /// HSL hue normalized to degrees in [0, 360), when entered as HSL.
  final double? hue;
}

/// Textual sRGB color entry.
final class ColorInput {
  ColorInput(
    String label, {
    this.required = true,
    String initialValue = '',
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
  }) : initialValue = initialValue,
       supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (initialValue.isNotEmpty && _parseColor(initialValue) == null) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
    _input = TextInput._(
      '$label (CSS sRGB color: hex, RGB, HSL, or static name).',
      required: required,
      initialValue: this.initialValue,
      onChanged: _showPreview,
      validate: (value) =>
          value.isEmpty && !required || _parseColor(value) != null ? null : 'Enter a valid sRGB color: hex, static name, or literal RGB/HSL. RGB channels must be 0-255 or 0-100%; HSL saturation and lightness 0-100%; alpha 0-1 or 0-100%. Use at most 12 digits per number; expressions and other color spaces are not supported.',
      instructions: instructions,
      supplementaryHelp: [
        'Color format: CSS Color 4 sRGB #RGB, #RGBA, #RRGGBB, #RRGGBBAA, literal RGB/HSL, and static names. Alpha is last, hue wraps modulo 360 degrees, and ASCII decimals use at most 12 digits. Expressions and other colour spaces are not supported.',
        ...supplementaryHelp,
      ],
      colors: colors,
      structure: structure,
    );
  }
  final bool required;
  final String initialValue;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final ColorTheme colors;
  final PromptStructure structure;
  late final TextInput _input;
  StringSink? _sink;
  bool _active = false;

  void _showPreview(String text) {
    final value = _parseColor(text);
    final sink = _sink;
    if (sink == null) return;
    final preview = _structureSpine(
      null,
      structure: structure,
      width: null,
      background: colors.background,
      border: colors.border,
    );
    if (value == null) {
      preview.hint(
        sink,
        text.isEmpty
            ? 'Preview unavailable: no color entered.'
            : 'Preview unavailable: draft is not a valid color.',
        foreground: colors.warning,
      );
      return;
    }
    String byte(double v) =>
        (v * 255).round().toRadixString(16).padLeft(2, '0');
    preview.write(
      sink,
      'Value: ${value.source}. sRGB: ${value.red}, ${value.green}, ${value.blue}. Alpha: ${value.alpha}.${value.hue == null ? '' : ' Hue: ${value.hue} degrees (modulo 360).'}',
      foreground: colors.foreground,
    );
    preview.write(
      sink,
      'approximate rounded hex preview: #${byte(value.red)}${byte(value.green)}${byte(value.blue)}${byte(value.alpha)} (not the stored value).',
      foreground: colors.foreground,
      closes: true,
    );
  }

  Future<PromptResult<ColorValue?>> prompt({
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
    _sink = source is ScriptedInput
        ? source.output
        : source == null
        ? (session != null
              ? _SessionOutputSink(session)
              : output ?? terminal?.output ?? stderr)
        : null;
    try {
      final result = await _input.prompt(
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
        session: session,
      );
      if (result is Accepted<String>) {
        final value = result.value.isEmpty ? null : _parseColor(result.value)!;
        return Accepted(value);
      }
      if (result is Cancelled<String>) return Cancelled();
      if (result is Interrupted<String>) return Interrupted();
      if (result is InputEnded<String>) return InputEnded();
      return Unavailable((result as Unavailable<String>).reason);
    } finally {
      _sink = null;
      _active = false;
    }
  }
}

ColorValue? _parseColor(String value) {
  if (value.runes.any((c) => c < 32 || c > 126)) return null;
  if (value.toLowerCase() == 'transparent') {
    return ColorValue._(value, 0, 0, 0, 0);
  }
  final named = _colorNames[value.toLowerCase()];
  if (named != null) {
    return ColorValue._(
      value,
      ((named >> 16) & 255) / 255,
      ((named >> 8) & 255) / 255,
      (named & 255) / 255,
      1,
    );
  }
  final hsl = RegExp(
    r'^hsla?\((.*)\)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (hsl != null) {
    final body = hsl[1]!;
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
    final hueMatch = RegExp(
      r'^([+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+))(deg|grad|rad|turn)?$',
      caseSensitive: false,
    ).firstMatch(parts[0]);
    if (hueMatch == null) return null;
    final hueNumber = _colorNumber(hueMatch[1]!);
    if (hueNumber == null) return null;
    final unit = hueMatch[2]?.toLowerCase();
    final hue =
        (hueNumber *
            (unit == 'grad'
                ? .9
                : unit == 'turn'
                ? 360
                : unit == 'rad'
                ? 180 / 3.141592653589793
                : 1)) %
        360;
    if (!parts[1].endsWith('%') || !parts[2].endsWith('%')) return null;
    final saturation = _colorNumber(parts[1].substring(0, parts[1].length - 1));
    final lightness = _colorNumber(parts[2].substring(0, parts[2].length - 1));
    if (saturation == null ||
        lightness == null ||
        saturation < 0 ||
        saturation > 100 ||
        lightness < 0 ||
        lightness > 100) {
      return null;
    }
    var alpha = 1.0;
    if (parts.length == 4) {
      final isPercent = parts[3].endsWith('%');
      final n = _colorNumber(
        isPercent ? parts[3].substring(0, parts[3].length - 1) : parts[3],
      );
      final max = isPercent ? 100 : 1;
      if (n == null || n < 0 || n > max) return null;
      alpha = n / max;
    }
    final s = saturation / 100;
    final l = lightness / 100;
    final a = s * (l < 1 - l ? l : 1 - l);
    double channel(int n) {
      final k = (n + hue / 30) % 12;
      final t = [k - 3, 9 - k, 1.0].reduce((x, y) => x < y ? x : y);
      return l - a * (t > -1 ? t : -1);
    }

    return ColorValue._(value, channel(0), channel(8), channel(4), alpha, hue);
  }
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
    if (legacy &&
        parts.take(3).map((x) => x.endsWith('%')).toSet().length != 1) {
      return null;
    }
    final channels = <double>[];
    for (var i = 0; i < parts.length; i++) {
      final token = parts[i];
      final percent = token.endsWith('%');
      final number = percent ? token.substring(0, token.length - 1) : token;
      if (!RegExp(r'^[+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)$')
              .hasMatch(number) ||
          number.replaceAll(RegExp(r'[^0-9]'), '').length > 12) {
        return null;
      }
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
      .hasMatch(value)) {
    return null;
  }
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

double? _colorNumber(String text) {
  if (!RegExp(r'^[+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)$').hasMatch(text) ||
      text.replaceAll(RegExp(r'[^0-9]'), '').length > 12) {
    return null;
  }
  final n = double.tryParse(text);
  return n != null && n.isFinite ? n : null;
}
