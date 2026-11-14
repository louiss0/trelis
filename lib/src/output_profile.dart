/// Declared capabilities, geometry, and display-width assumptions for one
/// selected output.
///
/// An [OutputProfile] describes output only. It neither acquires input nor owns
/// terminal state. Automatic values are resolved independently from an
/// invocation profile, a source profile, the legacy rich hint, and conservative
/// defaults.
enum CapabilitySupport { automatic, supported, unsupported }

/// The colour vocabulary that a selected output may support.
enum ColorDepth { automatic, none, ansi16, indexed256, rgb }

/// The glyph repertoire that a selected output may support.
enum GlyphSet { automatic, ascii, unicode }

/// The declared display-cell width for East Asian ambiguous characters.
enum AmbiguousWidth { automatic, narrow, wide }

/// The available dimensions for one selected output.
sealed class OutputGeometry {
  const OutputGeometry._();

  /// No usable geometry is declared or observed.
  const factory OutputGeometry.automatic() = _AutomaticOutputGeometry;

  /// A complete, positive output geometry declaration.
  factory OutputGeometry.fixed({required int columns, required int rows}) {
    if (columns <= 0) {
      throw ArgumentError.value(columns, 'columns', 'must be positive');
    }
    if (rows <= 0) {
      throw ArgumentError.value(rows, 'rows', 'must be positive');
    }
    return _FixedOutputGeometry(columns, rows);
  }

  /// Whether this geometry lacks usable dimensions.
  bool get isAutomatic;

  /// The declared column count, or null when [isAutomatic].
  int? get columns;

  /// The declared row count, or null when [isAutomatic].
  int? get rows;
}

final class _AutomaticOutputGeometry extends OutputGeometry {
  const _AutomaticOutputGeometry() : super._();

  @override
  bool get isAutomatic => true;

  @override
  int? get columns => null;

  @override
  int? get rows => null;
}

final class _FixedOutputGeometry extends OutputGeometry {
  const _FixedOutputGeometry(this.columns, this.rows) : super._();

  @override
  final int columns;

  @override
  final int rows;

  @override
  bool get isAutomatic => false;
}

/// Immutable output configuration for an invocation or scripted source.
final class OutputProfile {
  const OutputProfile({
    this.cursor = CapabilitySupport.automatic,
    this.alternateScreen = CapabilitySupport.automatic,
    this.styles = CapabilitySupport.automatic,
    this.colorDepth = ColorDepth.automatic,
    this.glyphs = GlyphSet.automatic,
    this.geometry = const OutputGeometry.automatic(),
    this.ambiguousWidth = AmbiguousWidth.automatic,
  });

  /// Cursor-addressing support.
  final CapabilitySupport cursor;

  /// Alternate-screen support.
  final CapabilitySupport alternateScreen;

  /// Supported monochrome SGR style support.
  final CapabilitySupport styles;

  /// Colour depth.
  final ColorDepth colorDepth;

  /// Glyph repertoire.
  final GlyphSet glyphs;

  /// Complete positive dimensions, or automatic/unknown.
  final OutputGeometry geometry;

  /// The display-cell treatment of ambiguous-width characters.
  final AmbiguousWidth ambiguousWidth;

  /// Resolves each field independently without treating a rich hint as proof
  /// of geometry, colour, glyph, style, or alternate-screen support.
  ///
  /// Invocation declarations have priority, followed by the source
  /// declaration, then the legacy [supportsRich] cursor hint. Remaining facts
  /// use conservative defaults. This value-level resolver has no authority to
  /// override a known real-stream restriction; native terminal code applies
  /// those restrictions before an invocation reaches a scripted source.
  factory OutputProfile.resolve({
    OutputProfile? invocation,
    OutputProfile? source,
    bool? supportsRich,
  }) {
    final requested = invocation ?? const OutputProfile();
    final declared = source ?? const OutputProfile();
    return OutputProfile(
      cursor: _resolveCapability(
        requested.cursor,
        declared.cursor,
        supportsRich == null
            ? CapabilitySupport.unsupported
            : (supportsRich
                  ? CapabilitySupport.supported
                  : CapabilitySupport.unsupported),
      ),
      alternateScreen: _resolveCapability(
        requested.alternateScreen,
        declared.alternateScreen,
        CapabilitySupport.unsupported,
      ),
      styles: _resolveCapability(
        requested.styles,
        declared.styles,
        CapabilitySupport.unsupported,
      ),
      colorDepth: _resolveColorDepth(requested.colorDepth, declared.colorDepth),
      glyphs: _resolveGlyphs(requested.glyphs, declared.glyphs),
      geometry: requested.geometry.isAutomatic
          ? declared.geometry
          : requested.geometry,
      ambiguousWidth: _resolveAmbiguousWidth(
        requested.ambiguousWidth,
        declared.ambiguousWidth,
      ),
    );
  }

  /// Replaces the named facts and preserves every other declared fact.
  ///
  /// Resolution, geometry observation and per-invocation restrictions each
  /// change one fact; a single-field copy forced every caller to reconstruct
  /// the complete profile by hand.
  OutputProfile copyWith({
    CapabilitySupport? cursor,
    CapabilitySupport? alternateScreen,
    CapabilitySupport? styles,
    ColorDepth? colorDepth,
    GlyphSet? glyphs,
    OutputGeometry? geometry,
    AmbiguousWidth? ambiguousWidth,
  }) => OutputProfile(
    cursor: cursor ?? this.cursor,
    alternateScreen: alternateScreen ?? this.alternateScreen,
    styles: styles ?? this.styles,
    colorDepth: colorDepth ?? this.colorDepth,
    glyphs: glyphs ?? this.glyphs,
    geometry: geometry ?? this.geometry,
    ambiguousWidth: ambiguousWidth ?? this.ambiguousWidth,
  );

  /// Whether the minimum safe facts for rich synthetic output are present.
  bool get supportsRichInteraction =>
      cursor == CapabilitySupport.supported && !geometry.isAutomatic;

  static CapabilitySupport _resolveCapability(
    CapabilitySupport invocation,
    CapabilitySupport source,
    CapabilitySupport fallback,
  ) => invocation != CapabilitySupport.automatic
      ? invocation
      : (source != CapabilitySupport.automatic ? source : fallback);

  static ColorDepth _resolveColorDepth(
    ColorDepth invocation,
    ColorDepth source,
  ) => invocation != ColorDepth.automatic
      ? invocation
      : (source != ColorDepth.automatic ? source : ColorDepth.none);

  static GlyphSet _resolveGlyphs(GlyphSet invocation, GlyphSet source) =>
      invocation != GlyphSet.automatic
      ? invocation
      : (source != GlyphSet.automatic ? source : GlyphSet.ascii);

  static AmbiguousWidth _resolveAmbiguousWidth(
    AmbiguousWidth invocation,
    AmbiguousWidth source,
  ) => invocation != AmbiguousWidth.automatic
      ? invocation
      : (source != AmbiguousWidth.automatic ? source : AmbiguousWidth.narrow);
}
