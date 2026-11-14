import 'package:characters/characters.dart';
import 'package:termunicode/termunicode.dart' as termunicode;

/// Maps editable grapheme clusters to their safe terminal representation.
///
/// Editing remains based on `characters`; this adapter only measures the
/// resulting display.  It deliberately uses termunicode scalar properties,
/// not its string helpers, because a display cluster has Trelis-specific
/// visible-control and selector rules.
final class TextDisplayMap {
  TextDisplayMap(String value, {this.ambiguousIsWide = false})
    : entries = List.unmodifiable([
        for (final cluster in value.characters)
          TextDisplayEntry._(cluster, ambiguousIsWide: ambiguousIsWide),
      ]);

  final bool ambiguousIsWide;
  final List<TextDisplayEntry> entries;

  int get cellWidth => entries.fold(0, (sum, entry) => sum + entry.cellWidth);

  /// Cell offset at a grapheme boundary. Values outside the editable boundary
  /// range are programmer errors rather than silently rounded caret positions.
  int caretCells(int graphemeOffset) {
    if (graphemeOffset < 0 || graphemeOffset > entries.length) {
      throw RangeError.range(
        graphemeOffset,
        0,
        entries.length,
        'graphemeOffset',
      );
    }
    return entries
        .take(graphemeOffset)
        .fold(0, (sum, entry) => sum + entry.cellWidth);
  }

  String displayBetween(int start, int end) =>
      entries.sublist(start, end).map((entry) => entry.display).join();
}

final class TextDisplayEntry {
  TextDisplayEntry._(this.original, {required bool ambiguousIsWide})
    : display = displaySafe(original),
      cellWidth = _width(original, ambiguousIsWide: ambiguousIsWide);

  final String original;
  final String display;
  final int cellWidth;

  static int _width(String cluster, {required bool ambiguousIsWide}) {
    final visible = displaySafe(cluster);
    // Controls, formats, bidi formatting and tabs are rendered as their
    // visible `\\u{XXXX}` spelling. A tab is never emitted as whitespace.
    if (visible != cluster) return visible.length;
    final runes = cluster.runes.toList();
    if (runes.isEmpty) return 0;
    // The package's blanket VS16 promotion is unsuitable for a standalone
    // selector. Trelis accepts a selector only as part of visible content.
    final visibleRunes = runes.where(
      (rune) =>
          rune != 0xfe0e &&
          rune != 0xfe0f &&
          rune != 0x200d &&
          !termunicode.isNonPrintableCp(rune),
    );
    if (visibleRunes.isEmpty) return 0;
    if (runes.contains(0x20e3)) return 2; // keycap with or without VS16.
    if (runes.contains(0xfe0f)) return 2;
    // Keep `characters` cluster segmentation, then select its leading scalar
    // under the pinned Unicode-16 table and declared ambiguous-width policy.
    return termunicode.widthCp(runes.first, cjk: ambiguousIsWide);
  }
}

/// The single display-escaping policy for text that may contain terminal
/// instructions or directionality controls.
///
/// The policy is applied per grapheme cluster, which is the unit the layout
/// measures. Control, format, separator, surrogate, unassigned and private-use
/// code points become their visible `\\u{XXXX}` spelling, a joiner stays part of
/// a supported cluster (such as an emoji sequence), and a dangling joiner at a
/// cluster boundary is spelled out. Measured display entries and protected
/// presentation content both use this policy, so the same text is never spelled
/// one way by the layout path and another by an unwrapped one.
String displaySafe(String value) {
  final result = StringBuffer();
  for (final cluster in value.characters) {
    result.write(_displayCluster(cluster));
  }
  return result.toString();
}

String _displayCluster(String cluster) {
  final runes = cluster.runes.toList();
  final hasVisibleBase = runes.any(
    (rune) =>
        !termunicode.isNonPrintableCp(rune) && termunicode.widthCp(rune) > 0,
  );
  final result = StringBuffer();
  for (final rune in runes) {
    if ((termunicode.isNonPrintableCp(rune) &&
            !(rune == 0x200d && hasVisibleBase && runes.last != 0x200d)) ||
        rune == 0x061c ||
        (rune >= 0x200e && rune <= 0x200f) ||
        (rune >= 0x202a && rune <= 0x202e) ||
        (rune >= 0x2066 && rune <= 0x2069)) {
      result.write(r'\u{');
      result.write(rune.toRadixString(16).toUpperCase().padLeft(4, '0'));
      result.write('}');
    } else {
      result.writeCharCode(rune);
    }
  }
  return result.toString();
}
