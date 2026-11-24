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

ScriptedInput _scripted(
  Stream<String> input,
  StringSink output, {
  TextInputTranscript? transcript,
}) => ScriptedInput(
  input,
  output,
  outputProfile: _richProfile,
  transcript: transcript,
);

QueryResultsPresentation? _results(TextInputTranscript transcript) {
  final occurrences = transcript.events
      .where((event) => event.kind == TextInputPresentationEventKind.results)
      .toList();
  return occurrences.isEmpty ? null : occurrences.last.results;
}

QueryResultsPresentation _resultsAt(
  TextInputTranscript transcript,
  QueryResultsPhase phase,
) {
  final occurrence = transcript.events
      .where(
        (event) =>
            event.kind == TextInputPresentationEventKind.results &&
            event.results?.phase == phase,
      )
      .toList();
  expect(
    occurrence,
    isNotEmpty,
    reason: 'expected a recorded ${phase.name} query/results state',
  );
  return occurrence.last.results!;
}

/// Painted text with wrapping and indentation collapsed, so an assertion names
/// help content rather than a particular wrap point.
String _painted(StringSink sink) =>
    sink.toString().replaceAll(RegExp(r'\s+'), ' ');

int _helpEvents(TextInputTranscript transcript) => transcript.events
    .where((event) => event.kind == TextInputPresentationEventKind.help)
    .length;

void main() {
  group('typed query/results projection', () {
    test(
      'source-stable results expose the displayed choice reference',
      () async {
        final transcript = TextInputTranscript();
        final result =
            await SearchSelect('Fruit', [
              Choice('a', 'Apple'),
              Choice('b', 'Banana'),
            ]).prompt(
              source: _scripted(
                Stream.value('app\r1\r'),
                StringBuffer(),
                transcript: transcript,
              ),
              mode: PromptMode.linear,
            );

        expect((result as Accepted<String>).value, 'a');
        final ready = _resultsAt(transcript, QueryResultsPhase.ready);
        expect(ready.component, 'SearchSelect');
        expect(
          ready.identityModel,
          QueryResultsIdentityModel.sourceStableChoice,
        );
        expect(ready.query.value, 'app');
        expect(ready.totalResults, 1);
        expect(ready.rows.single.reference, 1);
        expect(ready.rows.single.position, 1);
        expect(ready.rows.single.label.value, 'Apple');
        expect(ready.canAccept, isTrue);
      },
    );

    test(
      'response-local candidates expose positions, not references',
      () async {
        final transcript = TextInputTranscript();
        final result =
            await Autocomplete(
              'Name',
              suggestions: (_) => ['Ada', 'Grace'],
            ).prompt(
              source: _scripted(
                Stream.value('A\r1\r/submit\r'),
                StringBuffer(),
                transcript: transcript,
              ),
              mode: PromptMode.linear,
            );

        expect((result as Accepted<String>).value, 'Ada');
        final ready = _resultsAt(transcript, QueryResultsPhase.ready);
        expect(ready.component, 'Autocomplete');
        expect(
          ready.identityModel,
          QueryResultsIdentityModel.responseLocalCandidate,
        );
        expect(ready.rows.map((row) => row.reference), [null, null]);
        expect(ready.rows.map((row) => row.position), [1, 2]);
        expect(ready.rows.map((row) => row.label.value), ['Ada', 'Grace']);
        expect(ready.totalResults, 2);
      },
    );

    test('loading, empty and failure phases are explicit', () async {
      final requests = PendingRequests<List<Choice<String>>>();
      final input = StreamController<String>();
      final output = StringBuffer();
      final transcript = TextInputTranscript();
      final prompt =
          SearchSelect<String>('Fruit', [
            Choice('a', 'Apple'),
          ], search: requests.record).prompt(
            source: _scripted(input.stream, output, transcript: transcript),
            mode: PromptMode.linear,
          );

      input.add('ap\r');
      await settleUntil(() => requests.requested('ap'));
      final loading = _resultsAt(transcript, QueryResultsPhase.loading);
      expect(loading.query.value, 'ap');
      expect(loading.canAccept, isFalse);
      expect(loading.rows, isEmpty);

      requests.complete('ap', const []);
      await settleUntil(
        () => _results(transcript)?.phase == QueryResultsPhase.empty,
        description: 'an empty response is recorded as ready-empty',
      );
      final empty = _resultsAt(transcript, QueryResultsPhase.empty);
      expect(empty.canAccept, isFalse);
      expect(empty.notices, isNot(contains(QueryResultsNotice.retryByEditing)));
      expect(empty.retryAvailable, isFalse);

      input.add('/search\r\x7f\x7fx\r');
      await settleUntil(() => requests.requested('x'));
      requests.fail('x', StateError('offline'));
      await settleUntil(
        () => _results(transcript)?.phase == QueryResultsPhase.failure,
        description: 'a failed response is recorded as failure',
      );
      final failure = _resultsAt(transcript, QueryResultsPhase.failure);
      expect(failure.canAccept, isFalse);
      expect(failure.retryAvailable, isTrue);
      expect(failure.notices, contains(QueryResultsNotice.retryByEditing));

      input.add('/cancel\r');
      expect(await prompt, isA<Cancelled<String>>());
      await input.close();
    });

    test(
      'unknown or duplicate response identities are a typed notice',
      () async {
        final transcript = TextInputTranscript();
        final result =
            await SearchSelect(
              'Fruit',
              [Choice('a', 'Apple'), Choice('b', 'Banana')],
              search: (query) => query == 'x'
                  ? [Choice('z', 'Unknown')]
                  : [Choice('a', 'Apple')],
            ).prompt(
              source: _scripted(
                Stream.value('x\r/search\r\x7fy\r1\r'),
                StringBuffer(),
                transcript: transcript,
              ),
              mode: PromptMode.linear,
            );

        expect((result as Accepted<String>).value, 'a');
        final failure = _resultsAt(transcript, QueryResultsPhase.failure);
        expect(failure.notices, contains(QueryResultsNotice.invalidIdentities));
        expect(failure.notices, contains(QueryResultsNotice.retryByEditing));
        expect(
          _resultsAt(transcript, QueryResultsPhase.ready).canAccept,
          isTrue,
        );
      },
    );
  });

  group('meaningful presentation events', () {
    test('query submission is distinct from candidate acceptance', () async {
      final transcript = TextInputTranscript();
      final result = await SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
        source: _scripted(
          Stream.value('app\r1\r'),
          StringBuffer(),
          transcript: transcript,
        ),
        mode: PromptMode.linear,
      );

      expect((result as Accepted<String>).value, 'a');
      final kinds = transcript.events.map((event) => event.kind).toList();
      expect(kinds, contains(TextInputPresentationEventKind.resultsFocused));
      expect(kinds, contains(TextInputPresentationEventKind.submitted));
      expect(kinds, contains(TextInputPresentationEventKind.candidateAccepted));
      expect(kinds, isNot(contains(TextInputPresentationEventKind.rejected)));
      final accepted = transcript.events.firstWhere(
        (event) =>
            event.kind == TextInputPresentationEventKind.candidateAccepted,
      );
      expect(accepted.reference, 1);
      expect(accepted.text, 'Apple');
      expect(transcript.events.map((event) => event.id), [
        for (var id = 1; id <= transcript.events.length; id++) id,
      ]);
    });

    test(
      'free-text autocomplete submission is not a candidate acceptance',
      () async {
        final transcript = TextInputTranscript();
        final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
            .prompt(
              source: _scripted(
                Stream.value('Grace\r'),
                StringBuffer(),
                transcript: transcript,
              ),
              mode: PromptMode.rich,
            );

        expect((result as Accepted<String>).value, 'Grace');
        expect(
          transcript.events.map((event) => event.kind),
          isNot(contains(TextInputPresentationEventKind.candidateAccepted)),
        );
        expect(
          transcript.events.map((event) => event.kind),
          contains(TextInputPresentationEventKind.submitted),
        );
      },
    );

    test(
      'a response-local candidate acceptance has no source-stable reference',
      () async {
        final transcript = TextInputTranscript();
        final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
            .prompt(
              source: _scripted(
                Stream.value('A\r1\r/submit\r'),
                StringBuffer(),
                transcript: transcript,
              ),
              mode: PromptMode.linear,
            );

        expect((result as Accepted<String>).value, 'Ada');
        final accepted = transcript.events.singleWhere(
          (event) =>
              event.kind == TextInputPresentationEventKind.candidateAccepted,
        );
        expect(accepted.text, 'Ada');
        expect(
          accepted.reference,
          isNull,
          reason:
              'a position belongs to one suggestion response and is not a '
              'source-stable identity',
        );
        final ready = transcript.events
            .where(
              (event) =>
                  event.kind == TextInputPresentationEventKind.results &&
                  event.results?.phase == QueryResultsPhase.ready,
            )
            .last
            .results!;
        expect(
          ready.identityModel,
          QueryResultsIdentityModel.responseLocalCandidate,
        );
        expect(ready.rows.single.position, 1);
        expect(ready.rows.single.reference, isNull);
      },
    );

    test(
      'a refused reference is recorded as a rejection, not an acceptance',
      () async {
        final transcript = TextInputTranscript();
        final result =
            await SearchSelect('Fruit', [
              Choice('a', 'Apple', disabledReason: 'seasonal'),
              Choice('b', 'Banana'),
            ]).prompt(
              source: _scripted(
                Stream.value('\r1\r2\r'),
                StringBuffer(),
                transcript: transcript,
              ),
              mode: PromptMode.linear,
            );

        expect((result as Accepted<String>).value, 'b');
        final rejections = transcript.events
            .where(
              (event) => event.kind == TextInputPresentationEventKind.rejected,
            )
            .toList();
        expect(rejections, hasLength(1));
        expect(rejections.single.text, 'seasonal');
        expect(rejections.single.reference, 1);
        expect(
          transcript.events
              .where(
                (event) =>
                    event.kind ==
                    TextInputPresentationEventKind.candidateAccepted,
              )
              .single
              .reference,
          2,
        );
      },
    );

    test(
      'repeated identical states keep distinct occurrence identities',
      () async {
        final requests = PendingRequests<List<Choice<String>>>();
        final input = StreamController<String>();
        final transcript = TextInputTranscript();
        final prompt =
            SearchSelect<String>('Fruit', [
              Choice('a', 'Apple'),
            ], search: requests.record).prompt(
              source: _scripted(
                input.stream,
                StringBuffer(),
                transcript: transcript,
              ),
              mode: PromptMode.linear,
            );

        input.add('a\r');
        await settleUntil(() => requests.requested('a'));
        requests.fail('a', StateError('offline'));
        await settleUntil(
          () => _results(transcript)?.phase == QueryResultsPhase.failure,
        );
        input.add('/search\rb\r');
        await settleUntil(() => requests.requested('ab'));
        requests.fail('ab', StateError('offline'));
        await settleUntil(
          () =>
              transcript.events
                  .where(
                    (event) =>
                        event.kind == TextInputPresentationEventKind.results &&
                        event.results?.phase == QueryResultsPhase.failure,
                  )
                  .length ==
              2,
          description: 'the second identical failure is a fresh occurrence',
        );
        final failures = transcript.events
            .where(
              (event) =>
                  event.kind == TextInputPresentationEventKind.results &&
                  event.results?.phase == QueryResultsPhase.failure,
            )
            .toList();
        expect(failures.first.id, lessThan(failures.last.id));
        expect(failures.map((event) => event.results!.phase), [
          QueryResultsPhase.failure,
          QueryResultsPhase.failure,
        ]);
        input.add('/cancel\r');
        expect(await prompt, isA<Cancelled<String>>());
        await input.close();
      },
    );

    test(
      'no response is projected or rendered after the prompt closes',
      () async {
        final requests = PendingRequests<List<String>>();
        final input = StreamController<String>();
        final output = StringBuffer();
        final transcript = TextInputTranscript();
        final prompt = Autocomplete('Name', suggestions: requests.record)
            .prompt(
              source: _scripted(input.stream, output, transcript: transcript),
              mode: PromptMode.linear,
            );

        input.add('Ada\r/cancel\r');
        expect(await prompt, isA<Cancelled<String>>());
        final events = transcript.events.length;
        final painted = output.toString();
        expect(_results(transcript)?.phase, QueryResultsPhase.loading);
        requests.complete('Ada', ['Late']);
        await settle();
        expect(output.toString(), painted);
        expect(transcript.events.length, events);
        expect(_results(transcript)?.phase, QueryResultsPhase.loading);
        await input.close();
      },
    );
  });

  group('component and stage help', () {
    test(
      'every instruction policy keeps help access and complete help',
      () async {
        for (final policy in InstructionDisplay.values) {
          final out = StringBuffer();
          final result =
              await SearchSelect('Fruit', [
                Choice('a', 'Apple'),
              ], instructions: policy).prompt(
                source: _scripted(Stream.value('/help\r/cancel\r'), out),
                mode: PromptMode.linear,
              );
          expect(result, isA<Cancelled<String>>(), reason: policy.name);
          expect(out.toString(), contains('/help'), reason: policy.name);
          expect(
            _painted(out),
            contains('Help: SearchSelect query.'),
            reason: policy.name,
          );
          expect(
            _painted(out),
            contains('Enter opens matching results without accepting'),
            reason: policy.name,
          );
        }
      },
    );

    test('hidden rich instructions still reach complete stage help', () async {
      final input = StreamController<String>();
      final out = StringBuffer();
      final transcript = TextInputTranscript();
      final prompt =
          Autocomplete(
            'Name',
            suggestions: (_) => ['Ada'],
            instructions: InstructionDisplay.hidden,
          ).prompt(
            source: _scripted(input.stream, out, transcript: transcript),
            mode: PromptMode.rich,
          );
      input.add('A\x14');
      await settleUntil(() => _helpEvents(transcript) == 1);
      final painted = _painted(out);
      expect(painted, contains('Ctrl+T'));
      expect(painted, contains('Help: Autocomplete.'));
      expect(painted, contains('Tab accepts a candidate'));
      input.add('\x1b');
      await awaitLoneEscape();
      input.add('\r');
      expect((await prompt as Accepted<String>).value, 'A');
      await input.close();
    });

    test(
      'results help reports loading and retry without implying acceptance',
      () async {
        final requests = PendingRequests<List<Choice<String>>>();
        final input = StreamController<String>();
        final out = StringBuffer();
        final transcript = TextInputTranscript();
        final prompt =
            SearchSelect<String>('Fruit', [
              Choice('a', 'Apple'),
            ], search: requests.record).prompt(
              source: _scripted(input.stream, out, transcript: transcript),
              mode: PromptMode.linear,
            );

        input.add('a\r');
        await settleUntil(() => requests.requested('a'));
        input.add('/help\r');
        await settleUntil(() => _helpEvents(transcript) == 1);
        expect(
          _painted(out),
          contains(
            'Searching; no result can be accepted until the current request completes.',
          ),
        );

        requests.fail('a', StateError('offline'));
        await settleUntil(
          () => _results(transcript)?.phase == QueryResultsPhase.failure,
        );
        input.add('/help\r');
        await settleUntil(() => _helpEvents(transcript) == 2);
        expect(
          _painted(out),
          contains('Search unavailable; editing the query retries it.'),
        );
        input.add('/cancel\r');
        expect(await prompt, isA<Cancelled<String>>());
        await input.close();
      },
    );

    test(
      'results help keeps the focused identity and protected reasons',
      () async {
        final out = StringBuffer();
        final result =
            await SearchSelect('Fruit', [
              Choice('a', 'Apple', disabledReason: 'seasonal'),
              Choice('b', 'Banana'),
            ], defaultValue: 'a').prompt(
              source: _scripted(Stream.value('\r/help\r2\r'), out),
              mode: PromptMode.linear,
            );

        expect((result as Accepted<String>).value, 'b');
        final painted = _painted(out);
        expect(painted, contains('Focused: Apple (unavailable: seasonal).'));
        expect(
          painted,
          contains(
            '1 displayed results are unavailable; accepting one explains its reason.',
          ),
        );
      },
    );

    test(
      'rich results help names traversal, dismissal and current state',
      () async {
        final input = StreamController<String>();
        final out = StringBuffer();
        final transcript = TextInputTranscript();
        final prompt = SearchSelect('Fruit', [Choice('a', 'Apple')]).prompt(
          source: _scripted(input.stream, out, transcript: transcript),
          mode: PromptMode.rich,
        );
        input.add('\r\x14');
        await settleUntil(() => _helpEvents(transcript) == 1);
        final painted = _painted(out);
        expect(painted, contains('Help: SearchSelect results.'));
        expect(painted, contains('1 current results'));
        expect(painted, contains('Focused: Apple.'));
        expect(painted, contains('Escape dismisses help, then cancels'));
        input.add('\x1b');
        await awaitLoneEscape();
        input.add('\r');
        expect((await prompt as Accepted<String>).value, 'a');
        await input.close();
      },
    );

    test(
      'domain guidance distinguishes timezone and command palettes',
      () async {
        final zones = StringBuffer();
        await TimezoneSelect('Zone').prompt(
          source: _scripted(Stream.value('/help\r/cancel\r'), zones),
          mode: PromptMode.linear,
        );
        final zoneHelp = _painted(zones);
        expect(
          zoneHelp,
          contains(
            'the canonical identity is returned and no offset or current time is consulted',
          ),
        );
        expect(zoneHelp, contains('city names and aliases'));
      },
    );

    test(
      'autocomplete help reports the limit, pending state and identity model',
      () async {
        final requests = PendingRequests<List<String>>();
        final input = StreamController<String>();
        final out = StringBuffer();
        final transcript = TextInputTranscript();
        final prompt =
            Autocomplete(
              'Name',
              maxLength: 5,
              suggestions: requests.record,
            ).prompt(
              source: _scripted(input.stream, out, transcript: transcript),
              mode: PromptMode.linear,
            );

        input.add('Ada\r');
        await settleUntil(() => requests.requested('Ada'));
        input.add('/help\r');
        await settleUntil(() => _helpEvents(transcript) == 1);
        final painted = _painted(out);
        expect(painted, contains('Help: Autocomplete results.'));
        expect(
          painted,
          contains('Suggestions are still pending; none can be accepted.'),
        );
        expect(painted, contains('The answer is limited to 5 graphemes.'));
        expect(painted, contains('response-local'));

        requests.complete('Ada', ['Adaline']);
        await settleUntil(
          () => _results(transcript)?.phase == QueryResultsPhase.ready,
        );
        input.add('/submit\r');
        expect((await prompt as Accepted<String>).value, 'Ada');
        await input.close();
      },
    );

    test(
      'help dismissal preserves the query draft and focused result',
      () async {
        final input = StreamController<String>();
        final out = StringBuffer();
        final result = SearchSelect('Fruit', [
          Choice('apple', 'Apple'),
          Choice('pear', 'Pear'),
        ]).prompt(source: _scripted(input.stream, out), mode: PromptMode.rich);
        input.add('pe\x14');
        await settle();
        input.add('\x1b');
        await awaitLoneEscape();
        input.add('\r');
        await settle();
        input.add('\x1b[B\r');
        expect((await result as Accepted<String>).value, 'pear');
        await input.close();
      },
    );

    test('wrappers keep forwarding mode and output profile', () async {
      for (final prompt in <Future<PromptResult<String>> Function()>[
        () => TimezoneSelect('Zone').prompt(
          source: ScriptedInput(const Stream<String>.empty(), StringBuffer()),
          mode: PromptMode.rich,
        ),
      ]) {
        expect(await prompt(), isA<Unavailable<String>>());
      }
    });
  });

  group('deterministic lifecycle and selected-output faults', () {
    test('linear input end while searching writes nothing later', () async {
      final requests = PendingRequests<List<Choice<String>>>();
      final input = StreamController<String>();
      final output = StringBuffer();
      final transcript = TextInputTranscript();
      final prompt =
          SearchSelect<String>('Fruit', [
            Choice('a', 'Apple'),
          ], search: requests.record).prompt(
            source: _scripted(input.stream, output, transcript: transcript),
            mode: PromptMode.linear,
          );
      input.add('a\r');
      await settleUntil(() => requests.requested('a'));
      await input.close();
      expect(await prompt, isA<InputEnded<String>>());
      final painted = output.toString();
      final events = transcript.events.length;
      requests.complete('a', [Choice('a', 'Apple')]);
      await settle();
      expect(output.toString(), painted);
      expect(transcript.events.length, events);
      expect(_results(transcript)?.phase, QueryResultsPhase.loading);
    });

    test(
      'rich input end while suggestions are pending writes nothing later',
      () async {
        final requests = PendingRequests<List<String>>();
        final input = StreamController<String>();
        final output = StringBuffer();
        final transcript = TextInputTranscript();
        final prompt = Autocomplete('Name', suggestions: requests.record)
            .prompt(
              source: _scripted(input.stream, output, transcript: transcript),
              mode: PromptMode.rich,
            );
        input.add('Ada');
        await settleUntil(() => requests.requested('Ada'));
        input.add('\x1a');
        expect(await prompt, isA<InputEnded<String>>());
        final painted = output.toString();
        requests.complete('Ada', ['Adaline']);
        await settle();
        expect(output.toString(), painted);
        expect(_results(transcript)?.phase, QueryResultsPhase.loading);
        await input.close();
      },
    );

    test(
      'cancellation while searching leaves the projection untrusted',
      () async {
        final requests = PendingRequests<List<Choice<String>>>();
        final input = StreamController<String>();
        final output = StringBuffer();
        final transcript = TextInputTranscript();
        final prompt =
            SearchSelect<String>('Fruit', [
              Choice('a', 'Apple'),
            ], search: requests.record).prompt(
              source: _scripted(input.stream, output, transcript: transcript),
              mode: PromptMode.linear,
            );
        input.add('a\r/cancel\r');
        expect(await prompt, isA<Cancelled<String>>());
        final painted = output.toString();
        requests.complete('a', [Choice('a', 'Apple')]);
        await settle();
        expect(output.toString(), painted);
        expect(
          transcript.events.where(
            (event) =>
                event.kind == TextInputPresentationEventKind.results &&
                event.results!.phase == QueryResultsPhase.ready,
          ),
          isEmpty,
        );
        await input.close();
      },
    );

    test(
      'a failed selected output ends the prompt with the original error',
      () async {
        final requests = PendingRequests<List<Choice<String>>>();
        final input = StreamController<String>();
        final sink = SwitchableSink();
        final prompt =
            SearchSelect<String>('Fruit', [
              Choice('a', 'Apple'),
            ], search: requests.record).prompt(
              source: ScriptedInput(
                input.stream,
                sink,
                outputProfile: _richProfile,
              ),
              mode: PromptMode.linear,
            );
        input.add('a\r');
        await settleUntil(() => requests.requested('a'));
        final failure = StateError('selected output failed');
        final accepted = sink.toString();
        sink.failure = failure;

        requests.complete('a', [Choice('a', 'Apple')]);
        await expectLater(prompt, throwsA(same(failure)));
        expect(sink.toString(), accepted);
        await input.close();
      },
    );

    test(
      'dismissed suggestions leave an idle state that cannot accept',
      () async {
        final requests = PendingRequests<List<String>>();
        final input = StreamController<String>();
        final out = StringBuffer();
        final transcript = TextInputTranscript();
        final prompt = Autocomplete('Name', suggestions: requests.record)
            .prompt(
              source: _scripted(input.stream, out, transcript: transcript),
              mode: PromptMode.rich,
            );
        input.add('Ada');
        await settleUntil(() => requests.requested('Ada'));
        requests.complete('Ada', ['Adaline']);
        await settleUntil(
          () => _results(transcript)?.phase == QueryResultsPhase.ready,
        );
        input.add('\x1b');
        await awaitLoneEscape();
        await settleUntil(
          () => _results(transcript)?.phase == QueryResultsPhase.idle,
        );
        final idle = _results(transcript)!;
        expect(idle.notices, contains(QueryResultsNotice.dismissed));
        expect(idle.canAccept, isFalse);
        expect(idle.retryAvailable, isFalse);
        input.add('\r');
        expect((await prompt as Accepted<String>).value, 'Ada');
        await input.close();
      },
    );

    test(
      'background feedback and async results repaint in one session',
      () async {
        final requests = PendingRequests<List<Choice<String>>>();
        final input = StreamController<String>();
        final output = StringBuffer();
        final transcript = TextInputTranscript();
        await TerminalSession.run(
          (session) async {
            final region = session.startFeedbackRegion();
            final prompt = SearchSelect<String>('Fruit', [
              Choice('a', 'Apple'),
            ], search: requests.record).prompt(session: session);
            input.add('a\r');
            await settleUntil(() => requests.requested('a'));
            region.write('Background: contacting index');
            await settle();
            expect(output.toString(), contains('Background: contacting index'));
            requests.complete('a', [Choice('a', 'Apple')]);
            await settleUntil(
              () => _results(transcript)?.phase == QueryResultsPhase.ready,
            );
            expect(output.toString(), contains('1. Apple'));
            expect(output.toString(), contains('Background: contacting index'));
            input.add('1\r');
            expect(((await prompt) as Accepted<String>).value, 'a');
            region.retire();
          },
          source: _scripted(input.stream, output, transcript: transcript),
          mode: PromptMode.linear,
        );
        await input.close();
      },
    );

    test(
      'rich suggestions and background feedback share one session',
      () async {
        final requests = PendingRequests<List<String>>();
        final input = StreamController<String>();
        final output = StringBuffer();
        final transcript = TextInputTranscript();
        await TerminalSession.run(
          (session) async {
            final region = session.startFeedbackRegion();
            final prompt = Autocomplete(
              'Name',
              suggestions: requests.record,
            ).prompt(session: session);
            input.add('Ada');
            await settleUntil(() => requests.requested('Ada'));
            region.write('Background: loading index');
            await settle();
            requests.complete('Ada', ['Adaline']);
            await settleUntil(
              () => _results(transcript)?.phase == QueryResultsPhase.ready,
            );
            expect(output.toString(), contains('Background: loading index'));
            expect(output.toString(), contains('1 suggestions; none active.'));
            input.add('\t\r');
            expect(((await prompt) as Accepted<String>).value, 'Adaline');
            region.retire();
          },
          source: _scripted(input.stream, output, transcript: transcript),
          mode: PromptMode.rich,
        );
        await input.close();
      },
    );
  });
}
