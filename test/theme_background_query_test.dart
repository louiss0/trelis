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
}

final class _QuerySink implements StringSink {
  _QuerySink(this.events);

  final List<String> events;
  final _buffer = StringBuffer();
  final firstQuery = Completer<void>();
  final _queries = StreamController<void>.broadcast();

  String get text => _buffer.toString();

  List<String> get writes =>
      events.where((event) => event.startsWith('write:')).toList();

  Future<void> get nextQuery => _queries.stream.first;

  @override
  void write(Object? object) {
    final value = object.toString();
    _buffer.write(value);
    print('DEBUG write: $value');
    if (value == osc11BackgroundRequest) {
      events.add('query');
      if (!firstQuery.isCompleted) firstQuery.complete();
      _queries.add(null);
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
