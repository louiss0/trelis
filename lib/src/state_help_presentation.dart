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

/// The interaction direction a presentation must respect.
enum PresentationMode { rich, linear, screenReader }

/// Which component-safe help route applies to a prompt.
enum ComponentRoute { standard, secret, keyCapture }

/// How much opening guidance an application requested.
enum InstructionVisibility { expanded, compact, hidden }

/// The kind of help route advertised by a prompt.
enum HelpRouteKind { shortcut, command, outsideCapture }

/// A component-safe route to detailed help.
final class HelpRoute {
  const HelpRoute({
    required this.kind,
    required this.text,
    required this.shortText,
    this.gesture,
  });

  final HelpRouteKind kind;
  final String text;
  final String shortText;

  /// The gesture reserved for help, or null when no gesture is consumed.
  final String? gesture;
}

/// Returns the help route that is safe for [component] in [mode].
///
/// Key capture advertises a route outside the armed capture so a captured
/// gesture is never reinterpreted as help. Secret entry keeps the same route
/// but promises that its value stays hidden.
HelpRoute helpRoute({
  required PresentationMode mode,
  ComponentRoute component = ComponentRoute.standard,
}) {
  if (component == ComponentRoute.keyCapture) {
    return const HelpRoute(
      kind: HelpRouteKind.outsideCapture,
      text: 'Use /help after capture to open help.',
      shortText: '/help after capture',
    );
  }
  // Hidden entry treats a typed `/help` line as answer data, so its route is
  // the non-command shortcut in both rich and linear presentation.
  if (component == ComponentRoute.secret) {
    return const HelpRoute(
      kind: HelpRouteKind.shortcut,
      text: 'Ctrl+T opens help; hidden values stay hidden.',
      shortText: 'Ctrl+T help; hidden',
      gesture: 'Ctrl+T',
    );
  }
  if (mode == PresentationMode.rich) {
    return HelpRoute(
      kind: HelpRouteKind.shortcut,
      text: 'Ctrl+T opens help.',
      shortText: 'Ctrl+T help',
      gesture: 'Ctrl+T',
    );
  }
  return HelpRoute(
    kind: HelpRouteKind.command,
    text: '/help opens help.',
    shortText: '/help',
  );
}

/// The mandatory compact primary-action and help hint.
final class CompactHint {
  const CompactHint({
    required this.primaryAction,
    required this.shortPrimaryAction,
    required this.route,
  });

  final String primaryAction;
  final String shortPrimaryAction;
  final HelpRoute route;

  String get text => '$primaryAction; ${route.text}';
  String get shortText => '$shortPrimaryAction; ${route.shortText}';
}

CompactHint compactHint({
  required PresentationMode mode,
  required ComponentRoute component,
  required String primaryAction,
  required String shortPrimaryAction,
}) => CompactHint(
  primaryAction: primaryAction,
  shortPrimaryAction: shortPrimaryAction,
  route: helpRoute(mode: mode, component: component),
);

/// Where a compact hint is placed in a presentation.
enum HintPlacement { richBottom, linearAfter, screenReaderBefore }

/// One composed prompt presentation.
///
/// [lines] is the sequential record a screen reader or a transcript consumer
/// sees. A rich presentation closes its active area with [footer]; a linear
/// one appends the same footer after its content; a screen-reader presentation
/// puts the essential text, including the help route, before the prompt.
final class PromptPresentation {
  const PromptPresentation({
    required this.mode,
    required this.placement,
    required this.prompt,
    required this.lines,
    this.essentialBefore,
    this.footer,
  });

  final PresentationMode mode;
  final HintPlacement placement;
  final String prompt;
  final String? essentialBefore;
  final String? footer;
  final List<String> lines;
}

PromptPresentation composePromptPresentation({
  required PresentationMode mode,
  required String prompt,
  required String essential,
  required CompactHint hint,
  InstructionVisibility instructions = InstructionVisibility.expanded,
  List<String> optionalLines = const [],
  List<String> decoration = const [],
  int? availableRows,
}) {
  if (mode == PresentationMode.screenReader) {
    final essentialLine = '$essential ${hint.text}';
    return PromptPresentation(
      mode: mode,
      placement: HintPlacement.screenReaderBefore,
      prompt: prompt,
      essentialBefore: essentialLine,
      lines: [essentialLine, prompt],
    );
  }
  final placement = mode == PresentationMode.rich
      ? HintPlacement.richBottom
      : HintPlacement.linearAfter;
  final optional = instructions == InstructionVisibility.expanded
      ? List<String>.of(optionalLines)
      : <String>[];
  final ornaments = List<String>.of(decoration);
  final compact = availableRows != null && availableRows <= 2;
  final footer = compact ? hint.shortText : hint.text;
  while (availableRows != null &&
      optional.length + ornaments.length + 2 > availableRows) {
    if (ornaments.isNotEmpty) {
      ornaments.removeLast();
    } else if (optional.isNotEmpty) {
      optional.removeLast();
    } else {
      break;
    }
  }
  return PromptPresentation(
    mode: mode,
    placement: placement,
    prompt: prompt,
    footer: footer,
    lines: [prompt, ...optional, ...ornaments, footer],
  );
}

/// A linear, reviewable record of one prompt and its answer.
List<String> sequentialTranscript(
  PromptPresentation presentation, {
  String? response,
}) => [...presentation.lines, ?response];

/// Noninteractive feedback presentation.
///
/// [hint] exists only for feedback that offers a real user action.
final class FeedbackPresentation {
  const FeedbackPresentation({required this.lines, this.hint});

  final List<String> lines;
  final String? hint;
}

FeedbackPresentation composeFeedbackPresentation({
  required List<String> lines,
  String? actionHint,
}) => FeedbackPresentation(
  lines: List<String>.unmodifiable(lines),
  hint: actionHint,
);

/// The immutable state detailed help must leave untouched.
final class HelpStateSnapshot {
  const HelpStateSnapshot({
    this.draft,
    this.caret,
    this.focusedReference,
    this.secret = false,
  });

  final String? draft;
  final int? caret;
  final int? focusedReference;
  final bool secret;

  String get displayDraft => switch (secret) {
    true => 'hidden',
    false => draft ?? '<empty>',
  };

  String get displayCaret => secret ? 'hidden' : '${caret ?? 0}';

  String get displayFocus =>
      focusedReference == null ? 'none' : '$focusedReference';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HelpStateSnapshot &&
          other.draft == draft &&
          other.caret == caret &&
          other.focusedReference == focusedReference &&
          other.secret == secret;

  @override
  int get hashCode => Object.hash(draft, caret, focusedReference, secret);
}

/// The component context detailed help describes.
final class HelpContext {
  const HelpContext({
    required this.component,
    required this.primaryAction,
    required this.route,
    this.draft,
    this.caret,
    this.focusedReference,
    this.secret = false,
    this.supplementary = const [],
  });

  final String component;
  final String primaryAction;
  final HelpRoute route;
  final String? draft;
  final int? caret;
  final int? focusedReference;
  final bool secret;
  final List<String> supplementary;

  HelpStateSnapshot get snapshot => HelpStateSnapshot(
    draft: draft,
    caret: caret,
    focusedReference: focusedReference,
    secret: secret,
  );
}

/// The result of a request for detailed help.
sealed class HelpOutcome {
  const HelpOutcome(this.state);

  final HelpStateSnapshot state;
}

final class HelpShown extends HelpOutcome {
  const HelpShown(this.text, super.state);

  final String text;
}

final class HelpUnavailable extends HelpOutcome {
  const HelpUnavailable(this.reason, super.state);

  final String reason;
}

final class HelpFailed extends HelpOutcome {
  const HelpFailed(this.reason, super.state);

  final String reason;
}

/// Opens detailed help without changing the draft, focus or caret.
HelpOutcome presentDetailedHelp({
  required HelpContext context,
  required bool spaceAvailable,
  String Function(HelpContext context)? render,
}) {
  final state = context.snapshot;
  if (!spaceAvailable) {
    return HelpUnavailable(
      'Help space is unavailable; the active prompt is unchanged.',
      state,
    );
  }
  try {
    return HelpShown((render ?? renderDetailedHelp)(context), state);
  } catch (error) {
    final detail = context.secret ? '' : ': $error';
    return HelpFailed(
      'Help could not be rendered$detail; the active prompt is unchanged.',
      state,
    );
  }
}

String renderDetailedHelp(HelpContext context) {
  final state = context.snapshot;
  return [
    'Help: ${context.component}. ${context.primaryAction}. '
        '${context.route.text} '
        'Draft: ${state.displayDraft}. Caret: ${state.displayCaret}. '
        'Focus: ${state.displayFocus}.',
    ...context.supplementary,
  ].join('\n');
}
