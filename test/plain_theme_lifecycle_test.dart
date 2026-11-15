import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  group('PlainTheme component lifecycles', () {
    test('textInput accepts a value in linear mode', () async {
      final input = PlainTheme.textInput('Name', colors: ColorThemes.signal);
      final output = StringBuffer();
      final result = await input.prompt(
        source: ScriptedInput(
          Stream.fromIterable(['Ada\n']),
          output,
          outputProfile: const OutputProfile(),
        ),
        mode: PromptMode.linear,
      );
      expect(result, isA<Accepted<String>>());
      expect((result as Accepted<String>).value, 'Ada');
      expect(output.toString(), contains('Name'));
    });

    test(
      'textInput accepts a value in rich mode with synthetic geometry',
      () async {
        final input = PlainTheme.textInput('Name', colors: ColorThemes.signal);
        final output = StringBuffer();
        final transcript = TextInputTranscript();
        final result = await input.prompt(
          source: ScriptedInput(
            Stream.fromIterable(['Ada\n']),
            output,
            supportsRich: true,
            outputProfile: OutputProfile(
              cursor: CapabilitySupport.supported,
              geometry: OutputGeometry.fixed(columns: 80, rows: 24),
            ),
            transcript: transcript,
          ),
          mode: PromptMode.rich,
        );
        expect(result, isA<Accepted<String>>());
        expect((result as Accepted<String>).value, 'Ada');
        expect(
          transcript.events.any(
            (event) => event.kind == TextInputPresentationEventKind.opened,
          ),
          isTrue,
        );
        expect(
          transcript.events.any(
            (event) => event.kind == TextInputPresentationEventKind.submitted,
          ),
          isTrue,
        );
      },
    );

    test('confirm accepts the default true value in linear mode', () async {
      final input = PlainTheme.confirm('Proceed?', initialValue: true);
      final output = StringBuffer();
      final result = await input.prompt(
        source: ScriptedInput(
          Stream.fromIterable(['\n']),
          output,
          outputProfile: const OutputProfile(),
        ),
        mode: PromptMode.linear,
      );
      expect(result, isA<Accepted<bool>>());
      expect((result as Accepted<bool>).value, isTrue);
    });

    test('select accepts a choice in linear mode', () async {
      final input = PlainTheme.select<String>('Letter', [
        Choice('a', 'Alpha'),
        Choice('b', 'Beta'),
      ]);
      final output = StringBuffer();
      final result = await input.prompt(
        source: ScriptedInput(
          Stream.fromIterable(['1\n']),
          output,
          outputProfile: const OutputProfile(),
        ),
        mode: PromptMode.linear,
      );
      expect(result, isA<Accepted<String>>());
      expect((result as Accepted<String>).value, 'a');
    });

    test('progress can be started and finished without a session', () async {
      final progress = PlainTheme.progress(
        'Work',
        total: 10,
        colors: ColorThemes.signal,
      );
      final output = StringBuffer();
      progress.start(output: output, supportsRich: false);
      progress.update(5);
      progress.finish(FeedbackOutcome.completed);
      final text = output.toString();
      expect(text, contains('Work'));
      expect(text, contains('completed'));
    });

    test('text uses the supplied color theme in present', () {
      final text = PlainTheme.text(
        'Ready',
        kind: TextKind.success,
        colors: ColorThemes.signal,
      );
      final output = StringBuffer();
      text.present(output: output);
      expect(output.toString(), contains('Ready'));
    });
  });
}
