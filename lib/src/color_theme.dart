import 'output_profile.dart';

/// An opaque terminal colour request.
sealed class TerminalColor {
  const TerminalColor._();

  const factory TerminalColor.terminalDefault() = _TerminalDefault;

  factory TerminalColor.indexed(int index) {
    _checkByte(index, 'index');
    return _IndexedTerminalColor(index);
  }

  factory TerminalColor.rgb(int red, int green, int blue) {
    _checkByte(red, 'red');
    _checkByte(green, 'green');
    _checkByte(blue, 'blue');
    return _RgbTerminalColor(red, green, blue);
  }

  static void _checkByte(int value, String name) {
    if (value < 0 || value > 255) {
      throw ArgumentError.value(value, name, 'must be in 0..255');
    }
  }
}

final class _TerminalDefault extends TerminalColor {
  const _TerminalDefault() : super._();
}

final class _IndexedTerminalColor extends TerminalColor {
  const _IndexedTerminalColor(this.index) : super._();
  final int index;
}

final class _RgbTerminalColor extends TerminalColor {
  const _RgbTerminalColor(this.red, this.green, this.blue) : super._();
  final int red;
  final int green;
  final int blue;
}

/// A complete immutable palette for semantic prompt roles.
final class ColorTheme {
  const ColorTheme({
    required this.foreground,
    required this.background,
    required this.muted,
    required this.accent,
    required this.selectionForeground,
    required this.selectionBackground,
    required this.success,
    required this.warning,
    required this.error,
    required this.border,
  });
  final TerminalColor foreground;
  final TerminalColor background;
  final TerminalColor muted;
  final TerminalColor accent;
  final TerminalColor selectionForeground;
  final TerminalColor selectionBackground;
  final TerminalColor success;
  final TerminalColor warning;
  final TerminalColor error;
  final TerminalColor border;

  ColorTheme copyWith({
    TerminalColor? foreground,
    TerminalColor? background,
    TerminalColor? muted,
    TerminalColor? accent,
    TerminalColor? selectionForeground,
    TerminalColor? selectionBackground,
    TerminalColor? success,
    TerminalColor? warning,
    TerminalColor? error,
    TerminalColor? border,
  }) => ColorTheme(
    foreground: foreground ?? this.foreground,
    background: background ?? this.background,
    muted: muted ?? this.muted,
    accent: accent ?? this.accent,
    selectionForeground: selectionForeground ?? this.selectionForeground,
    selectionBackground: selectionBackground ?? this.selectionBackground,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    border: border ?? this.border,
  );
}

/// Built-in immutable colour palettes.
abstract final class ColorThemes {
  static const terminalDefault = ColorTheme(
    foreground: TerminalColor.terminalDefault(),
    background: TerminalColor.terminalDefault(),
    muted: TerminalColor.terminalDefault(),
    accent: TerminalColor.terminalDefault(),
    selectionForeground: TerminalColor.terminalDefault(),
    selectionBackground: TerminalColor.terminalDefault(),
    success: TerminalColor.terminalDefault(),
    warning: TerminalColor.terminalDefault(),
    error: TerminalColor.terminalDefault(),
    border: TerminalColor.terminalDefault(),
  );
}

bool isTerminalDefault(TerminalColor color) => color is _TerminalDefault;

String terminalSgr(
  TerminalColor color, {
  required bool background,
  required ColorDepth depth,
}) {
  final prefix = background ? 48 : 38;
  if (color is _TerminalDefault) {
    return '${background ? 49 : 39}';
  }
  if (depth == ColorDepth.rgb && color is _RgbTerminalColor) {
    return '$prefix;2;${color.red};${color.green};${color.blue}';
  }
  final int index = color is _IndexedTerminalColor
      ? color.index
      : _rgbIndex(color as _RgbTerminalColor);
  if (depth == ColorDepth.indexed256 || depth == ColorDepth.rgb) {
    return '$prefix;5;$index';
  }
  return '${(background ? 40 : 30) + _ansi16Index(index)}';
}

int _rgbIndex(_RgbTerminalColor color) {
  // xterm's 6x6x6 cube; nearest component ties choose the lower index.
  int level(int value) => ((value * 5) ~/ 255);
  return 16 +
      36 * level(color.red) +
      6 * level(color.green) +
      level(color.blue);
}

int _ansi16Index(int index) => index < 8 ? index : index % 8;
