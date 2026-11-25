import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';
// The typed query/results projection is an internal presentation contract, not
// part of the public authoring surface: read it through its narrow seam.
import 'package:trelis/src/presentation.dart';
import 'package:test/test.dart';

import 'support/async_search_fixture.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

ScriptedInput _scriptedInput(
  Stream<String> input,
  StringSink output, {
  TextInputTranscript? transcript,
}) => ScriptedInput(
  input,
  output,
  outputProfile: _richProfile,
  transcript: transcript,
);

int _helpEvents(TextInputTranscript transcript) => transcript.events
    .where((event) => event.kind == TextInputPresentationEventKind.help)
    .length;

QueryResultsPresentation? _lastResults(TextInputTranscript transcript) {
  final occurrences = transcript.events
      .where((event) => event.kind == TextInputPresentationEventKind.results)
      .toList();
  return occurrences.isEmpty ? null : occurrences.last.results;
}

void main() {
  test('explicit rich mode requires declared geometry without querying suggestions', () async {
    var queried = false;
    final result =
        await Autocomplete(
          'Name',
          suggestions: (_) {
            queried = true;
            return <String>[];
          },
        ).prompt(
          source: ScriptedInput(const Stream<String>.empty(), StringBuffer()),
          mode: PromptMode.rich,
        );
    expect(result, isA<Unavailable<String>>());
    expect(queried, isFalse);
  });
  test(
    'one autocomplete instance rejects overlap across session and standalone',
    () async {
      final sessionInput = StreamController<String>();
      final prompt = Autocomplete('Name', suggestions: (_) => <String>[]);
      await TerminalSession.run(
        (session) async {
          final first = prompt.prompt(session: session);
          await expectLater(
            prompt.prompt(
              source: _scriptedInput(
                const Stream<String>.empty(),
                StringBuffer(),
              ),
              mode: PromptMode.linear,
            ),
            throwsStateError,
          );
          sessionInput.add('/cancel\r');
          expect(await first, isA<Cancelled<String>>());
        },
        source: _scriptedInput(sessionInput.stream, StringBuffer()),
        mode: PromptMode.linear,
      );
      await sessionInput.close();
    },
  );
  test(
    'standalone autocomplete defers suggestion output while help is open',
    () async {
      final input = StreamController<String>();
      final output = StringBuffer();
      final transcript = TextInputTranscript();
      final pending = Completer<List<String>>();
      final prompt = Autocomplete('Name', suggestions: (_) => pending.future)
          .prompt(
            source: _scriptedInput(
              input.stream,
              output,
              transcript: transcript,
            ),
            mode: PromptMode.rich,
          );
      input.add('\x1bOP');
      await settleUntil(() => _helpEvents(transcript) == 1);
      pending.complete(['Ada']);
      await settleUntil(
        () => _lastResults(transcript)?.phase == QueryResultsPhase.ready,
      );
      expect(output.toString(), isNot(contains('1 suggestions; none active.')));
      input.add('\x1b');
      await awaitLoneEscape();
      await settleUntil(
        () => output.toString().contains('1 suggestions; none active.'),
      );
      input.add('\x03');
      expect(await prompt, isA<Interrupted<String>>());
      await input.close();
    },
  );
  test(
    'suggestion display encodes bidi without altering accepted text',
    () async {
      final output = StringBuffer();
      final result =
          await Autocomplete('Name', suggestions: (_) => ['A\u202eB']).prompt(
            source: _scriptedInput(Stream.value('A\r1\r/submit\r'), output),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'A\u202eB');
      expect(output.toString(), contains(r'A\u{202E}B'));
      expect(output.toString(), isNot(contains('A\u202eB')));
    },
  );
  test('linear query help preserves a draft for continued editing', () async {
    final output = StringBuffer();
    final result = await Autocomplete('Name', suggestions: (_) => <String>[])
        .prompt(
          source: _scriptedInput(Stream.value('/help\rAda\r/submit\r'), output),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'Ada');
  });
  test(
    'hidden autocomplete instructions retain help and supplementary guidance',
    () async {
      final input = StreamController<String>();
      final output = StringBuffer();
      final transcript = TextInputTranscript();
      final prompt =
          Autocomplete(
            'Name',
            suggestions: (_) => <String>[],
            instructions: InstructionDisplay.hidden,
            supplementaryHelp: ['Use a preferred name.'],
          ).prompt(
            source: _scriptedInput(
              input.stream,
              output,
              transcript: transcript,
            ),
            mode: PromptMode.rich,
          );
      input.add('\x1bOP');
      await settleUntil(() => _helpEvents(transcript) == 1);
      expect(output.toString(), contains('Use a preferred name.'));
      input.add('\x1b');
      await awaitLoneEscape();
      input.add('\x03');
      expect(await prompt, isA<Interrupted<String>>());
      await input.close();
    },
  );
  test(
    'linear results help distinguishes choosing a candidate from submitting',
    () async {
      final output = StringBuffer();
      final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
          .prompt(
            source: _scriptedInput(
              Stream.value('A\r/help\r1\r/submit\r'),
              output,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'Ada');
      expect(output.toString(), contains('Help: Autocomplete results.'));
      expect(output.toString(), contains('number copies a candidate'));
    },
  );
  test(
    'suggestions completing during help are shown after dismissal',
    () async {
      final input = StreamController<String>();
      final output = StringBuffer();
      final transcript = TextInputTranscript();
      final pending = Completer<List<String>>();
      await TerminalSession.run(
        (session) async {
          final prompt = Autocomplete(
            'Name',
            suggestions: (_) => pending.future,
          ).prompt(session: session);
          input.add('\x1bOP');
          await settleUntil(() => _helpEvents(transcript) == 1);
          pending.complete(['Ada']);
          await settleUntil(
            () => _lastResults(transcript)?.phase == QueryResultsPhase.ready,
          );
          expect(
            output.toString(),
            isNot(contains('1 suggestions; none active.')),
          );
          input.add('\x1b');
          await awaitLoneEscape();
          await settleUntil(
            () => output.toString().contains('1 suggestions; none active.'),
          );
          input.add('\x03');
          expect(await prompt, isA<Interrupted<String>>());
        },
        source: _scriptedInput(input.stream, output, transcript: transcript),
        mode: PromptMode.rich,
      );
      await input.close();
    },
  );
  test(
    'autocomplete shares scripted input with the next session prompt',
    () async {
      final output = StringBuffer();
      final source = _scriptedInput(
        Stream.value('Ada\r/submit\rnext\r'),
        output,
      );
      await TerminalSession.run(
        (session) async {
          final first = await Autocomplete(
            'Name',
            suggestions: (_) => <String>[],
          ).prompt(session: session);
          final second = await TextInput('Next').prompt(session: session);
          expect((first as Accepted<String>).value, 'Ada');
          expect((second as Accepted<String>).value, 'next');
        },
        source: source,
        mode: PromptMode.linear,
      );
    },
  );
  test(
    'rich help explains candidate acceptance without losing the draft',
    () async {
      final input = StreamController<String>();
      final output = StringBuffer();
      final result = Autocomplete('Name', suggestions: (_) => ['Ada']).prompt(
        source: _scriptedInput(input.stream, output),
        mode: PromptMode.rich,
      );
      input.add('A\x1bOP\x1b');
      await awaitLoneEscape();
      input.add('\r');
      expect((await result as Accepted<String>).value, 'A');
      expect(
        output.toString(),
        contains('Help: Autocomplete. Tab accepts a candidate'),
      );
      expect(output.toString(), contains('Enter submits free text'));
      await input.close();
    },
  );
  test(
    'supplied unmatched text is accepted without querying suggestions',
    () async {
      var calls = 0;
      final prompt = Autocomplete(
        'Name',
        suggestions: (query) async {
          calls++;
          return ['Ada'];
        },
      );
      final result = await prompt.prompt(source: SuppliedAnswer('Grace'));
      expect((result as Accepted<String>).value, 'Grace');
      expect(calls, 0);
    },
  );
  test(
    'linear candidate acceptance requires explicit final submission',
    () async {
      final output = StringBuffer();
      final result =
          await Autocomplete(
            'Name',
            suggestions: (_) async => ['Ada', 'Grace'],
          ).prompt(
            source: _scriptedInput(Stream.value('A\r2\r/submit\r'), output),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'Grace');
      expect(output.toString(), contains('1. Ada'));
      expect(output.toString(), contains('2. Grace'));
    },
  );
  test(
    'rich navigation accepts a candidate before a separate submission',
    () async {
      final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
          .prompt(
            source: _scriptedInput(Stream.value('A\x1b[B\r\r'), StringBuffer()),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'Ada');
    },
  );
  test('linear free text can submit while suggestions are pending', () async {
    final pending = Completer<List<String>>();
    final result =
        await Autocomplete('Name', suggestions: (_) => pending.future)
            .prompt(
              source: _scriptedInput(
                Stream.value('Grace\r/submit\r'),
                StringBuffer(),
              ),
              mode: PromptMode.linear,
            )
            .timeout(const Duration(seconds: 1));
    expect((result as Accepted<String>).value, 'Grace');
  });
  test(
    'rich Escape dismisses pending suggestions before cancellation',
    () async {
      final pending = Completer<List<String>>();
      final input = StreamController<String>();
      final result = Autocomplete('Name', suggestions: (_) => pending.future)
          .prompt(
            source: _scriptedInput(input.stream, StringBuffer()),
            mode: PromptMode.rich,
          );
      input.add('A\x1b');
      await awaitLoneEscape();
      input.add('\r');
      expect((await result as Accepted<String>).value, 'A');
      await input.close();
    },
  );
  test(
    'linear default is editable and invalid submission retains draft',
    () async {
      final output = StringBuffer();
      final result =
          await Autocomplete(
            'Name',
            initialValue: 'Ada',
            required: true,
            suggestions: (_) => <String>[],
            validate: (value) => value == 'Ada!' ? null : 'Add an exclamation',
          ).prompt(
            source: _scriptedInput(
              Stream.value('\r/submit\r/edit\r!\r/submit\r'),
              output,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'Ada!');
      expect(output.toString(), contains('Add an exclamation'));
    },
  );
  test('Escape dismisses help before the active suggestion layer', () async {
    final input = StreamController<String>();
    final result = Autocomplete('Name', suggestions: (_) => ['Ada']).prompt(
      source: _scriptedInput(input.stream, StringBuffer()),
      mode: PromptMode.rich,
    );
    input.add('A\x1b[B\x1bOP\x1b');
    await awaitLoneEscape();
    input.add('\r\r');
    expect((await result as Accepted<String>).value, 'Ada');
    await input.close();
  });
  test('late rich results cannot replace newer suggestions', () async {
    final requests = PendingRequests<List<String>>();
    final input = StreamController<String>();
    final transcript = TextInputTranscript();
    final result = Autocomplete('Name', suggestions: requests.record).prompt(
      source: _scriptedInput(
        input.stream,
        StringBuffer(),
        transcript: transcript,
      ),
      mode: PromptMode.rich,
    );
    input.add('a');
    await settleUntil(() => requests.requested('a'));
    input.add('b');
    await settleUntil(() => requests.requested('ab'));
    requests.complete('ab', ['Newest']);
    await settleUntil(
      () => _lastResults(transcript)?.phase == QueryResultsPhase.ready,
    );
    requests.complete('a', ['Stale']);
    await settle();
    input.add('\t\r');
    expect((await result as Accepted<String>).value, 'Newest');
    await input.close();
  });
  test(
    'navigating and dismissing suggestions retains the editing cursor',
    () async {
      final input = StreamController<String>();
      final result = Autocomplete('Name', suggestions: (_) => ['candidate'])
          .prompt(
            source: _scriptedInput(input.stream, StringBuffer()),
            mode: PromptMode.rich,
          );
      input.add('ab\x1b[D\x1b[B\x1b');
      await awaitLoneEscape();
      input.add('X\r');
      expect((await result as Accepted<String>).value, 'aXb');
      await input.close();
    },
  );
  test('linear quoted command remains free-text data', () async {
    final result = await Autocomplete('Name', suggestions: (_) => <String>[])
        .prompt(
          source: _scriptedInput(
            Stream.value('\\/cancel\r/submit\r'),
            StringBuffer(),
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, '/cancel');
  });
  test('pasted action-stage submit is literal, not a command', () async {
    final result = await Autocomplete('Name', suggestions: (_) => <String>[])
        .prompt(
          source: _scriptedInput(
            Stream.value('Ada\r\x1b[200~/submit\x1b[201~\r/cancel\r'),
            StringBuffer(),
          ),
          mode: PromptMode.linear,
        );
    expect(result, isA<Cancelled<String>>());
  });
  test('quoted action-stage submit is not executed', () async {
    final result = await Autocomplete('Name', suggestions: (_) => <String>[])
        .prompt(
          source: _scriptedInput(
            Stream.value('Ada\r\\/submit\r/cancel\r'),
            StringBuffer(),
          ),
          mode: PromptMode.linear,
        );
    expect(result, isA<Cancelled<String>>());
  });
  test('pasted candidate number does not accept a candidate', () async {
    final result = await Autocomplete('Name', suggestions: (_) => ['Grace'])
        .prompt(
          source: _scriptedInput(
            Stream.value('Ada\r\x1b[200~1\x1b[201~\r/submit\r'),
            StringBuffer(),
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'Ada');
  });
  test(
    'late linear results cannot replace results for the edited query',
    () async {
      final requests = PendingRequests<List<String>>();
      final input = StreamController<String>();
      final transcript = TextInputTranscript();
      final result = Autocomplete('Name', suggestions: requests.record).prompt(
        source: _scriptedInput(
          input.stream,
          StringBuffer(),
          transcript: transcript,
        ),
        mode: PromptMode.linear,
      );
      input.add('a\r/edit\rb\r');
      await settleUntil(() => requests.requested('ab'));
      requests.complete('ab', ['Newest']);
      await settleUntil(
        () => _lastResults(transcript)?.phase == QueryResultsPhase.ready,
      );
      requests.complete('a', ['Stale']);
      await settle();
      input.add('1\r/submit\r');
      expect((await result as Accepted<String>).value, 'Newest');
      await input.close();
    },
  );
  test('offered candidates do not intercept free-text Enter', () async {
    final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
        .prompt(
          source: _scriptedInput(Stream.value('Grace\r'), StringBuffer()),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'Grace');
  });
  test('Tab accepts the first suggestion without submitting it', () async {
    final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
        .prompt(
          source: _scriptedInput(Stream.value('x\t!\r'), StringBuffer()),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'Ada!');
  });
  test('rich Escape dismisses suggestions then cancels', () async {
    final input = StreamController<String>();
    final result = Autocomplete('Name', suggestions: (_) => ['Ada']).prompt(
      source: _scriptedInput(input.stream, StringBuffer()),
      mode: PromptMode.rich,
    );
    input.add('x\x1b');
    await awaitLoneEscape();
    input.add('\x1b');
    await awaitLoneEscape();
    expect(await result, isA<Cancelled<String>>());
    await input.close();
  });
  test(
    'linear cancel remains available with a short character limit',
    () async {
      final result =
          await Autocomplete(
            'Name',
            maxLength: 2,
            suggestions: (_) => <String>[],
          ).prompt(
            source: _scriptedInput(Stream.value('/cancel\r'), StringBuffer()),
            mode: PromptMode.linear,
          );
      expect(result, isA<Cancelled<String>>());
    },
  );
  test(
    'rich introduction distinguishes candidate acceptance from submission',
    () async {
      final out = StringBuffer();
      final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
          .prompt(
            source: _scriptedInput(Stream.value('Grace\r'), out),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'Grace');
      expect(
        out.toString(),
        contains(
          'Tab accepts the first or active candidate; Enter accepts an active candidate or submits text',
        ),
      );
    },
  );
  test(
    'obsolete suggestion errors do not disturb current candidates',
    () async {
      final requests = PendingRequests<List<String>>();
      final input = StreamController<String>();
      final out = StringBuffer();
      final transcript = TextInputTranscript();
      final result = Autocomplete('Name', suggestions: requests.record).prompt(
        source: _scriptedInput(input.stream, out, transcript: transcript),
        mode: PromptMode.rich,
      );
      input.add('a');
      await settleUntil(() => requests.requested('a'));
      input.add('b');
      await settleUntil(() => requests.requested('ab'));
      requests.complete('ab', ['Current']);
      await settleUntil(
        () => _lastResults(transcript)?.phase == QueryResultsPhase.ready,
      );
      requests.fail('a', StateError('obsolete'));
      await settle();
      input.add('\t\r');
      expect((await result as Accepted<String>).value, 'Current');
      expect(out.toString(), isNot(contains('Suggestions unavailable.')));
      await input.close();
    },
  );
  test(
    'pending rich suggestions cannot be accepted with Tab or Enter',
    () async {
      final pending = Completer<List<String>>();
      final input = StreamController<String>();
      final out = StringBuffer();
      final transcript = TextInputTranscript();
      final result = Autocomplete('Name', suggestions: (_) => pending.future)
          .prompt(
            source: _scriptedInput(input.stream, out, transcript: transcript),
            mode: PromptMode.rich,
          );
      input.add('draft\t\r');
      expect((await result as Accepted<String>).value, 'draft');
      expect(out.toString(), isNot(contains('Accepted into editable text:')));
      expect(_lastResults(transcript)?.phase, QueryResultsPhase.loading);
      final snapshot = out.toString();
      pending.complete(['Late']);
      await settle();
      expect(out.toString(), snapshot);
      expect(_lastResults(transcript)?.phase, QueryResultsPhase.loading);
      await input.close();
    },
  );
  test('late suggestion error writes nothing after cancellation', () async {
    final pending = Completer<List<String>>();
    final input = StreamController<String>();
    final out = StringBuffer();
    final result = Autocomplete('Name', suggestions: (_) => pending.future)
        .prompt(
          source: _scriptedInput(input.stream, out),
          mode: PromptMode.linear,
        );
    input.add('draft\r/cancel\r');
    expect(await result, isA<Cancelled<String>>());
    final snapshot = out.toString();
    pending.completeError(StateError('late'));
    await settle();
    expect(out.toString(), snapshot);
    await input.close();
  });
}
