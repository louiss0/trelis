import 'dart:io';

/// Semantic meaning that remains readable without color.
enum TextKind { ordinary, hint, success, warning, error }

String _safe(String value) => value.runes.map((c) {
  if (c < 32 ||
      (c >= 127 && c <= 159) ||
      c == 0x2028 ||
      c == 0x2029 ||
      (c >= 0x202a && c <= 0x202e) ||
      (c >= 0x2066 && c <= 0x2069)) {
    return r'\u' + c.toRadixString(16).padLeft(4, '0');
  }
  return String.fromCharCode(c);
}).join();

/// Literal, feedback-only text.
final class Text {
  Text(this.content, {this.kind = TextKind.ordinary});
  final String content;
  final TextKind kind;

  void present({StringSink? output}) {
    final prefix = switch (kind) {
      TextKind.ordinary => '',
      TextKind.hint => 'Hint: ',
      TextKind.success => 'Success: ',
      TextKind.warning => 'Warning: ',
      TextKind.error => 'Error: ',
    };
    (output ?? stderr).writeln('$prefix${_safe(content)}');
  }
}
