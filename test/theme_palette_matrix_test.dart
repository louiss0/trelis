import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

/// Independent verification of the 45 named colour palettes.
///
/// The expected values are not copied from the generated Dart file. This
/// fixture reads the source atlas (`example/prototype-themes/generate.py`, the
/// throwaway visual study the palettes were derived from), parses its declared
/// colours, and asserts that every named `ColorThemes` preset maps the atlas
/// roles the atlas and the specification say it maps: text to foreground,
/// terminal surface to background, the page colour excluded, the selection pair,
/// the success/error roles, the rule as the border and the documented accent
/// fallback for warnings.
///
/// Conversion, the no-colour policy, custom palettes, immutability and palette
/// overrides across structurally different layouts are verified here as palette
/// facts, independently of any one component's interaction.

/// The source atlas, relative to the package root the test runner uses.
const _atlasPath = 'example/prototype-themes/generate.py';

/// The atlas tuple order: page, terminal, text, muted, accent, selected
/// foreground, success, error, rule.
const _pageIndex = 0;
const _terminalIndex = 1;
const _textIndex = 2;
const _mutedIndex = 3;
const _accentIndex = 4;
const _selectedIndex = 5;
const _successIndex = 6;
const _errorIndex = 7;
const _ruleIndex = 8;

/// The nine colours every atlas record declares.
const _atlasColourCount = 9;

/// The number of named presets the specification requires.
const _namedPaletteCount = 45;

/// The 45 named presets, keyed by their atlas slug.
final _palettes = <String, ColorTheme>{
  'signal': ColorThemes.signal,
  'paper': ColorThemes.paper,
  'mainframe': ColorThemes.mainframe,
  'blueprint': ColorThemes.blueprint,
  'ember': ColorThemes.ember,
  'orchid': ColorThemes.orchid,
  'workbench': ColorThemes.workbench,
  'tide': ColorThemes.tide,
  'ink': ColorThemes.ink,
  'arcade': ColorThemes.arcade,
  'fieldnotes': ColorThemes.fieldnotes,
  'nordic': ColorThemes.nordic,
  'punch': ColorThemes.punch,
  'ledger': ColorThemes.ledger,
  'infrared': ColorThemes.infrared,
  'porcelain': ColorThemes.porcelain,
  'basalt': ColorThemes.basalt,
  'citrus': ColorThemes.citrus,
  'lavender': ColorThemes.lavender,
  'glacier': ColorThemes.glacier,
  'vinyl': ColorThemes.vinyl,
  'botanical': ColorThemes.botanical,
  'terminal-amber': ColorThemes.terminalAmber,
  'slate': ColorThemes.slate,
  'solar': ColorThemes.solar,
  'deep-space': ColorThemes.deepSpace,
  'moss': ColorThemes.moss,
  'copper': ColorThemes.copper,
  'midnight-mint': ColorThemes.midnightMint,
  'typewriter': ColorThemes.typewriter,
  'neon-grid': ColorThemes.neonGrid,
  'sandstone': ColorThemes.sandstone,
  'blue-hour': ColorThemes.blueHour,
  'matcha': ColorThemes.matcha,
  'obsidian': ColorThemes.obsidian,
  'clay': ColorThemes.clay,
  'polar': ColorThemes.polar,
  'forest-floor': ColorThemes.forestFloor,
  'ultraviolet': ColorThemes.ultraviolet,
  'sea-glass': ColorThemes.seaGlass,
  'carbon': ColorThemes.carbon,
  'sakura': ColorThemes.sakura,
  'terminal-green': ColorThemes.terminalGreen,
  'desert-dusk': ColorThemes.desertDusk,
  'ion': ColorThemes.ion,
};

/// One record of the source atlas.
final class _AtlasPalette {
  const _AtlasPalette(this.name, this.slug, this.colours);

  final String name;
  final String slug;

  /// The nine declared colours, in atlas order.
  final List<String> colours;

  String colour(int index) => colours[index];

  TerminalColor rgb(int index) => _terminalColor(colours[index]);
}

TerminalColor _terminalColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return TerminalColor.rgb(
    int.parse(value.substring(0, 2), radix: 16),
    int.parse(value.substring(2, 4), radix: 16),
    int.parse(value.substring(4, 6), radix: 16),
  );
}

/// Every atlas record, parsed from the source file rather than the generated
/// Dart, so the mapping is checked against its origin.
List<_AtlasPalette> _readAtlas() {
  final source = File(_atlasPath).readAsStringSync();
  final entry = RegExp(
    r"\('([^']+)', '([a-z0-9-]+)', '[a-z]+', '[^']*',\s*\[([^\]]*)\]\)",
  );
  final colour = RegExp(r'#[0-9a-fA-F]{6}');
  return [
    for (final match in entry.allMatches(source))
      _AtlasPalette(match.group(1)!, match.group(2)!, [
        for (final found in colour.allMatches(match.group(3)!))
          found.group(0)!.toLowerCase(),
      ]),
  ];
}

/// Every semantic role of a palette, so a role is never dropped silently.
List<TerminalColor> _roles(ColorTheme palette) => [
  palette.foreground,
  palette.background,
  palette.muted,
  palette.accent,
  palette.selectionForeground,
  palette.selectionBackground,
  palette.success,
  palette.warning,
  palette.error,
  palette.border,
];

OutputProfile _profile({int columns = 72, bool rgb = true}) => OutputProfile(
  cursor: CapabilitySupport.supported,
  colorDepth: rgb ? ColorDepth.rgb : ColorDepth.none,
  geometry: OutputGeometry.fixed(columns: columns, rows: 20),
  glyphs: GlyphSet.unicode,
);

Future<String> _render(
  String label,
  ColorTheme colors, {
  PromptStructure structure = PromptStructure.plain,
}) async {
  final out = StringBuffer();
  final result = await TextInput(label, structure: structure, colors: colors)
      .prompt(
        source: ScriptedInput(
          Stream.value('Ada\r'),
          out,
          outputProfile: _profile(),
        ),
        mode: PromptMode.rich,
      );
  expect((result as Accepted<String>).value, 'Ada');
  return out.toString();
}

void main() {
  final atlas = _readAtlas();
  final bySlug = {for (final palette in atlas) palette.slug: palette};

  group('the source atlas', () {
    test('declares the 45 named palettes the library exposes', () {
      expect(atlas, hasLength(_namedPaletteCount));
      expect(_palettes, hasLength(_namedPaletteCount));
      expect(bySlug.keys.toSet(), _palettes.keys.toSet());
      for (final palette in atlas) {
        expect(
          palette.colours,
          hasLength(_atlasColourCount),
          reason: '${palette.slug} declares ${palette.colours.length} colours',
        );
        for (final hex in palette.colours) {
          expect(hex, matches(RegExp(r'^#[0-9a-f]{6}$')));
        }
      }
    });
  });

  group('named palette mapping', () {
    for (final entry in _palettes.entries) {
      final slug = entry.key;
      final palette = entry.value;

      test('$slug maps every atlas role and excludes its page colour', () {
        final source = bySlug[slug]!;
        expect(palette.foreground, source.rgb(_textIndex));
        expect(palette.background, source.rgb(_terminalIndex));
        expect(palette.muted, source.rgb(_mutedIndex));
        expect(palette.accent, source.rgb(_accentIndex));
        expect(palette.selectionForeground, source.rgb(_selectedIndex));
        expect(palette.selectionBackground, palette.accent);
        expect(palette.success, source.rgb(_successIndex));
        expect(
          palette.warning,
          palette.accent,
          reason: 'the documented warning fallback is the accent role',
        );
        expect(palette.error, source.rgb(_errorIndex));
        expect(palette.border, source.rgb(_ruleIndex));

        // The atlas page colour is artwork, not a surface: the runtime
        // background is the declared terminal surface.
        if (source.colour(_pageIndex) != source.colour(_terminalIndex)) {
          expect(
            palette.background,
            isNot(source.rgb(_pageIndex)),
            reason: 'the page colour must not become the background',
          );
        }

        // Ten roles, all declared, none left terminal-native: a preset is a
        // complete palette rather than a partial override.
        expect(_roles(palette), hasLength(10));
        for (final role in _roles(palette)) {
          expect(isTerminalDefault(role), isFalse, reason: '$slug role');
        }
      });
    }
  });

  group('terminal-native defaults', () {
    test('the default palette forces no surface and no colour', () {
      for (final role in _roles(ColorThemes.terminalDefault)) {
        expect(isTerminalDefault(role), isTrue);
      }
      expect(
        terminalStyledText(
          'x',
          foreground: ColorThemes.terminalDefault.foreground,
          background: ColorThemes.terminalDefault.background,
          depth: ColorDepth.rgb,
        ),
        'x',
        reason: 'a terminal-native palette must not style anything',
      );
    });

    test('light and dark presets both keep their own declared surface', () {
      // No global dark/light mode: a preset names its surface and the terminal
      // keeps the one it has.
      final light = ColorThemes.paper;
      final dark = ColorThemes.signal;
      expect(light.background, TerminalColor.rgb(250, 249, 245));
      expect(dark.background, TerminalColor.rgb(25, 27, 40));
      expect(light.foreground, isNot(light.background));
      expect(dark.foreground, isNot(dark.background));
    });
  });

  group('conversion and no-colour policy', () {
    test('an atlas colour converts at every declared depth', () {
      final accent = ColorThemes.signal.accent;
      expect(
        terminalSgr(accent, background: false, depth: ColorDepth.rgb),
        '38;2;182;162;255',
      );
      expect(
        terminalSgr(accent, background: true, depth: ColorDepth.rgb),
        '48;2;182;162;255',
      );
      for (final depth in [ColorDepth.indexed256, ColorDepth.ansi16]) {
        expect(
          terminalSgr(accent, background: false, depth: depth),
          matches(RegExp(r'^(38;5;\d+|3[0-7])$')),
        );
      }
      expect(
        terminalSgr(accent, background: false, depth: ColorDepth.none),
        '39',
      );
      expect(
        terminalSgr(accent, background: true, depth: ColorDepth.none),
        '49',
      );
      expect(
        terminalSgr(accent, background: false, depth: ColorDepth.automatic),
        '39',
      );
    });

    test('every palette converts at every depth without modifying output', () {
      for (final entry in _palettes.entries) {
        for (final role in _roles(entry.value)) {
          for (final depth in ColorDepth.values) {
            expect(
              terminalSgr(role, background: false, depth: depth),
              isNotEmpty,
              reason: '${entry.key} at ${depth.name}',
            );
          }
        }
        expect(
          terminalStyledText(
            'x',
            foreground: entry.value.foreground,
            background: entry.value.background,
            depth: ColorDepth.none,
          ),
          'x',
          reason: '${entry.key} must not style output a depth cannot show',
        );
      }
    });
  });

  group('custom palettes and immutability', () {
    test('copyWith is immutable and never mutates a preset', () {
      final before = ColorThemes.signal;
      final patched = before.copyWith(
        warning: TerminalColor.rgb(255, 190, 80),
        foreground: TerminalColor.rgb(1, 2, 3),
      );
      expect(patched.warning, TerminalColor.rgb(255, 190, 80));
      expect(patched.foreground, TerminalColor.rgb(1, 2, 3));
      expect(patched.accent, before.accent);
      expect(before.warning, before.accent);
      expect(before.foreground, TerminalColor.rgb(230, 232, 244));
      expect(ColorThemes.signal, same(before));
    });

    test('a whole custom palette replaces all ten roles', () {
      final custom = ColorTheme(
        foreground: TerminalColor.rgb(1, 2, 3),
        background: TerminalColor.rgb(4, 5, 6),
        muted: TerminalColor.rgb(7, 8, 9),
        accent: TerminalColor.rgb(10, 11, 12),
        selectionForeground: TerminalColor.rgb(13, 14, 15),
        selectionBackground: TerminalColor.rgb(16, 17, 18),
        success: TerminalColor.rgb(19, 20, 21),
        warning: TerminalColor.rgb(22, 23, 24),
        error: TerminalColor.rgb(25, 26, 27),
        border: TerminalColor.rgb(28, 29, 30),
      );
      expect(_roles(custom), hasLength(10));
      expect(isTerminalDefault(custom.accent), isFalse);
      expect(
        custom.copyWith(border: TerminalColor.rgb(0, 0, 0)).foreground,
        custom.foreground,
      );
    });
  });

  group('an alternate palette across structurally different layouts', () {
    const structures = [
      PromptStructure.rail,
      PromptStructure.box,
      PromptStructure.ledger,
      PromptStructure.block,
    ];

    for (final structure in structures) {
      test('${structure.name} styles its stage from the palette', () async {
        final palette = ColorThemes.signal.copyWith(
          foreground: TerminalColor.rgb(12, 34, 56),
        );
        final text = await _render('Name', palette, structure: structure);
        expect(text, contains('\x1b[38;2;12;34;56;'));
      });
    }

    test('a per-component override does not leak to its neighbour', () async {
      final overridden = ColorThemes.signal.copyWith(
        foreground: TerminalColor.rgb(12, 34, 56),
      );
      final neighbour = ColorThemes.paper.copyWith(
        foreground: TerminalColor.rgb(90, 80, 70),
      );
      final first = await _render('First', overridden);
      final second = await _render('Second', neighbour);
      expect(first, contains('\x1b[38;2;12;34;56;'));
      expect(first, isNot(contains('\x1b[38;2;90;80;70;')));
      expect(second, contains('\x1b[38;2;90;80;70;'));
      expect(second, isNot(contains('\x1b[38;2;12;34;56;')));
      // The presets themselves are unchanged by the overrides.
      expect(ColorThemes.signal.foreground, TerminalColor.rgb(230, 232, 244));
      expect(ColorThemes.paper.foreground, TerminalColor.rgb(40, 45, 50));
    });
  });
}
