import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('OutputProfile exposes immutable declared capability vocabulary', () {
    final profile = OutputProfile(
      cursor: CapabilitySupport.supported,
      alternateScreen: CapabilitySupport.unsupported,
      styles: CapabilitySupport.supported,
      colorDepth: ColorDepth.indexed256,
      glyphs: GlyphSet.unicode,
      geometry: OutputGeometry.fixed(columns: 100, rows: 30),
      ambiguousWidth: AmbiguousWidth.wide,
    );

    expect(profile.cursor, CapabilitySupport.supported);
    expect(profile.alternateScreen, CapabilitySupport.unsupported);
    expect(profile.styles, CapabilitySupport.supported);
    expect(profile.colorDepth, ColorDepth.indexed256);
    expect(profile.glyphs, GlyphSet.unicode);
    expect(profile.geometry.columns, 100);
    expect(profile.geometry.rows, 30);
    expect(profile.ambiguousWidth, AmbiguousWidth.wide);
    expect(
      () => OutputGeometry.fixed(columns: 0, rows: 24),
      throwsArgumentError,
    );
  });

  test('OutputProfile replaces one declared fact without losing the rest', () {
    final profile = OutputProfile(
      cursor: CapabilitySupport.supported,
      alternateScreen: CapabilitySupport.unsupported,
      styles: CapabilitySupport.supported,
      colorDepth: ColorDepth.indexed256,
      glyphs: GlyphSet.unicode,
      geometry: OutputGeometry.fixed(columns: 100, rows: 30),
      ambiguousWidth: AmbiguousWidth.wide,
    );

    final reflowed = profile.copyWith(
      geometry: OutputGeometry.fixed(columns: 40, rows: 30),
    );

    expect(reflowed.geometry.columns, 40);
    expect(reflowed.cursor, CapabilitySupport.supported);
    expect(reflowed.alternateScreen, CapabilitySupport.unsupported);
    expect(reflowed.styles, CapabilitySupport.supported);
    expect(reflowed.colorDepth, ColorDepth.indexed256);
    expect(reflowed.glyphs, GlyphSet.unicode);
    expect(reflowed.ambiguousWidth, AmbiguousWidth.wide);
    expect(
      profile.copyWith(colorDepth: ColorDepth.none).colorDepth,
      ColorDepth.none,
    );
  });

  test('OutputProfile replaces and clears each declared fact', () {
    final profile = OutputProfile(
      cursor: CapabilitySupport.supported,
      alternateScreen: CapabilitySupport.unsupported,
      styles: CapabilitySupport.supported,
      colorDepth: ColorDepth.indexed256,
      glyphs: GlyphSet.unicode,
      geometry: OutputGeometry.fixed(columns: 100, rows: 30),
      ambiguousWidth: AmbiguousWidth.wide,
    );

    final changed = profile.copyWith(
      cursor: CapabilitySupport.unsupported,
      alternateScreen: CapabilitySupport.supported,
      styles: CapabilitySupport.unsupported,
      colorDepth: ColorDepth.none,
      glyphs: GlyphSet.ascii,
      geometry: const OutputGeometry.automatic(),
      ambiguousWidth: AmbiguousWidth.narrow,
    );

    expect(changed.cursor, CapabilitySupport.unsupported);
    expect(changed.alternateScreen, CapabilitySupport.supported);
    expect(changed.styles, CapabilitySupport.unsupported);
    expect(changed.colorDepth, ColorDepth.none);
    expect(changed.glyphs, GlyphSet.ascii);
    expect(changed.geometry.isAutomatic, isTrue);
    expect(changed.ambiguousWidth, AmbiguousWidth.narrow);
    expect(changed.isAutomatic, isFalse);
    expect(const OutputProfile().isAutomatic, isTrue);
  });

  test(
    'a source profile with cursor and positive geometry enables rich input',
    () async {
      final output = StringBuffer();
      final result = await TextInput('Name').prompt(
        source: ScriptedInput(
          Stream.value('Ada\r'),
          output,
          outputProfile: OutputProfile(
            cursor: CapabilitySupport.supported,
            geometry: OutputGeometry.fixed(columns: 100, rows: 30),
          ),
        ),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<String>).value, 'Ada');
      expect(output.toString(), contains('\x1b[2K'));
    },
  );

  test(
    'invocation facts override source and legacy hints field by field',
    () async {
      final output = StringBuffer();
      final result = await TextInput('Name').prompt(
        source: ScriptedInput(
          Stream.value('/cancel\r'),
          output,
          supportsRich: true,
          outputProfile: OutputProfile(
            cursor: CapabilitySupport.supported,
            geometry: OutputGeometry.fixed(columns: 100, rows: 30),
            glyphs: GlyphSet.unicode,
          ),
        ),
        outputProfile: OutputProfile(cursor: CapabilitySupport.unsupported),
      );

      expect(result, isA<Cancelled<String>>());
      expect(output.toString(), contains('Current text: /cancel'));
      expect(output.toString(), isNot(contains('\x1b[2K')));
    },
  );

  test(
    'legacy rich hint does not invent geometry for automatic or rich mode',
    () async {
      final automaticOutput = StringBuffer();
      final automatic = await TextInput('Name').prompt(
        source: ScriptedInput(Stream.value('/cancel\r'), automaticOutput),
      );
      expect(automatic, isA<Cancelled<String>>());
      expect(automaticOutput.toString(), contains('Current text: /cancel'));
      expect(automaticOutput.toString(), isNot(contains('\x1b[2K')));

      final richOutput = StringBuffer();
      final rich = await TextInput('Name').prompt(
        source: ScriptedInput(Stream.value('Ada\r'), richOutput),
        mode: PromptMode.rich,
      );
      expect(rich, isA<Unavailable<String>>());
      expect(richOutput.toString(), isEmpty);
    },
  );

  test(
    'an invocation profile can supply synthetic rich facts over legacy false',
    () async {
      final output = StringBuffer();
      final result = await TextInput('Name').prompt(
        source: ScriptedInput(
          Stream.value('Ada\r'),
          output,
          supportsRich: false,
        ),
        mode: PromptMode.rich,
        outputProfile: OutputProfile(
          cursor: CapabilitySupport.supported,
          geometry: OutputGeometry.fixed(columns: 100, rows: 30),
          styles: CapabilitySupport.supported,
          colorDepth: ColorDepth.rgb,
          glyphs: GlyphSet.unicode,
        ),
      );

      expect((result as Accepted<String>).value, 'Ada');
      expect(output.toString(), contains('\x1b[2K'));
      expect(
        output.toString(),
        isNot(contains('\x1b[3')),
        reason: 'colour requests do not add unimplemented colour sequences',
      );
    },
  );

  test('a terminal adapter can declare its selected output profile', () async {
    final output = StringBuffer();
    final terminal = ProfiledTerminalIo(
      Stream.value('Ada\r'),
      output,
      OutputProfile(
        cursor: CapabilitySupport.supported,
        geometry: OutputGeometry.fixed(columns: 100, rows: 30),
      ),
    );

    final result = await TextInput('Name')
        .prompt(terminal: terminal, mode: PromptMode.rich);

    expect((result as Accepted<String>).value, 'Ada');
    expect(terminal.events, ['acquire', 'restore']);
    expect(output.toString(), contains('\x1b[2K'));
  });

  test('supplied answers retain validation and literal command behavior without output', () async {
    final accepted = await TextInput('Name').prompt(
      source: SuppliedAnswer('/cancel'),
      outputProfile: OutputProfile(
        cursor: CapabilitySupport.supported,
        geometry: OutputGeometry.fixed(columns: 100, rows: 30),
      ),
    );
    final rejected = await TextInput('Name', required: true).prompt(
      source: SuppliedAnswer(''),
      outputProfile: OutputProfile(
        cursor: CapabilitySupport.supported,
        geometry: OutputGeometry.fixed(columns: 100, rows: 30),
      ),
    );

    expect((accepted as Accepted<String>).value, '/cancel');
    expect(rejected, isA<Unavailable<String>>());
  });
}

final class ProfiledTerminalIo implements TerminalIo, TerminalIoOutputProfile {
  ProfiledTerminalIo(this.input, this.output, this.outputProfile);

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  @override
  final OutputProfile outputProfile;

  @override
  bool get supportsRich => false;

  final List<String> events = [];

  @override
  Map<String, String?> get environment => const {};

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}
