import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/background_query.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/trelis.dart';

void main() {
  test(
    'a valid query beats a passive hint and explicit choice beats a query',
    () async {
      final events = <String>[];
      final sink = _QuerySink(events);
      final input = StreamController<String>();
      final profile = _interactiveProfile();
      final owner = ThemeSession(
        environment: _environment(input.stream, sink, events, profile: profile),
        colorFacts: ColorDetectionFacts(
          outputProfile: profile,
          passiveBackground: BackgroundObservation.light,
        ),
        onResolved: (_) async => events.add('callback'),
      );

      final pending = owner.prompt((handle) async {
        expect(handle.colors.background, BackgroundVariant.dark);
        sink.write('prompt');
        return Accepted('ok');
      });
      await sink.firstQuery.future;
      input.add('\x1b]11;rgb:0000/0000/0000\x07');
      await input.close();

      expect(await pending, isA<Accepted<String>>());
      expect(events, [
        'acquire',
        'query',
        'callback',
        'write:prompt',
        'restore',
      ]);

      final explicitEvents = <String>[];
      final explicitSink = _QuerySink(explicitEvents);
      final explicitProfile = _interactiveProfile();
      final explicit = ThemeSession(
        environment: _environment(
          const Stream<String>.empty(),
          explicitSink,
          explicitEvents,
          profile: explicitProfile,
        ),
        colors: const ColorPreferences(background: BackgroundPreference.light),
        colorFacts: ColorDetectionFacts(
          outputProfile: explicitProfile,
          passiveBackground: BackgroundObservation.dark,
        ),
      );

      final explicitResult = await explicit.prompt((handle) async {
        expect(handle.colors.background, BackgroundVariant.light);
        return Accepted('explicit');
      });
      expect(explicitResult, isA<Accepted<String>>());
      expect(explicitSink.writes, isEmpty);
    },
  );

  test(
    'disabled, NO_COLOR, no-depth and redirected output emit no query',
    () async {
      final cases = [
        _SuppressionCase(
          'disabled',
          profile: _interactiveProfile(),
          colors: const ColorPreferences(allowBackgroundQuery: false),
        ),
        _SuppressionCase(
          'NO_COLOR',
          profile: _interactiveProfile(),
          environment: const {'NO_COLOR': '1'},
        ),
        _SuppressionCase(
          'no colour depth',
          profile: _interactiveProfile(colorDepth: ColorDepth.none),
        ),
        _SuppressionCase(
          'redirected output',
          profile: _interactiveProfile(cursor: CapabilitySupport.unsupported),
          supportsRich: false,
        ),
      ];

      for (final testCase in cases) {
        final events = <String>[];
        final sink = _QuerySink(events);
        final owner = ThemeSession(
          environment: _environment(
            const Stream<String>.empty(),
            sink,
            events,
            profile: testCase.profile,
            environment: testCase.environment,
            supportsRich: testCase.supportsRich,
          ),
          colors: testCase.colors,
          colorFacts: ColorDetectionFacts(
            outputProfile: testCase.profile,
            passiveBackground: BackgroundObservation.light,
          ),
        );

        final result = await owner.prompt((handle) async {
          expect(
            handle.colors.background,
            BackgroundVariant.light,
            reason: testCase.name,
          );
          return Accepted(testCase.name);
        });

        expect(result, isA<Accepted<String>>(), reason: testCase.name);
        expect(sink.text, isEmpty, reason: testCase.name);
      }
    },
  );

  test(
    'prompt-first waits for the timeout before callback and output',
    () async {
      final events = <String>[];
      final sink = _QuerySink(events);
      final profile = _interactiveProfile();
      final owner = ThemeSession(
        environment: _environment(
          StreamController<String>().stream,
          sink,
          events,
          profile: profile,
        ),
        colorFacts: ColorDetectionFacts(
          outputProfile: profile,
          passiveBackground: BackgroundObservation.light,
        ),
        onResolved: (_) async => events.add('callback'),
      );

      BackgroundVariant? seen;
      final pending = owner.prompt((handle) async {
        seen = handle.colors.background;
        sink.write('prompt');
        return Accepted('ok');
      });
      await sink.firstQuery.future;
      expect(events, ['acquire', 'query']);

      expect(await pending, isA<Accepted<String>>());
      expect(seen, BackgroundVariant.light);
      expect(events, [
        'acquire',
        'query',
        'callback',
        'write:prompt',
        'restore',
      ]);
    },
  );

  test(
    'feedback-first waits for a valid query before callback and output',
    () async {
      final events = <String>[];
      final sink = _QuerySink(events);
      final input = StreamController<String>();
      final profile = _interactiveProfile();
      final owner = ThemeSession(
        environment: _environment(input.stream, sink, events, profile: profile),
        colorFacts: ColorDetectionFacts(
          outputProfile: profile,
          passiveBackground: BackgroundObservation.dark,
        ),
        onResolved: (_) async => events.add('callback'),
      );

      BackgroundVariant? seen;
      final pending = owner.feedback((handle) async {
        seen = handle.colors.background;
        sink.write('feedback');
        return 'started';
      });
      await sink.firstQuery.future;
      expect(events, ['acquire', 'query']);
      input.add('\x1b]11;rgb:ffff/ffff/ffff\x07');

      expect(await pending, 'started');
      expect(seen, BackgroundVariant.light);
      expect(events, [
        'acquire',
        'query',
        'callback',
        'write:feedback',
        'restore',
      ]);
      await input.close();
    },
  );

  test('a query write failure falls back before the callback', () async {
    final events = <String>[];
    final failure = StateError('cannot write query');
    final sink = _QuerySink(events, queryFailure: failure);
    final profile = _interactiveProfile();
    BackgroundVariant? seen;
    final owner = ThemeSession(
      environment: _environment(
        const Stream<String>.empty(),
        sink,
        events,
        profile: profile,
      ),
      colorFacts: ColorDetectionFacts(
        outputProfile: profile,
        passiveBackground: BackgroundObservation.light,
      ),
      onResolved: (_) async => events.add('callback'),
    );

    final result = await owner.prompt((handle) async {
      seen = handle.colors.background;
      return Accepted('ok');
    });

    expect(result, isA<Accepted<String>>());
    expect(seen, BackgroundVariant.light);
    expect(events, ['acquire', 'query', 'callback', 'restore']);
  });

  test(
    'one query per active period is cached and later periods re-query',
    () async {
      final events = <String>[];
      final sink = _QuerySink(events);
      var listens = 0;
      var cancels = 0;
      final input = StreamController<String>.broadcast(
        onListen: () => listens++,
        onCancel: () => cancels++,
      );
      final profile = _interactiveProfile();
      final owner = ThemeSession(
        environment: _environment(input.stream, sink, events, profile: profile),
        colorFacts: ColorDetectionFacts(
          outputProfile: profile,
          passiveBackground: BackgroundObservation.dark,
        ),
      );
      final started = Completer<void>();
      final release = Completer<void>();

      final first = owner.prompt((handle) async {
        expect(handle.colors.background, BackgroundVariant.dark);
        started.complete();
        await release.future;
        return Accepted('first');
      });
      await sink.firstQuery.future;
      input.add('\x1b]11;rgb:0000/0000/0000\x07');
      await started.future;

      await owner.feedback((handle) async {
        expect(handle.colors.background, BackgroundVariant.dark);
        return null;
      });
      expect(sink.queryCount, 1);
      expect(listens, 1);

      release.complete();
      await first;
      expect(cancels, 1);

      final secondQuery = sink.nextQuery;
      final second = owner.prompt((handle) async {
        expect(handle.colors.background, BackgroundVariant.light);
        return Accepted('second');
      });
      await secondQuery;
      input.add('\x1b]11;rgb:ffff/ffff/ffff\x07');

      expect(await second, isA<Accepted<String>>());
      expect(sink.queryCount, 2);
      expect(listens, 2);
      await input.close();
    },
  );
}

final class _QuerySink implements StringSink {
  _QuerySink(this.events, {this.queryFailure});

  final List<String> events;
  final Object? queryFailure;
  final _buffer = StringBuffer();
  final firstQuery = Completer<void>();
  final _queries = StreamController<void>.broadcast();
  var queryCount = 0;

  String get text => _buffer.toString();

  List<String> get writes =>
      events.where((event) => event.startsWith('write:')).toList();

  Future<void> get nextQuery => _queries.stream.first;

  @override
  void write(Object? object) {
    final value = object.toString();
    _buffer.write(value);
    if (value == osc11BackgroundRequest) {
      queryCount++;
      events.add('query');
      if (!firstQuery.isCompleted) firstQuery.complete();
      _queries.add(null);
      final failure = queryFailure;
      if (failure != null) {
        Error.throwWithStackTrace(failure, StackTrace.empty);
      }
    } else {
      events.add('write:$value');
    }
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    for (final object in objects) {
      write(object);
      if (separator.isNotEmpty) write(separator);
    }
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) {
    write(object);
    write('\n');
  }
}

final class _SuppressionCase {
  const _SuppressionCase(
    this.name, {
    required this.profile,
    this.colors = const ColorPreferences(),
    this.environment = const <String, String?>{},
    this.supportsRich = true,
  });

  final String name;
  final ColorPreferences colors;
  final Map<String, String?> environment;
  final OutputProfile profile;
  final bool supportsRich;
}

final class _Adapter implements TerminalIo {
  _Adapter(
    this.input,
    this.output,
    this.events, {
    this.environment = const <String, String?>{},
    this.acquireError,
    this.supportsRich = true,
  });

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  @override
  final Map<String, String?> environment;
  final List<String> events;
  final Object? acquireError;
  @override
  final bool supportsRich;

  @override
  TerminalLease acquire() {
    events.add('acquire');
    final failure = acquireError;
    if (failure != null) {
      Error.throwWithStackTrace(failure, StackTrace.empty);
    }
    return TerminalLease(() => events.add('restore'));
  }
}

OutputProfile _interactiveProfile({
  ColorDepth colorDepth = ColorDepth.rgb,
  CapabilitySupport cursor = CapabilitySupport.supported,
}) => OutputProfile(
  cursor: cursor,
  colorDepth: colorDepth,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

TerminalEnvironment _environment(
  Stream<String> input,
  _QuerySink sink,
  List<String> events, {
  OutputProfile? profile,
  Map<String, String?> environment = const <String, String?>{},
  Object? acquireError,
  bool supportsRich = true,
}) => TerminalEnvironment.custom(
  adapter: _Adapter(
    input,
    sink,
    events,
    environment: environment,
    acquireError: acquireError,
    supportsRich: supportsRich,
  ),
  profile: profile ?? _interactiveProfile(),
);
