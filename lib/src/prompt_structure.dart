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

/// The number of display cells a structural prefix occupies.
///
/// Both the Unicode and the ASCII vocabulary spend two cells on every prefix,
/// so a wrapped line still fits the width it was measured against.
int structurePrefixCells(PromptStructure structure) =>
    usesStructurePrefix(structure) ? 2 : 0;

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
