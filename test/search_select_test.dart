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

bool _painted(StringSink sink, String text) => sink.toString().contains(text);

void main() {
  test(
    'one search instance rejects overlap across session and standalone',
    () async {
      final input = StreamController<String>();
      final prompt = SearchSelect('Fruit', [Choice('a', 'Apple')]);
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
          input.add('/cancel\r');
          expect(await first, isA<Cancelled<String>>());
        },
        source: _scriptedInput(input.stream, StringBuffer()),
        mode: PromptMode.linear,
      );
      await input.close();
    },
  );
  test('invalid search identities arriving during help are reported after dismissal', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final transcript = TextInputTranscript();
    final pending = Completer<List<Choice<String>>>();
    final prompt =
        SearchSelect('Fruit', [
          Choice('a', 'Apple'),
        ], search: (_) => pending.future).prompt(
          source: _scriptedInput(input.stream, output, transcript: transcript),
          mode: PromptMode.rich,
        );
    input.add('\x1bOP');
    await settleUntil(
      () => transcript.events.any(
        (event) => event.kind == TextInputPresentationEventKind.help,
      ),
    );
    pending.complete([Choice('unknown', 'Other')]);
    await settleUntil(
      () => transcript.events.any(
        (event) =>
            event.kind == TextInputPresentationEventKind.results &&
            event.results!.notices.contains(
              QueryResultsNotice.invalidIdentities,
            ),
      ),
    );
    expect(output.toString(), isNot(contains('unknown or duplicate')));
    input.add('\x1b');
    await awaitLoneEscape();
    await settleUntil(() => _painted(output, 'unknown or duplicate'));
    input.add('\x03');
    expect(await prompt, isA<Interrupted<String>>());
    await input.close();
  });
  test('standalone search defers results while query help is open', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final transcript = TextInputTranscript();
    final pending = Completer<List<Choice<String>>>();
    final prompt =
        SearchSelect('Fruit', [
          Choice('a', 'Apple'),
        ], search: (_) => pending.future).prompt(
          source: _scriptedInput(input.stream, output, transcript: transcript),
          mode: PromptMode.rich,
        );
    input.add('\x1bOP');
    await settleUntil(
      () => transcript.events.any(
        (event) => event.kind == TextInputPresentationEventKind.help,
      ),
    );
    pending.complete([Choice('a', 'Apple')]);
    await settleUntil(
      () => transcript.events.any(
        (event) =>
            event.kind == TextInputPresentationEventKind.results &&
            event.results!.phase == QueryResultsPhase.ready,
      ),
    );
    expect(output.toString(), isNot(contains('1. Apple')));
    input.add('\x1b');
    await awaitLoneEscape();
    await settleUntil(() => _painted(output, '1. Apple'));
    input.add('\x03');
    expect(await prompt, isA<Interrupted<String>>());
    await input.close();
  });
  test(
    'search results encode bidi controls without changing choice identity',
    () async {
      final output = StringBuffer();
      final result = await SearchSelect('Pick', [Choice('a', 'A\u202eB')])
          .prompt(
            source: _scriptedInput(Stream.value('\r1\r'), output),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'a');
      expect(output.toString(), contains(r'A\u{202E}B'));
      expect(output.toString(), isNot(contains('A\u202eB')));
    },
  );
  test('search failure during help is deferred until dismissal', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final transcript = TextInputTranscript();
    final pending = Completer<List<Choice<String>>>();
    await TerminalSession.run(
      (session) async {
        final prompt = SearchSelect('Fruit', [
          Choice('a', 'Apple'),
        ], search: (_) => pending.future).prompt(session: session);
        input.add('\x1bOP');
        await settleUntil(
          () => transcript.events.any(
            (event) => event.kind == TextInputPresentationEventKind.help,
          ),
        );
        pending.completeError(StateError('failure'));
        await settleUntil(
          () => transcript.events.any(
            (event) =>
                event.kind == TextInputPresentationEventKind.results &&
                event.results!.phase == QueryResultsPhase.failure,
          ),
        );
        expect(output.toString(), isNot(contains('Search unavailable')));
        input.add('\x1b');
        await awaitLoneEscape();
        await settleUntil(() => _painted(output, 'Search unavailable'));
        input.add('\x03');
        expect(await prompt, isA<Interrupted<String>>());
      },
      source: _scriptedInput(input.stream, output, transcript: transcript),
      mode: PromptMode.rich,
    );
    await input.close();
  });
  test('linear query help does not become part of the query', () async {
    final output = StringBuffer();
    final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
      source: _scriptedInput(Stream.value('/help\rApple\r1\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'a');
  });
  test(
    'linear results help explains stable references and searching again',
    () async {
      final output = StringBuffer();
      final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
        source: _scriptedInput(Stream.value('Apple\r/help\r1\r'), output),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, 'a');
      expect(output.toString(), contains('Help: SearchSelect results.'));
      expect(output.toString(), contains('source-stable reference'));
    },
  );
  test('search completion during help appears after dismissal', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final transcript = TextInputTranscript();
    final pending = Completer<List<Choice<String>>>();
    await TerminalSession.run(
      (session) async {
        final prompt = SearchSelect('Fruit', [
          Choice('a', 'Apple'),
        ], search: (_) => pending.future).prompt(session: session);
        input.add('\x1bOP');
        await settleUntil(
          () => transcript.events.any(
            (event) => event.kind == TextInputPresentationEventKind.help,
          ),
        );
        pending.complete([Choice('a', 'Apple')]);
        await settleUntil(
          () => transcript.events.any(
            (event) =>
                event.kind == TextInputPresentationEventKind.results &&
                event.results!.phase == QueryResultsPhase.ready,
          ),
        );
        expect(output.toString(), isNot(contains('1. Apple')));
        input.add('\x1b');
        await awaitLoneEscape();
        await settleUntil(() => _painted(output, '1. Apple'));
        input.add('\x03');
        expect(await prompt, isA<Interrupted<String>>());
      },
      source: _scriptedInput(input.stream, output, transcript: transcript),
      mode: PromptMode.rich,
    );
    await input.close();
  });
  test('feedback waits while search results help owns the session', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final transcript = TextInputTranscript();
    await TerminalSession.run(
      (session) async {
        final region = session.startFeedbackRegion();
        final prompt = SearchSelect('Fruit', [
          Choice('a', 'Apple'),
        ]).prompt(session: session);
        input.add('\r\x1bOP');
        await settleUntil(
          () => transcript.events.any(
            (event) => event.kind == TextInputPresentationEventKind.help,
          ),
        );
        region.write('background update');
        await settle();
        expect(output.toString(), isNot(contains('background update')));
        input.add('\x1b');
        await awaitLoneEscape();
        await settleUntil(() => _painted(output, 'background update'));
        input.add('\x03');
        expect(await prompt, isA<Interrupted<String>>());
        region.retire();
      },
      source: _scriptedInput(input.stream, output, transcript: transcript),
      mode: PromptMode.rich,
    );
    await input.close();
  });
  test('feedback waits while search query help owns the session', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final transcript = TextInputTranscript();
    await TerminalSession.run(
      (session) async {
        final region = session.startFeedbackRegion();
        final prompt = SearchSelect('Fruit', [
          Choice('a', 'Apple'),
        ]).prompt(session: session);
        input.add('\x1bOP');
        await settleUntil(
          () => transcript.events.any(
            (event) => event.kind == TextInputPresentationEventKind.help,
          ),
        );
        region.write('background update');
        await settle();
        expect(output.toString(), isNot(contains('background update')));
        input.add('\x1b');
        await awaitLoneEscape();
        await settleUntil(() => _painted(output, 'background update'));
        input.add('\x03');
        expect(await prompt, isA<Interrupted<String>>());
        expect(output.toString(), contains('background update'));
        region.retire();
      },
      source: _scriptedInput(input.stream, output, transcript: transcript),
      mode: PromptMode.rich,
    );
    await input.close();
  });
  test(
    'search select shares scripted input with the next session prompt',
    () async {
      final source = _scriptedInput(
        Stream.value('Apple\r1\rnext\r'),
        StringBuffer(),
      );
      await TerminalSession.run(
        (session) async {
          final first = await SearchSelect('Fruit', [
            Choice('a', 'Apple'),
          ]).prompt(session: session);
          final second = await TextInput('Next').prompt(session: session);
          expect((first as Accepted<String>).value, 'a');
          expect((second as Accepted<String>).value, 'next');
        },
        source: source,
        mode: PromptMode.linear,
      );
    },
  );
  test('query help explains Enter only opens results', () async {
    final out = StringBuffer();
    final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
      source: _scriptedInput(Stream.value('\x1bOP\x1b\r\r'), out),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'a');
    expect(out.toString(), contains('Enter opens results without accepting'));
  });
  test(
    'removed focused result requires navigation before rich acceptance',
    () async {
      final out = StringBuffer();
      final result =
          await SearchSelect(
            'Fruit',
            [Choice('a', 'Apple'), Choice('b', 'Banana')],
            search: (q) => q.isEmpty
                ? [Choice('a', 'Apple'), Choice('b', 'Banana')]
                : [Choice('b', 'Banana')],
          ).prompt(
            source: _scriptedInput(Stream.value('\r\t\tb\r\r\x1b[B\r'), out),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'b');
      expect(
        out.toString(),
        contains('Previously focused choice is removed or unavailable'),
      );
    },
  );
  test('rich results help is dismissed before root cancellation', () async {
    final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
      source: _scriptedInput(Stream.value('\r\x1bOP\x1b\r'), StringBuffer()),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'a');
  });
  test('supplied reference cannot bypass dynamic availability', () async {
    final result = await SearchSelect('Fruit', [
      Choice('a', 'Apple'),
    ], search: (_) => <Choice<String>>[]).prompt(source: SuppliedAnswer('1'));
    expect(result, isA<Unavailable<String>>());
  });
  test('pending async search cannot accept a reference', () async {
    final requests = PendingRequests<List<Choice<String>>>();
    final input = StreamController<String>();
    final out = StringBuffer();
    final result =
        SearchSelect<String>('Fruit', [
          Choice('a', 'Apple'),
        ], search: requests.record).prompt(
          source: _scriptedInput(input.stream, out),
          mode: PromptMode.linear,
        );
    input.add('\r1\r');
    await settleUntil(
      () => _painted(out, 'Choose a current result reference.'),
    );
    await settleUntil(() => requests.requested(''));
    requests.complete('', [Choice('a', 'Apple')]);
    await settleUntil(() => _painted(out, '1. Apple'));
    input.add('1\r');
    expect((await result as Accepted<String>).value, 'a');
    await input.close();
  });

  test('late asynchronous result does not write after cancellation', () async {
    final pending = Completer<List<Choice<String>>>();
    final out = StringBuffer();
    final result =
        await SearchSelect('Fruit', [
          Choice('a', 'Apple'),
        ], search: (_) => pending.future).prompt(
          source: _scriptedInput(Stream.value('/cancel\r'), out),
          mode: PromptMode.linear,
        );
    expect(result, isA<Cancelled<String>>());
    final snapshot = out.toString();
    pending.complete([Choice('a', 'Apple')]);
    await settle();
    expect(out.toString(), snapshot);
  });
  test('default focus resumes when it matches again after filtering', () async {
    final result =
        await SearchSelect('Fruit', [
          Choice('a', 'Apple'),
          Choice('b', 'Banana'),
        ], defaultValue: 'b').prompt(
          source: _scriptedInput(
            Stream.value('app\r\t\t\x7f\x7f\x7f\r\r'),
            StringBuffer(),
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'b');
  });
  test('disabled default is explained and cannot be accepted', () async {
    final out = StringBuffer();
    final result =
        await SearchSelect('Fruit', [
          Choice('a', 'Apple', disabledReason: 'seasonal'),
          Choice('b', 'Banana'),
        ], defaultValue: 'a').prompt(
          source: _scriptedInput(Stream.value('\r\r\x1b[B\r'), out),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'b');
    expect(out.toString(), contains('Unavailable: seasonal'));
  });

  test(
    'linear paging retains original references and permits review',
    () async {
      final out = StringBuffer();
      final result =
          await SearchSelect('Items', [
            for (var i = 1; i <= 12; i++) Choice(i, 'Item $i'),
          ]).prompt(
            source: _scriptedInput(
              Stream.value('item\r/next\r/list\r12\r'),
              out,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<int>).value, 12);
      expect(out.toString(), contains('Page 2 of 2'));
      expect(out.toString(), contains('12. Item 12'));
    },
  );

  test('no matches cannot submit and query can be replaced', () async {
    final out = StringBuffer();
    final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
      source: _scriptedInput(
        Stream.value('zzz\r1\r/search\r\x7f\x7f\x7fapple\r1\r'),
        out,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'a');
    expect(out.toString(), contains('No matching choices'));
  });
  test(
    'rich results entered while loading can be accepted after loading',
    () async {
      final requests = PendingRequests<List<Choice<String>>>();
      final input = StreamController<String>();
      final transcript = TextInputTranscript();
      final result =
          SearchSelect<String>('Fruit', [
            Choice('a', 'Apple'),
          ], search: requests.record).prompt(
            source: _scriptedInput(
              input.stream,
              StringBuffer(),
              transcript: transcript,
            ),
            mode: PromptMode.rich,
          );
      input.add('\r');
      await settleUntil(
        () => transcript.events.any(
          (event) =>
              event.kind == TextInputPresentationEventKind.results &&
              event.results!.phase == QueryResultsPhase.loading,
        ),
      );
      requests.complete('', [Choice('a', 'Apple')]);
      await settleUntil(
        () => transcript.events.any(
          (event) =>
              event.kind == TextInputPresentationEventKind.results &&
              event.results!.phase == QueryResultsPhase.ready,
        ),
      );
      input.add('\r');
      await input.close();
      expect((await result as Accepted<String>).value, 'a');
    },
  );
  test('linear user can explicitly choose after an async focused choice disappears', () async {
    final out = StringBuffer();
    final result =
        await SearchSelect(
          'Fruit',
          [Choice('a', 'Apple'), Choice('b', 'Banana')],
          defaultValue: 'a',
          search: (q) => q.isEmpty
              ? [Choice('a', 'Apple'), Choice('b', 'Banana')]
              : [Choice('b', 'Banana')],
        ).prompt(
          source: _scriptedInput(Stream.value('\r/search\rb\r2\r'), out),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'b');
    expect(out.toString(), contains('Previously focused choice'));
  });
  test('obsolete async search cannot replace current results', () async {
    final requests = PendingRequests<List<Choice<String>>>();
    final input = StreamController<String>();
    final out = StringBuffer();
    final transcript = TextInputTranscript();
    final prompt =
        SearchSelect<String>('Fruit', [
          Choice('a', 'Apple'),
          Choice('b', 'Banana'),
        ], search: requests.record).prompt(
          source: _scriptedInput(input.stream, out, transcript: transcript),
          mode: PromptMode.linear,
        );
    input.add('a');
    await settleUntil(() => requests.requested('a'));
    input.add('\x7fb\r');
    await settleUntil(() => requests.requested('b'));
    requests.complete('b', [Choice('b', 'Banana')]);
    await settleUntil(
      () => transcript.events.any(
        (event) =>
            event.kind == TextInputPresentationEventKind.results &&
            event.results!.phase == QueryResultsPhase.ready,
      ),
    );
    requests.complete('a', [Choice('a', 'Apple')]);
    await settle();
    input.add('1\r2\r');
    expect((await prompt as Accepted<String>).value, 'b');
    await input.close();
  });
  test(
    'Tab traverses results and cancel action before returning to query',
    () async {
      final out = StringBuffer();
      final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
        source: _scriptedInput(Stream.value('\t\t\t\r\r'), out),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<String>).value, 'a');
      expect(out.toString(), contains('Cancel action focused'));
    },
  );
  test('returning from no matches restores prior focused choice', () async {
    final result =
        await SearchSelect('Fruit', [
          Choice('apple', 'Apple'),
          Choice('pear', 'Pear'),
        ]).prompt(
          source: _scriptedInput(
            Stream.value('\r\x1b[B\t\tzzz\r\t\t\x7f\x7f\x7f\r\r'),
            StringBuffer(),
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'pear');
  });
  test('pasting in results returns to query without accepting', () async {
    final result =
        await SearchSelect('Fruit', [
          Choice('apple', 'Apple'),
          Choice('pear', 'Pear'),
        ]).prompt(
          source: _scriptedInput(
            Stream.value('\r\x1b[200~pear\x1b[201~\r\r'),
            StringBuffer(),
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'pear');
  });
  test('query Enter cannot accept a choice', () async {
    final result = await SearchSelect('Fruit', [Choice('apple', 'Apple')])
        .prompt(
          source: _scriptedInput(Stream.value('app\r'), StringBuffer()),
          mode: PromptMode.rich,
        );
    expect(result, isA<InputEnded<String>>());
  });

  test(
    'linear search rejects a stale reference before accepting a current one',
    () async {
      final output = StringBuffer();
      final result =
          await SearchSelect('Fruit', [
            Choice('apple', 'Apple'),
            Choice('pear', 'Pear'),
          ]).prompt(
            source: _scriptedInput(Stream.value('pear\r1\r2\r'), output),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'pear');
      expect(output.toString(), contains('Choose a current result reference.'));
    },
  );
  test('Enter in query only enters results; Enter there chooses', () async {
    final output = StringBuffer();
    final result =
        await SearchSelect('Fruit', [
          Choice('apple', 'Apple'),
          Choice('pear', 'Pear'),
        ]).prompt(
          source: _scriptedInput(Stream.value('PL\r\r'), output),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'apple');
    expect(output.toString(), contains('1. Apple'));
  });
  test('failed search remains distinct from empty results on list', () async {
    final out = StringBuffer();
    final result =
        await SearchSelect('Fruit', [
          Choice('a', 'Apple'),
        ], search: (_) => throw StateError('offline')).prompt(
          source: _scriptedInput(Stream.value('x\r/list\r/cancel\r'), out),
          mode: PromptMode.linear,
        );
    expect(result, isA<Cancelled<String>>());
    expect(
      'Search unavailable; edit the query to retry.'
          .allMatches(out.toString())
          .length,
      greaterThanOrEqualTo(2),
    );
    expect(out.toString(), isNot(contains('No matching choices')));
  });
  test(
    'invalid identities fail and edited query recovers source order',
    () async {
      for (final invalid in [
        <Choice<String>>[Choice('z', 'Unknown')],
        <Choice<String>>[Choice('a', 'First'), Choice('a', 'Again')],
      ]) {
        final out = StringBuffer();
        final result =
            await SearchSelect(
              'Fruit',
              [Choice('a', 'Apple'), Choice('b', 'Banana')],
              search: (q) => q == 'x'
                  ? invalid
                  : [Choice('b', 'Renamed B'), Choice('a', 'Renamed A')],
            ).prompt(
              source: _scriptedInput(
                Stream.value('x\r/list\r1\r/search\r\x7fy\r2\r'),
                out,
              ),
              mode: PromptMode.linear,
            );
        expect((result as Accepted<String>).value, 'b');
        expect(out.toString(), contains('unknown or duplicate identities'));
        expect(
          out.toString(),
          contains('Search unavailable; edit the query to retry.'),
        );
        expect(out.toString(), contains('Choose a current result reference.'));
        expect(out.toString(), contains('1. Renamed A'));
        expect(out.toString(), contains('2. Renamed B'));
        expect(
          out.toString().indexOf('1. Renamed A'),
          lessThan(out.toString().indexOf('2. Renamed B')),
        );
      }
    },
  );
  test(
    'rich obsolete success and error do not disturb current results',
    () async {
      final requests = PendingRequests<List<Choice<String>>>();
      final input = StreamController<String>();
      final out = StringBuffer();
      final transcript = TextInputTranscript();
      final result =
          SearchSelect<String>('Fruit', [
            Choice('a', 'Apple'),
            Choice('b', 'Banana'),
          ], search: requests.record).prompt(
            source: _scriptedInput(input.stream, out, transcript: transcript),
            mode: PromptMode.rich,
          );
      input.add('a');
      await settleUntil(() => requests.requested('a'));
      input.add('b');
      await settleUntil(() => requests.requested('ab'));
      input.add('c\r');
      await settleUntil(() => requests.requested('abc'));
      requests.complete('abc', [Choice('b', 'Fresh')]);
      await settleUntil(
        () => transcript.events.any(
          (event) =>
              event.kind == TextInputPresentationEventKind.results &&
              event.results!.phase == QueryResultsPhase.ready,
        ),
      );
      requests.fail('ab', StateError('stale'));
      requests.complete('a', [Choice('a', 'Stale')]);
      await settle();
      input.add('\r');
      expect((await result as Accepted<String>).value, 'b');
      expect(out.toString(), isNot(contains('Search unavailable')));
      expect(out.toString(), isNot(contains('Stale')));
      await input.close();
    },
  );
  test('async failure persists on list and edited query recovers', () async {
    final out = StringBuffer();
    final input = StreamController<String>();
    final transcript = TextInputTranscript();
    final pending = Completer<List<Choice<String>>>();
    final result =
        SearchSelect<String>(
          'Fruit',
          [Choice('a', 'Apple')],
          search: (q) => q == 'x'
              ? pending.future
              : <Choice<String>>[Choice('a', 'Apple')],
        ).prompt(
          source: _scriptedInput(input.stream, out, transcript: transcript),
          mode: PromptMode.linear,
        );
    input.add('x\r');
    await settleUntil(
      () => transcript.events.any(
        (event) =>
            event.kind == TextInputPresentationEventKind.results &&
            event.results!.phase == QueryResultsPhase.loading,
      ),
    );
    pending.completeError(StateError('offline'));
    await settleUntil(
      () => transcript.events.any(
        (event) =>
            event.kind == TextInputPresentationEventKind.results &&
            event.results!.phase == QueryResultsPhase.failure,
      ),
    );
    input.add('/list\r1\r/search\r\x7fy\r1\r');
    expect((await result as Accepted<String>).value, 'a');
    expect(
      'Search unavailable; edit the query to retry.'
          .allMatches(out.toString())
          .length,
      greaterThanOrEqualTo(2),
    );
    expect(out.toString(), contains('Choose a current result reference.'));
    await input.close();
  });
}
