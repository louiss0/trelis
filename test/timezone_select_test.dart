import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

ScriptedInput _scriptedInput(Stream<String> input, StringSink output) =>
    ScriptedInput(input, output, outputProfile: _richProfile);

void main() {
  test('timezone select accepts through the shared session', () async {
    final output = StringBuffer();
    final source = _scriptedInput(Stream.value('UTC\r/cancel\r'), output);
    final result = await TerminalSession.run(
      (session) => TimezoneSelect('Zone').prompt(session: session),
      source: source,
      mode: PromptMode.linear,
    );
    expect(result, isA<Cancelled<String>>());
    expect(output.toString(), contains('UTC'));
  });
  test('supplied stable reference accepts an enabled canonical zone', () async {
    final result = await TimezoneSelect('Zone')
        .prompt(source: SuppliedAnswer('105'));
    expect((result as Accepted<String>).value, 'America/New_York');
  });
  test('rich alias search and linear search return the same zone', () async {
    final result = await TimezoneSelect('Zone').prompt(
      source: _scriptedInput(Stream.value('US/Eastern\r\r'), StringBuffer()),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'America/New_York');
  });
  test('stale references do not select a different zone', () async {
    final out = StringBuffer();
    final result = await TimezoneSelect('Zone').prompt(
      source: _scriptedInput(Stream.value('US/Eastern\r1\r105\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'America/New_York');
    expect(out.toString(), contains('Choose a current result reference'));
  });
  test(
    'removed rich focus requires explicit navigation before acceptance',
    () async {
      final out = StringBuffer();
      final result =
          await TimezoneSelect('Zone', defaultValue: 'America/New_York').prompt(
            source: _scriptedInput(Stream.value('\rtokyo\r\r\x1b[B\r'), out),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'Asia/Tokyo');
      expect(
        out.toString(),
        contains('Previously focused choice is removed or unavailable'),
      );
    },
  );
  test('empty prompt label is rejected', () {
    expect(() => TimezoneSelect('  '), throwsArgumentError);
  });
  test('unknown defaults are rejected', () {
    expect(
      () => TimezoneSelect('Zone', defaultValue: 'Not/AZone'),
      throwsArgumentError,
    );
  });
  test('an unavailable default is explained instead of substituted', () async {
    final out = StringBuffer();
    final result =
        await TimezoneSelect(
          'Zone',
          defaultValue: 'US/Eastern',
          unavailable: {'America/New_York': 'not supported'},
        ).prompt(
          source: _scriptedInput(Stream.value('\r\r\x1b'), out),
          mode: PromptMode.rich,
        );
    expect(result, isA<InputEnded<String>>());
    expect(out.toString(), contains('not supported'));
  });
  test('an alias default retains its canonical identity', () async {
    final result = await TimezoneSelect('Zone', defaultValue: 'US/Eastern')
        .prompt(
          source: _scriptedInput(Stream.value('\r\r'), StringBuffer()),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'America/New_York');
  });
  test(
    'rich Enter opens results before accepting the default identity',
    () async {
      final out = StringBuffer();
      final result = await TimezoneSelect('Zone', defaultValue: 'Asia/Tokyo')
          .prompt(
            source: _scriptedInput(Stream.value('\r\r'), out),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'Asia/Tokyo');
      expect(out.toString(), contains('Results focused.'));
    },
  );
  test('linear search returns canonical IANA identity for an alias', () async {
    final out = StringBuffer();
    final result = await TimezoneSelect('Zone').prompt(
      source: _scriptedInput(Stream.value('US/Eastern\r105\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'America/New_York');
    expect(out.toString(), contains('2025c'));
  });
  test('rich and linear help state the matching and identity rules', () async {
    for (final mode in [PromptMode.rich, PromptMode.linear]) {
      final out = StringBuffer();
      final result = await TimezoneSelect('Zone').prompt(
        source: _scriptedInput(
          mode == PromptMode.rich
              ? Stream.value('\x1bOP\x1bUS/Eastern\r\r')
              : Stream.value('/help\rUS/Eastern\r105\r'),
          out,
        ),
        mode: mode,
      );

      expect((result as Accepted<String>).value, 'America/New_York');
      // Guidance is wrapped at the declared width, so compare one whitespace-
      // normalised document rather than depending on line breaks.
      final text = out.toString().replaceAll(RegExp(r'\s+'), ' ');
      expect(
        text,
        contains('Help: TimezoneSelect'),
        reason: '${mode.name} help is timezone-specific',
      );
      expect(text, contains('city names and aliases'));
      expect(text, contains('canonical identity'));
      expect(text, contains('no offset or current time'));
    }
  });
  test('hidden instructions keep the timezone help route', () async {
    final out = StringBuffer();
    final result =
        await TimezoneSelect(
          'Zone',
          instructions: InstructionDisplay.hidden,
        ).prompt(
          source: _scriptedInput(Stream.value('/help\rUS/Eastern\r105\r'), out),
          mode: PromptMode.linear,
        );

    expect((result as Accepted<String>).value, 'America/New_York');
    expect(out.toString(), contains('/help for help'));
    expect(out.toString(), contains('Help: TimezoneSelect'));
  });
}
