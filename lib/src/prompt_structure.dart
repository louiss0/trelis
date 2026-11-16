import 'text_measurement.dart';

/// Declared visual grammar for a structural theme.
///
/// A structural theme decides how labels, body, hints and protected content
/// are arranged. It does not change a component's task behavior, accepted
/// values or interaction rules.
enum PromptStructure {
  /// Bare question, indented body and parenthesized compact hint.
  plain,

  /// Connected title/body spine; compact hint closes the rail.
  rail,

  /// Branching heading and continuing vertical context; compact hint closes
  /// the branch.
  branch,

  /// Square enclosure, title at top, body inside; hint outside below.
  box,

  /// Rounded enclosure with title/body inside; hint outside below.
  round,

  /// Double-rule enclosure, title/body inside; hint outside below.
  double,

  /// Unframed conversational label and body; bare hint below.
  minimal,

  /// Question-mark uppercase heading, indented body, -- hint below.
  ascii,

  /// Forward chevron heading, indented body, directional hint below.
  chevron,

  /// Bracketed question heading, indented body and hint; no full enclosing
  /// side/bottom frame.
  bracket,

  /// Fixed-label heading, rule and left-edged field body; hint below.
  form,

  /// Numbered ledger with dotted rule and indented body; note hint.
  ledger,

  /// ask: heading, indented body and hint: line.
  colon,

  /// Question followed by underline; indented body and hint.
  line,

  /// Strong label band, reverse-video where supported; indented body and hint
  /// below.
  block,
}

/// Drawing characters for a [PromptStructure] when Unicode box-drawing is
/// supported.
class StructureGlyphs {
  const StructureGlyphs({
    required this.start,
    required this.continueLine,
    required this.end,
  });

  /// Prefix for the first line of a structured block.
  final String start;

  /// Prefix for continuation lines inside a structured block.
  final String continueLine;

  /// Prefix for the last line that closes a structured block.
  final String end;
}

const _railGlyphs = StructureGlyphs(start: '│ ', continueLine: '│ ', end: '└ ');

const _branchGlyphs = StructureGlyphs(
  start: '├ ',
  continueLine: '│ ',
  end: '└ ',
);

const _asciiRailGlyphs = StructureGlyphs(
  start: '| ',
  continueLine: '| ',
  end: r'\ ',
);

const _asciiBranchGlyphs = StructureGlyphs(
  start: '+-',
  continueLine: '| ',
  end: r'\-',
);

/// Returns the glyph set for [structure], preferring Unicode when [ascii] is
/// false.
StructureGlyphs glyphsFor(PromptStructure structure, {required bool ascii}) {
  return switch (structure) {
    PromptStructure.rail => ascii ? _asciiRailGlyphs : _railGlyphs,
    PromptStructure.branch => ascii ? _asciiBranchGlyphs : _branchGlyphs,
    _ => const StructureGlyphs(start: '', continueLine: '', end: ''),
  };
}

/// Returns whether [structure] uses structural line prefixes.
bool usesStructurePrefix(PromptStructure structure) =>
    structure == PromptStructure.rail || structure == PromptStructure.branch;

/// Returns whether [structure] frames its content with an enclosure.
bool usesStructureEnclosure(PromptStructure structure) =>
    enclosureGlyphsFor(structure, ascii: false) != null;

/// Returns whether [structure] draws any frame, as a line prefix, as an
/// enclosure around the stage content, or as a decorated heading.
bool usesStructureFraming(PromptStructure structure) =>
    usesStructurePrefix(structure) ||
    usesStructureEnclosure(structure) ||
    usesStructureHeading(structure);

/// The number of display cells a structural prefix occupies.
///
/// Both the Unicode and the ASCII vocabulary spend two cells on every rail or
/// branch prefix, so a wrapped line still fits the width it was measured
/// against. An enclosure repeats its left rule outside the frame with the same
/// cells as that rule, so a live row outside the frame keeps the same
/// measurement as a prefixed one and lines up with the frame interior.
int structurePrefixCells(PromptStructure structure, {bool ascii = false}) {
  if (usesStructurePrefix(structure)) return 2;
  final heading = headingGlyphsFor(structure, ascii: ascii);
  if (heading != null) return heading.bodyIndentCells;
  final glyphs = enclosureGlyphsFor(structure, ascii: ascii);
  return glyphs?.livePrefixCells ?? 0;
}

/// The marker a framed structure repeats on a live row it does not enclose.
///
/// A rail or branch continues its spine; an enclosure repeats one side rule so
/// an editable row still reads as part of the stage without redrawing a frame
/// that a repaint would have to rewrite. A structure with no frame keeps the
/// reference cursor marker.
String structureLivePrefix(PromptStructure structure, {required bool ascii}) {
  if (usesStructurePrefix(structure)) {
    return glyphsFor(structure, ascii: ascii).continueLine;
  }
  final heading = headingGlyphsFor(structure, ascii: ascii);
  if (heading != null) return heading.bodyMarker;
  final glyphs = enclosureGlyphsFor(structure, ascii: ascii);
  if (glyphs != null) return glyphs.livePrefix;
  return '> ';
}

/// Applies structural prefixes to already-wrapped [lines].
///
/// [opens] gives the first non-empty line the structure's start glyph and
/// [closes] gives the last non-empty line its closing glyph; a block that does
/// neither is a continuation event inside the current structural line. When the
/// same single line both opens and closes, the start glyph wins, matching the
/// existing single-line stage grammar. Empty lines are kept but never receive a
/// prefix, preserving vertical breathing space.
List<String> frameStructureLines(
  PromptStructure structure, {
  required bool ascii,
  required List<String> lines,
  bool opens = true,
  bool closes = true,
}) {
  if (!usesStructurePrefix(structure) || lines.isEmpty) return lines;
  final glyphs = glyphsFor(structure, ascii: ascii);
  final first = lines.indexWhere((line) => line.isNotEmpty);
  if (first < 0) return lines;
  final last = lines.lastIndexWhere((line) => line.isNotEmpty);
  String prefixFor(int index) {
    if (index == first && opens) return glyphs.start;
    if (index == last && closes) return glyphs.end;
    return glyphs.continueLine;
  }

  return [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].isEmpty) '' else '${prefixFor(i)}${lines[i]}',
  ];
}

/// Drawing characters for a [PromptStructure] enclosure.
///
/// A box, rounded or double structure encloses the stage it renders: a top
/// rule, body rows bounded by the vertical rule, and a bottom rule. The compact
/// hint stays outside the frame.
class EnclosureGlyphs {
  const EnclosureGlyphs({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.horizontal,
    required this.vertical,
  });

  /// The upper-left corner of the top rule.
  final String topLeft;

  /// The upper-right corner of the top rule.
  final String topRight;

  /// The lower-left corner of the bottom rule.
  final String bottomLeft;

  /// The lower-right corner of the bottom rule.
  final String bottomRight;

  /// The rule character repeated along the top and bottom edges.
  final String horizontal;

  /// The side rule drawn before and after every body row.
  final String vertical;

  /// The display cells one side rule occupies.
  int get verticalCells => vertical.runes.length;

  /// The marker that repeats the frame's left side on a live row outside it.
  ///
  /// The marker is the whole side rule, so a live row's content starts in the
  /// same column as the body rows above it even when the side rule is drawn
  /// with two characters.
  String get livePrefix => '$vertical ';

  /// The display cells [livePrefix] occupies.
  int get livePrefixCells => verticalCells + 1;

  /// One horizontal run of [cells] display cells.
  String rule(int cells) =>
      cells <= 0 ? '' : List.filled(cells, horizontal).join();
}

const _boxEnclosure = EnclosureGlyphs(
  topLeft: '┌',
  topRight: '┐',
  bottomLeft: '└',
  bottomRight: '┘',
  horizontal: '─',
  vertical: '│',
);

const _roundEnclosure = EnclosureGlyphs(
  topLeft: '╭',
  topRight: '╮',
  bottomLeft: '╰',
  bottomRight: '╯',
  horizontal: '─',
  vertical: '│',
);

const _doubleEnclosure = EnclosureGlyphs(
  topLeft: '╔',
  topRight: '╗',
  bottomLeft: '╚',
  bottomRight: '╝',
  horizontal: '═',
  vertical: '║',
);

const _asciiBoxEnclosure = EnclosureGlyphs(
  topLeft: '+',
  topRight: '+',
  bottomLeft: '+',
  bottomRight: '+',
  horizontal: '-',
  vertical: '|',
);

const _asciiRoundEnclosure = EnclosureGlyphs(
  topLeft: '.',
  topRight: '.',
  bottomLeft: "'",
  bottomRight: "'",
  horizontal: '-',
  vertical: '|',
);

const _asciiDoubleEnclosure = EnclosureGlyphs(
  topLeft: '+',
  topRight: '+',
  bottomLeft: '+',
  bottomRight: '+',
  horizontal: '=',
  vertical: '||',
);

/// Returns the enclosure vocabulary for [structure], or null when [structure]
/// does not enclose its content.
///
/// The ASCII counterparts are the approved portable spellings: `+`, `-` and
/// `|` for a square frame, a dot and apostrophe corner with a hyphen rule for
/// the rounded one, and `=` rules with doubled vertical bars for the double
/// enclosure.
EnclosureGlyphs? enclosureGlyphsFor(
  PromptStructure structure, {
  required bool ascii,
}) {
  return switch (structure) {
    PromptStructure.box => ascii ? _asciiBoxEnclosure : _boxEnclosure,
    PromptStructure.round => ascii ? _asciiRoundEnclosure : _roundEnclosure,
    PromptStructure.double => ascii ? _asciiDoubleEnclosure : _doubleEnclosure,
    _ => null,
  };
}

/// The widest total width an enclosure may claim, in display cells.
///
/// Total width includes both side rules, the leading padding cell and the
/// trailing cell that lines the content up with the right rule, so this cap is
/// never an interior measurement.
const structureEnclosureWidthCap = 80;

/// The narrowest total frame width worth drawing.
///
/// Below this the chrome is simplified rather than the structure replaced: the
/// enclosure degrades to its left rule and the stage keeps its marker instead
/// of silently becoming an unframed component.
const structureEnclosureCompactWidth = 12;

/// The total display width [structure]'s enclosure claims for [width] columns.
///
/// The frame never exceeds [structureEnclosureWidthCap] and never exceeds the
/// columns the output actually offers. A missing measurement keeps the cap
/// itself, which is the widest the structure is allowed to be.
int enclosureTotalWidth(PromptStructure structure, int? width) =>
    (width ?? structureEnclosureWidthCap).clamp(1, structureEnclosureWidthCap);

/// The display width available to one body row of [structure]'s enclosure.
///
/// Both side rules, the leading padding cell and the cell that lines the
/// content up with the right rule are part of [width], so this is what is left
/// for the content itself.
int enclosureContentWidth(
  PromptStructure structure, {
  required bool ascii,
  required int width,
}) {
  final glyphs = enclosureGlyphsFor(structure, ascii: ascii);
  if (glyphs == null) return width;
  final total = enclosureTotalWidth(structure, width);
  return (total - 2 * glyphs.verticalCells - 1).clamp(1, total);
}

/// Composes the top rule of [structure]'s enclosure.
///
/// [title] is embedded between corner and rule when it fits; otherwise the rule
/// is plain and the caller keeps the title as a body row. Either way the result
/// is exactly [width] display cells wide.
String enclosureTopRule(
  PromptStructure structure, {
  required bool ascii,
  String? title,
  required int width,
}) {
  final glyphs = enclosureGlyphsFor(structure, ascii: ascii);
  if (glyphs == null) return title ?? '';
  final total = enclosureTotalWidth(structure, width);
  final interior = (total - 2).clamp(0, total);
  final titleCells = title == null ? 0 : TextDisplayMap(title).cellWidth;
  if (title == null || title.isEmpty || titleCells + 4 > total) {
    return '${glyphs.topLeft}${glyphs.rule(interior)}${glyphs.topRight}';
  }
  return '${glyphs.topLeft} $title '
      '${glyphs.rule(interior - titleCells - 2)}${glyphs.topRight}';
}

/// Composes one body row of [structure]'s enclosure.
///
/// [line] is already wrapped and display-safe; it is padded to the frame's
/// content field so the right rule lines up on every row. A row wider than the
/// frame is kept whole rather than truncated, because the caller measured it
/// against the same width.
String enclosureBodyRow(
  PromptStructure structure, {
  required bool ascii,
  required String line,
  required int width,
}) {
  final glyphs = enclosureGlyphsFor(structure, ascii: ascii);
  if (glyphs == null) return line;
  final total = enclosureTotalWidth(structure, width);
  final field = (total - 2 * glyphs.verticalCells - 1).clamp(0, total);
  final used = TextDisplayMap(line).cellWidth;
  final padded = used >= field ? line : '$line${' ' * (field - used)}';
  return '${glyphs.vertical} $padded${glyphs.vertical}';
}

/// Composes the bottom rule of [structure]'s enclosure.
String enclosureBottomRule(
  PromptStructure structure, {
  required bool ascii,
  required int width,
}) {
  final glyphs = enclosureGlyphsFor(structure, ascii: ascii);
  if (glyphs == null) return '';
  final total = enclosureTotalWidth(structure, width);
  return '${glyphs.bottomLeft}'
      '${glyphs.rule((total - 2).clamp(0, total))}'
      '${glyphs.bottomRight}';
}

/// Composes one complete enclosure as display lines.
///
/// [body] lines are already wrapped and display-safe. This is the composition
/// a single staged block uses; a component that emits several blocks composes
/// the same pieces in order so one frame spans them all.
List<String> frameEnclosureLines(
  PromptStructure structure, {
  required bool ascii,
  required List<String> body,
  String? title,
  required int width,
}) {
  final glyphs = enclosureGlyphsFor(structure, ascii: ascii);
  if (glyphs == null) return body;
  final total = enclosureTotalWidth(structure, width);
  final titleCells = title == null ? 0 : TextDisplayMap(title).cellWidth;
  final titled = title != null && title.isNotEmpty && titleCells + 4 <= total;
  return [
    enclosureTopRule(
      structure,
      ascii: ascii,
      title: titled ? title : null,
      width: total,
    ),
    if (titled && body.isEmpty)
      enclosureBodyRow(structure, ascii: ascii, line: '', width: total),
    for (final line in body)
      enclosureBodyRow(structure, ascii: ascii, line: line, width: total),
    enclosureBottomRule(structure, ascii: ascii, width: total),
  ];
}

/// The kind of stage line a component writes through the structure spine.
///
/// A structure that declares typed event prefixes spells them before the line
/// it already composed: the label is a display label only, so the semantic
/// content after it stays exactly as the component wrote it. No typed prefix is
/// ever a parser command or a component identity.
enum StageEvent {
  /// Read-only stage content: guidance, descriptions, choice rows, editable
  /// rows.
  body,

  /// A state or context row, such as a live draft or a retained default.
  state,

  /// A validation, warning or refusal notice.
  warning,

  /// A reported outcome: accepted, cancelled, interrupted or input ended.
  result,
}

/// Drawing characters for a [PromptStructure] heading grammar.
///
/// A heading structure decorates the stage heading, indents the body rows that
/// follow it and marks the compact hint, instead of drawing a line prefix or an
/// enclosure. The seven heading/decorated grammars are deliberately different
/// arrangements, not colour variants of one layout: a conversational label, a
/// question-mark console heading, a forward chevron, a bracketed band, a
/// fixed-label form with a rule and a left edge, a numbered ledger with a dotted
/// rule, and a key:value diagnostic with typed prefixes.
class HeadingGlyphs {
  const HeadingGlyphs({
    required this.headingPrefix,
    required this.headingSuffix,
    required this.bodyIndent,
    required this.hintPrefix,
    required this.bodyMarker,
    this.uppercaseHeading = false,
    this.ruleGlyph = '',
    this.hintIndent,
    this.headingIndent,
    this.numbered = false,
    this.eventPrefixes = const <StageEvent, String>{},
  });

  /// The decoration before the heading text.
  final String headingPrefix;

  /// The decoration after the heading text.
  final String headingSuffix;

  /// The indent before every body row of the stage.
  final String bodyIndent;

  /// The marker before the compact hint, which sits under the body rows.
  final String hintPrefix;

  /// The marker a live, editable row repeats so it reads as part of the stage.
  ///
  /// This is the structure's atlas body marker rather than a frame rule, so an
  /// editable row is recognisably the same grammar as the stage above it even
  /// though nothing encloses it.
  final String bodyMarker;

  /// Whether the heading text alone is spelled in capitals.
  ///
  /// The console and form grammars declare this, and it applies to the heading
  /// the component owns. Body rows, answer data, literal commands and stable
  /// choice references are never case-transformed.
  final bool uppercaseHeading;

  /// The character a stage rule is drawn with under the heading, or an empty
  /// string when the grammar draws no rule.
  ///
  /// The rule is composed from the width the stage actually has, capped at
  /// [structureRuleWidthCap], so a specimen's rule length never becomes an
  /// alignment requirement the output cannot meet.
  final String ruleGlyph;

  /// The lead before the compact hint when the grammar does not hang it under
  /// the body indent, or null to reuse [bodyIndent].
  ///
  /// The diagnostic grammar writes its hint at the reference column so the
  /// `hint:` label lines up with the other typed labels.
  final String? hintIndent;

  /// The indent a wrapped heading continuation takes, or null to reuse
  /// [bodyIndent].
  ///
  /// The form heading is a fixed label, not a field row, so its continuation
  /// lines are indented like guidance instead of repeating the field's left
  /// edge. A grammar that leaves this unset keeps the body indent it always
  /// used.
  final String? headingIndent;

  /// Whether each stage heading carries a prompt-local stage number.
  ///
  /// Numbering is display sequencing only: it is allocated per invocation by
  /// the stage writer, never by this vocabulary and never by a global counter.
  final bool numbered;

  /// The typed labels this grammar puts before a non-body [StageEvent].
  ///
  /// An empty map is the conversational grammar: events keep the body rows
  /// they always had, and no other structure's bytes change.
  final Map<StageEvent, String> eventPrefixes;

  /// The display cells [headingPrefix] occupies.
  int get headingPrefixCells => TextDisplayMap(headingPrefix).cellWidth;

  /// The display cells [headingSuffix] occupies.
  int get headingSuffixCells => TextDisplayMap(headingSuffix).cellWidth;

  /// The display cells [bodyIndent] occupies.
  int get bodyIndentCells => TextDisplayMap(bodyIndent).cellWidth;

  /// The display cells [hintPrefix] occupies.
  int get hintPrefixCells => TextDisplayMap(hintPrefix).cellWidth;

  /// The lead before the compact hint: [hintIndent], or [bodyIndent] when the
  /// grammar does not declare one, followed by [hintPrefix].
  String get hintLead => '${hintIndent ?? bodyIndent}$hintPrefix';

  /// The display cells [hintLead] occupies.
  int get hintLeadCells => TextDisplayMap(hintLead).cellWidth;

  /// The indent a wrapped heading continuation line takes.
  String get headingContinuation => headingIndent ?? bodyIndent;

  /// Whether this grammar draws a rule under its heading.
  bool get drawsRule => ruleGlyph.isNotEmpty;

  /// One rule run of [cells] display cells, or an empty string when this
  /// grammar draws no rule.
  String rule(int cells) => cells <= 0 || ruleGlyph.isEmpty
      ? ''
      : List.filled(cells, ruleGlyph).join();

  /// The typed label for [event], or null when this grammar leaves that event
  /// as a body row.
  String? eventPrefix(StageEvent event) => eventPrefixes[event];

  /// The display label of stage number [number]: two digits, then ` / `.
  String stageNumberLabel(int number) =>
      '${number.toString().padLeft(2, '0')} / ';

  /// The heading [text] spelled with stage number [number].
  String numberedHeading(int number, String text) =>
      '${stageNumberLabel(number)}${spelling(text)}';

  /// The display cells the whole heading decoration spends on its first line.
  int get headingCells => headingPrefixCells + headingSuffixCells;

  /// The heading spelled for this grammar: decoration is applied by
  /// [frameHeadingLines], so this is the text the decoration wraps.
  String spelling(String text) => uppercaseHeading ? text.toUpperCase() : text;

  /// The opening marker of the narrow spelling.
  String get compactPrefix => headingPrefix.trimRight();

  /// The display cells [compactPrefix] occupies.
  int get compactPrefixCells => TextDisplayMap(compactPrefix).cellWidth;

  /// One body row of this grammar, indented under the heading.
  String body(String line) => '$bodyIndent$line';
}

const _minimalHeading = HeadingGlyphs(
  headingPrefix: '',
  headingSuffix: '',
  bodyIndent: '',
  hintPrefix: '',
  bodyMarker: '› ',
);

const _asciiMinimalHeading = HeadingGlyphs(
  headingPrefix: '',
  headingSuffix: '',
  bodyIndent: '',
  hintPrefix: '',
  bodyMarker: '> ',
);

/// The console grammar is ASCII in every capability profile: it declares no
/// Unicode counterpart at all, so no output profile can change its spelling.
const _asciiConsoleHeading = HeadingGlyphs(
  headingPrefix: '? ',
  headingSuffix: '',
  bodyIndent: '  ',
  hintPrefix: '-- ',
  bodyMarker: '> ',
  uppercaseHeading: true,
);

const _chevronHeading = HeadingGlyphs(
  headingPrefix: '❯ ',
  headingSuffix: '',
  bodyIndent: '  ',
  hintPrefix: '↳ ',
  bodyMarker: '❯ ',
);

const _asciiChevronHeading = HeadingGlyphs(
  headingPrefix: '> ',
  headingSuffix: '',
  bodyIndent: '  ',
  hintPrefix: '-> ',
  bodyMarker: '> ',
);

const _bracketHeading = HeadingGlyphs(
  headingPrefix: '[ ',
  headingSuffix: ' ]',
  bodyIndent: '  ',
  hintPrefix: '',
  bodyMarker: '» ',
);

const _asciiBracketHeading = HeadingGlyphs(
  headingPrefix: '[ ',
  headingSuffix: ' ]',
  bodyIndent: '  ',
  hintPrefix: '',
  bodyMarker: '> ',
);

/// The form grammar draws a rule under an uppercase fixed label and repeats a
/// left edge down the body rows the label owns. The hint sits below the edged
/// field, indented like the rule rather than edged like the field.
const _formHeading = HeadingGlyphs(
  headingPrefix: '',
  headingSuffix: '',
  bodyIndent: '│ ',
  hintPrefix: '',
  hintIndent: '  ',
  headingIndent: '  ',
  bodyMarker: '│ ',
  uppercaseHeading: true,
  ruleGlyph: '─',
);

const _asciiFormHeading = HeadingGlyphs(
  headingPrefix: '',
  headingSuffix: '',
  bodyIndent: '| ',
  hintPrefix: '',
  hintIndent: '  ',
  headingIndent: '  ',
  bodyMarker: '| ',
  uppercaseHeading: true,
  ruleGlyph: '-',
);

/// The ledger grammar numbers the task stage, rules it with a dotted line,
/// indents the body rows and closes the stage with a `note:` line.
const _ledgerHeading = HeadingGlyphs(
  headingPrefix: '',
  headingSuffix: '',
  bodyIndent: '   ',
  hintPrefix: 'note: ',
  bodyMarker: '   > ',
  numbered: true,
  ruleGlyph: '·',
);

const _asciiLedgerHeading = HeadingGlyphs(
  headingPrefix: '',
  headingSuffix: '',
  bodyIndent: '   ',
  hintPrefix: 'note: ',
  bodyMarker: '   > ',
  numbered: true,
  ruleGlyph: '.',
);

/// The diagnostic grammar is ASCII in every capability profile: `ask:`, `hint:`
/// and the typed event labels are the structure, so no output profile changes
/// its spelling. Its labels sit at the reference column and its content is
/// indented under them, exactly as a key:value diagnostic record reads.
const _colonHeading = HeadingGlyphs(
  headingPrefix: 'ask:',
  headingSuffix: '',
  bodyIndent: '  ',
  hintPrefix: 'hint:',
  hintIndent: '',
  bodyMarker: '  :: ',
  eventPrefixes: {
    StageEvent.state: 'state:',
    StageEvent.warning: 'warning:',
    StageEvent.result: 'result:',
  },
);

/// Returns whether [structure] decorates its heading instead of drawing a line
/// prefix or an enclosure.
bool usesStructureHeading(PromptStructure structure) => switch (structure) {
  PromptStructure.minimal ||
  PromptStructure.ascii ||
  PromptStructure.chevron ||
  PromptStructure.bracket ||
  PromptStructure.form ||
  PromptStructure.ledger ||
  PromptStructure.colon => true,
  _ => false,
};

/// Returns the heading vocabulary for [structure], or null when [structure]
/// draws a line prefix or an enclosure instead.
///
/// The console grammar ([PromptStructure.ascii]) and the diagnostic grammar
/// ([PromptStructure.colon]) have one spelling only: they are always the
/// portable ASCII vocabulary, whatever the output profile supports. The other
/// five use their declared vocabulary when glyph support is known and fall back
/// to their ASCII counterpart when it is not, exactly as the rail, branch and
/// enclosure grammars do.
HeadingGlyphs? headingGlyphsFor(
  PromptStructure structure, {
  required bool ascii,
}) {
  return switch (structure) {
    PromptStructure.minimal => ascii ? _asciiMinimalHeading : _minimalHeading,
    PromptStructure.ascii => _asciiConsoleHeading,
    PromptStructure.chevron => ascii ? _asciiChevronHeading : _chevronHeading,
    PromptStructure.bracket => ascii ? _asciiBracketHeading : _bracketHeading,
    PromptStructure.form => ascii ? _asciiFormHeading : _formHeading,
    PromptStructure.ledger => ascii ? _asciiLedgerHeading : _ledgerHeading,
    PromptStructure.colon => _colonHeading,
    _ => null,
  };
}

/// The widest a stage rule may be drawn, in display cells.
///
/// The rule is chrome, so it is bounded by the same total-width cap an enclosure
/// uses and by the columns the output actually offers. It is never a specimen's
/// rule length.
const structureRuleWidthCap = 80;

/// The display cells [structure]'s rule occupies for [width] columns.
int structureRuleWidth(PromptStructure structure, int? width) =>
    (width ?? structureRuleWidthCap).clamp(1, structureRuleWidthCap);

/// The display label of stage number [number] for [structure], or an empty
/// string when [structure] does not number its stages.
String structureStageNumberLabel(
  PromptStructure structure,
  int number, {
  bool ascii = false,
}) {
  final glyphs = headingGlyphsFor(structure, ascii: ascii);
  if (glyphs == null || !glyphs.numbered) return '';
  return glyphs.stageNumberLabel(number);
}

/// The heading [text] with stage number [number], as [structure] spells it.
///
/// The number is display sequencing supplied by the invocation that writes the
/// stage. This helper only spells it, so numbering stays a per-invocation fact
/// rather than a property of the vocabulary or of a global counter.
String structureStageHeading(
  PromptStructure structure,
  int number,
  String text, {
  bool ascii = false,
}) {
  final glyphs = headingGlyphsFor(structure, ascii: ascii);
  if (glyphs == null || !glyphs.numbered) {
    return structureHeadingText(structure, text, ascii: ascii);
  }
  return glyphs.numberedHeading(number, text);
}

/// The typed label [structure] puts before an event of [event], or null when
/// the grammar leaves that event as a body row.
String? structureEventPrefix(
  PromptStructure structure,
  StageEvent event, {
  bool ascii = false,
}) => headingGlyphsFor(structure, ascii: ascii)?.eventPrefix(event);

/// The heading spelling of [text] for [structure].
///
/// Only the structure's declared casing rule applies, and it applies to the
/// heading the component owns: no component passes answer data, a literal
/// command, an example, an identifier or a stable choice reference here.
String structureHeadingText(
  PromptStructure structure,
  String text, {
  bool ascii = false,
}) => headingGlyphsFor(structure, ascii: ascii)?.spelling(text) ?? text;

/// Applies [structure]'s heading decoration to already-wrapped [lines].
///
/// The first line carries the heading prefix, the last carries the heading
/// suffix, and wrapped continuation lines take the grammar's continuation
/// indent so a wrapped heading still reads as one block. [compact] selects the
/// narrow spelling: the decoration is simplified to its marker instead of the
/// structure being replaced by an unframed one. A structure with no heading
/// grammar returns [lines] unchanged.
List<String> frameHeadingLines(
  PromptStructure structure, {
  required bool ascii,
  required List<String> lines,
  bool compact = false,
}) {
  final glyphs = headingGlyphsFor(structure, ascii: ascii);
  if (glyphs == null || lines.isEmpty) return lines;
  final first = lines.indexWhere((line) => line.isNotEmpty);
  if (first < 0) return lines;
  final last = lines.lastIndexWhere((line) => line.isNotEmpty);
  final prefix = compact ? glyphs.compactPrefix : glyphs.headingPrefix;
  final suffix = compact ? '' : glyphs.headingSuffix;
  return [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].isEmpty)
        ''
      else
        '${i == first ? prefix : glyphs.headingContinuation}${lines[i]}'
            '${i == last ? suffix : ''}',
  ];
}
