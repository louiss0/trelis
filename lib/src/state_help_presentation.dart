/// Internal, reusable state and help presentation primitives.
///
/// These declarations describe display-safe text only. They never read input,
/// mutate a component or write to a terminal, so a component family can adopt
/// them without changing its task behavior or its interaction rules. This
/// library is deliberately absent from the public export barrel.
library;

import 'package:characters/characters.dart';

import 'presentation.dart' show DisplayText;

/// Whether a presentation uses the Unicode or portable ASCII vocabulary.
enum StateGlyphs { unicode, ascii }

/// The built-in selected/unselected pair for single-choice presentation.
enum SingleSelectionStyle {
  circles(
    selected: '●',
    unselected: '○',
    asciiSelected: '(*)',
    asciiUnselected: '( )',
  ),
  squares(
    selected: '■',
    unselected: '□',
    asciiSelected: '[x]',
    asciiUnselected: '[ ]',
  ),
  triangles(
    selected: '▲',
    unselected: '△',
    asciiSelected: '<^>',
    asciiUnselected: '< >',
  ),
  dotsInCircles(
    selected: '◉',
    unselected: '○',
    asciiSelected: '(o)',
    asciiUnselected: '(.)',
  ),
  checkmarks(
    selected: '✓',
    unselected: '○',
    asciiSelected: 'x',
    asciiUnselected: '-',
  );

  const SingleSelectionStyle({
    required this.selected,
    required this.unselected,
    required this.asciiSelected,
    required this.asciiUnselected,
  });

  final String selected;
  final String unselected;
  final String asciiSelected;
  final String asciiUnselected;

  String get unicodePair => '$selected/$unselected';
  String get asciiPair => '$asciiSelected/$asciiUnselected';

  /// The marker for [selectedState] in the requested [glyphs].
  String selectedGlyph(StateGlyphs glyphs, {required bool selectedState}) =>
      switch (glyphs) {
        StateGlyphs.unicode => selectedState ? selected : unselected,
        StateGlyphs.ascii => selectedState ? asciiSelected : asciiUnselected,
      };
}

/// The independently presented expansion state of a tree row.
enum DisclosureState { leaf, expanded, collapsed }

/// Why a choice cannot be selected or accepted.
enum ChoiceRestriction { none, locked, unavailable }

/// The aligned markers of one choice row.
///
/// Each state occupies its own position, so focus, selection, default and a
/// restriction never overwrite each other. The disclosure position stays
/// blank for a leaf instead of disappearing.
final class ChoiceMarkers {
  const ChoiceMarkers({
    required this.disclosure,
    required this.selection,
    required this.focus,
    required this.defaultMarker,
    required this.restriction,
    required this.reason,
  });

  final String disclosure;
  final String selection;
  final String focus;
  final String defaultMarker;
  final String restriction;

  /// The readable explanation, or null when the row has no restriction.
  final String? reason;

  /// The fixed-width marker prefix used by [renderChoiceRow].
  String get prefix =>
      '$disclosure ${selection.padRight(3)} $focus $defaultMarker '
      '${restriction.padRight(3)} ';
}

/// One display-safe choice row.
final class ChoicePresentation {
  const ChoicePresentation({
    required this.label,
    this.reference,
    this.focused = false,
    this.checked,
    this.selected,
    this.isDefault = false,
    this.style = SingleSelectionStyle.circles,
    this.disclosure = DisclosureState.leaf,
    this.restriction = ChoiceRestriction.none,
    this.reason,
  }) : assert(
         checked == null || selected == null,
         'A row has either a multi-selection or a single-selection state.',
       ),
       assert(
         restriction == ChoiceRestriction.none || reason != null,
         'A locked or unavailable row needs a readable reason.',
       );

  final String label;
  final int? reference;
  final bool focused;

  /// The multi-selection draft state, or null for a family without one.
  final bool? checked;

  /// The single-selection draft state, or null for a family without one.
  final bool? selected;

  /// Marks the configured default without implying that it is selected.
  final bool isDefault;
  final SingleSelectionStyle style;
  final DisclosureState disclosure;
  final ChoiceRestriction restriction;
  final String? reason;

  /// Restricted rows remain focusable so their reasons can be inspected.
  bool get focusable => true;

  /// Only an unrestricted row can change the draft selection.
  bool get selectable => restriction == ChoiceRestriction.none;

  /// A locked or unavailable row can never be accepted as the answer.
  bool get acceptable => selectable;

  ChoiceMarkers markers({StateGlyphs glyphs = StateGlyphs.unicode}) {
    if (restriction != ChoiceRestriction.none &&
        (reason == null || reason!.trim().isEmpty)) {
      throw StateError(
        'A locked or unavailable row needs a readable reason: $label',
      );
    }
    final selection = switch (selected) {
      bool value => style.selectedGlyph(glyphs, selectedState: value),
      null => switch (checked) {
        bool value => _checkedGlyph(glyphs, checkedState: value),
        null => '',
      },
    };
    return ChoiceMarkers(
      disclosure: switch (disclosure) {
        DisclosureState.leaf => ' ',
        DisclosureState.expanded => switch (glyphs) {
          StateGlyphs.unicode => '▾',
          StateGlyphs.ascii => 'v',
        },
        DisclosureState.collapsed => switch (glyphs) {
          StateGlyphs.unicode => '▸',
          StateGlyphs.ascii => '>',
        },
      },
      selection: selection,
      focus: focused
          ? switch (glyphs) {
              StateGlyphs.unicode => '→',
              StateGlyphs.ascii => '>',
            }
          : ' ',
      defaultMarker: isDefault
          ? switch (glyphs) {
              StateGlyphs.unicode => '★',
              StateGlyphs.ascii => 'D',
            }
          : ' ',
      restriction: switch (restriction) {
        ChoiceRestriction.none => '',
        ChoiceRestriction.locked => '[L]',
        ChoiceRestriction.unavailable => '[!]',
      },
      reason: reason,
    );
  }
}

String _checkedGlyph(StateGlyphs glyphs, {required bool checkedState}) =>
    switch (glyphs) {
      StateGlyphs.unicode => checkedState ? '✓' : '○',
      StateGlyphs.ascii => checkedState ? 'x' : '-',
    };

/// Renders one row without colour: state distinctions never depend on colour.
///
/// Markers stay atomic when the row is narrow. If the label does not fit after
/// the aligned prefix, it wraps under a hanging indent rather than splitting a
/// marker or hiding the readable restriction reason.
String renderChoiceRow(
  ChoicePresentation row, {
  StateGlyphs glyphs = StateGlyphs.unicode,
  int? width,
}) {
  final markers = row.markers(glyphs: glyphs);
  final prefix = markers.prefix;
  final reason = markers.reason == null ? '' : ' ${markers.reason}';
  final label = DisplayText.from('${row.label}$reason').value;
  final prefixCells = prefix.characters.length;
  final available = width == null
      ? null
      : (width - prefixCells).clamp(1, width);
  final lines = _wrapWords(label, available);
  if (lines.isEmpty) return prefix.trimRight();
  return [
    '$prefix${lines.first}',
    for (final line in lines.skip(1)) '${' ' * prefixCells}$line',
  ].join('\n');
}

List<String> _wrapWords(String text, int? width) {
  if (width == null) return [text];
  final lines = <String>[];
  var current = '';
  void flush() {
    if (current.isNotEmpty) lines.add(current);
    current = '';
  }

  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    if (word.characters.length > width) {
      flush();
      var cluster = '';
      for (final character in word.characters) {
        if (cluster.characters.length == width) {
          lines.add(cluster);
          cluster = '';
        }
        cluster += character;
      }
      current = cluster;
      continue;
    }
    if (current.isEmpty) {
      current = word;
    } else if (current.characters.length + 1 + word.characters.length <=
        width) {
      current = '$current $word';
    } else {
      flush();
      current = word;
    }
  }
  flush();
  return lines;
}

/// A semantic status whose symbol is always accompanied by a text label.
enum Status { success, warning, error }

String renderStatus(
  Status status,
  String message, {
  StateGlyphs glyphs = StateGlyphs.unicode,
}) {
  final symbol = switch (status) {
    Status.success => switch (glyphs) {
      StateGlyphs.unicode => '✓',
      StateGlyphs.ascii => '+',
    },
    Status.warning => '!',
    Status.error => switch (glyphs) {
      StateGlyphs.unicode => '×',
      StateGlyphs.ascii => 'x',
    },
  };
  final label = switch (status) {
    Status.success => 'Success',
    Status.warning => 'Warning',
    Status.error => 'Error',
  };
  return '$symbol $label: ${DisplayText.from(message).value}';
}
