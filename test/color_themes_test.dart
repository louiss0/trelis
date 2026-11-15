import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  group('ColorThemes named palettes', () {
    test('exposes terminalDefault and all 45 named palettes', () {
      const names = <String>[
        'terminalDefault',
        'signal',
        'paper',
        'mainframe',
        'blueprint',
        'ember',
        'orchid',
        'workbench',
        'tide',
        'ink',
        'arcade',
        'fieldnotes',
        'nordic',
        'punch',
        'ledger',
        'infrared',
        'porcelain',
        'basalt',
        'citrus',
        'lavender',
        'glacier',
        'vinyl',
        'botanical',
        'terminalAmber',
        'slate',
        'solar',
        'deepSpace',
        'moss',
        'copper',
        'midnightMint',
        'typewriter',
        'neonGrid',
        'sandstone',
        'blueHour',
        'matcha',
        'obsidian',
        'clay',
        'polar',
        'forestFloor',
        'ultraviolet',
        'seaGlass',
        'carbon',
        'sakura',
        'terminalGreen',
        'desertDusk',
        'ion',
      ];
      for (final name in names) {
        final palette = switch (name) {
          'terminalDefault' => ColorThemes.terminalDefault,
          'signal' => ColorThemes.signal,
          'paper' => ColorThemes.paper,
          'mainframe' => ColorThemes.mainframe,
          'blueprint' => ColorThemes.blueprint,
          'ember' => ColorThemes.ember,
          'orchid' => ColorThemes.orchid,
          'workbench' => ColorThemes.workbench,
          'tide' => ColorThemes.tide,
          'ink' => ColorThemes.ink,
          'arcade' => ColorThemes.arcade,
          'fieldnotes' => ColorThemes.fieldnotes,
          'nordic' => ColorThemes.nordic,
          'punch' => ColorThemes.punch,
          'ledger' => ColorThemes.ledger,
          'infrared' => ColorThemes.infrared,
          'porcelain' => ColorThemes.porcelain,
          'basalt' => ColorThemes.basalt,
          'citrus' => ColorThemes.citrus,
          'lavender' => ColorThemes.lavender,
          'glacier' => ColorThemes.glacier,
          'vinyl' => ColorThemes.vinyl,
          'botanical' => ColorThemes.botanical,
          'terminalAmber' => ColorThemes.terminalAmber,
          'slate' => ColorThemes.slate,
          'solar' => ColorThemes.solar,
          'deepSpace' => ColorThemes.deepSpace,
          'moss' => ColorThemes.moss,
          'copper' => ColorThemes.copper,
          'midnightMint' => ColorThemes.midnightMint,
          'typewriter' => ColorThemes.typewriter,
          'neonGrid' => ColorThemes.neonGrid,
          'sandstone' => ColorThemes.sandstone,
          'blueHour' => ColorThemes.blueHour,
          'matcha' => ColorThemes.matcha,
          'obsidian' => ColorThemes.obsidian,
          'clay' => ColorThemes.clay,
          'polar' => ColorThemes.polar,
          'forestFloor' => ColorThemes.forestFloor,
          'ultraviolet' => ColorThemes.ultraviolet,
          'seaGlass' => ColorThemes.seaGlass,
          'carbon' => ColorThemes.carbon,
          'sakura' => ColorThemes.sakura,
          'terminalGreen' => ColorThemes.terminalGreen,
          'desertDusk' => ColorThemes.desertDusk,
          'ion' => ColorThemes.ion,
          _ => throw StateError('Unknown palette $name'),
        };
        expect(palette, isA<ColorTheme>(), reason: name);
      }
    });

    test('Signal maps atlas tokens to semantic roles', () {
      final signal = ColorThemes.signal;
      expect(signal.foreground, TerminalColor.rgb(230, 232, 244));
      expect(signal.background, TerminalColor.rgb(25, 27, 40));
      expect(signal.muted, TerminalColor.rgb(161, 167, 189));
      expect(signal.accent, TerminalColor.rgb(182, 162, 255));
      expect(signal.selectionForeground, TerminalColor.rgb(25, 19, 41));
      expect(signal.selectionBackground, signal.accent);
      expect(signal.success, TerminalColor.rgb(155, 221, 180));
      expect(signal.warning, signal.accent);
      expect(signal.error, TerminalColor.rgb(255, 146, 158));
      expect(signal.border, TerminalColor.rgb(59, 61, 85));
    });

    test('atlas page colour is ignored; background uses terminal surface', () {
      // The Signal atlas page is #11121b, but the runtime background must be
      // the terminal surface (#191b28) so the palette never recolours the
      // global terminal surface.
      expect(ColorThemes.signal.background, isNot(TerminalColor.rgb(17, 18, 27)));
      expect(ColorThemes.signal.background, TerminalColor.rgb(25, 27, 40));
    });

    test('copyWith is immutable and retains unspecified roles', () {
      final signal = ColorThemes.signal;
      final patched = signal.copyWith(
        warning: TerminalColor.rgb(255, 190, 80),
      );
      expect(patched.warning, TerminalColor.rgb(255, 190, 80));
      expect(patched.foreground, signal.foreground);
      expect(patched.accent, signal.accent);
      // Original is unchanged.
      expect(signal.warning, signal.accent);
    });

    test('palette objects are independent; mutating a copied list does not leak', () {
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
      expect(custom.foreground, TerminalColor.rgb(1, 2, 3));
    });

    test('TerminalColor rejects out-of-range channel values', () {
      expect(() => TerminalColor.rgb(-1, 0, 0), throwsArgumentError);
      expect(() => TerminalColor.rgb(0, 256, 0), throwsArgumentError);
      expect(() => TerminalColor.indexed(-1), throwsArgumentError);
      expect(() => TerminalColor.indexed(256), throwsArgumentError);
    });

    test('terminalDefault uses native terminal colours for every role', () {
      final defaultPalette = ColorThemes.terminalDefault;
      expect(isTerminalDefault(defaultPalette.foreground), isTrue);
      expect(isTerminalDefault(defaultPalette.background), isTrue);
      expect(isTerminalDefault(defaultPalette.muted), isTrue);
      expect(isTerminalDefault(defaultPalette.accent), isTrue);
      expect(isTerminalDefault(defaultPalette.selectionForeground), isTrue);
      expect(isTerminalDefault(defaultPalette.selectionBackground), isTrue);
      expect(isTerminalDefault(defaultPalette.success), isTrue);
      expect(isTerminalDefault(defaultPalette.warning), isTrue);
      expect(isTerminalDefault(defaultPalette.error), isTrue);
      expect(isTerminalDefault(defaultPalette.border), isTrue);
    });
  });
}
