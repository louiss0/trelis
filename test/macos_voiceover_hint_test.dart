import 'dart:async';
import 'dart:ffi';

import 'package:test/test.dart';
import 'package:trelis/trelis.dart';
import 'package:trelis/src/hint_observations.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/macos_voiceover_hint.dart';
import 'package:trelis/src/theme_session.dart';

void main() {
  test('the VoiceOver hint stays off without touching native calls', () {
    final bridge = _FakeVoiceOverBridge();

    final observation = observeVoiceOver(
      platform: HintPlatform.macos,
      bridge: bridge,
    );

    expect(observation, ScreenReaderObservation.unknown);
    expect(bridge.events, isEmpty);
  });

  test('unsupported platforms never open native libraries', () {
    for (final platform in [
      HintPlatform.windows,
      HintPlatform.linux,
      HintPlatform.unsupported,
    ]) {
      final bridge = _FakeVoiceOverBridge();

      final observation = observeVoiceOver(
        platform: platform,
        enabled: true,
        bridge: bridge,
      );

      expect(observation, ScreenReaderObservation.unknown, reason: '$platform');
      expect(bridge.events, isEmpty, reason: '$platform');
    }
  });

  test('a VoiceOver positive state is observed with balanced lifetime', () {
    final bridge = _FakeVoiceOverBridge(enabledByte: 1);

    final observation = observeVoiceOver(
      platform: HintPlatform.macos,
      enabled: true,
      bridge: bridge,
    );

    expect(observation, ScreenReaderObservation.positive);
    expect(bridge.events, contains('class:NSWorkspace'));
    expect(bridge.events, contains('selector:isVoiceOverEnabled'));
    expect(
      bridge.events.indexOf('pool:push'),
      lessThan(bridge.events.indexOf('workspace')),
    );
    expect(
      bridge.events.indexOf('read'),
      lessThan(bridge.events.indexOf('pool:pop')),
    );
    expect(
      bridge.events.where((event) => event.startsWith('close:')),
      hasLength(2),
    );
    expect(bridge.events.last, startsWith('close:'));
  });

  test('a VoiceOver negative state is observed without blocking', () {
    final bridge = _FakeVoiceOverBridge(enabledByte: 0);

    final observation = observeVoiceOver(
      platform: HintPlatform.macos,
      enabled: true,
      bridge: bridge,
    );

    expect(observation, ScreenReaderObservation.negative);
    expect(bridge.events, contains('pool:pop'));
    expect(
      bridge.events.where((event) => event.startsWith('close:')),
      hasLength(2),
    );
  });

  test('unavailable symbols and absent selectors stay unknown', () {
    final bridges = [
      _FakeVoiceOverBridge(missingClass: true),
      _FakeVoiceOverBridge(missingSelector: true),
      _FakeVoiceOverBridge(missingWorkspace: true),
      _FakeVoiceOverBridge(responds: false),
    ];

    for (final bridge in bridges) {
      final observation = observeVoiceOver(
        platform: HintPlatform.macos,
        enabled: true,
        bridge: bridge,
      );

      expect(observation, ScreenReaderObservation.unknown);
      expect(
        bridge.events.where((event) => event == 'pool:push'),
        hasLength(bridge.events.where((event) => event == 'pool:pop').length),
        reason: bridge.events.toString(),
      );
      expect(
        bridge.events.where((event) => event.startsWith('close:')),
        hasLength(2),
        reason: bridge.events.toString(),
      );
    }
  });

  test('failed calls and invalid bytes stay unknown without leaking', () {
    for (final failure in [
      'open',
      'class',
      'selector',
      'pool',
      'workspace',
      'responds',
      'read',
      'close',
      'pop',
    ]) {
      final bridge = _FakeVoiceOverBridge(failureAt: failure);
      final observation = observeVoiceOver(
        platform: HintPlatform.macos,
        enabled: true,
        bridge: bridge,
      );

      expect(observation, ScreenReaderObservation.unknown, reason: failure);
      expect(
        bridge.events.where((event) => event == 'pool:push'),
        hasLength(bridge.events.where((event) => event == 'pool:pop').length),
        reason: failure,
      );
    }

    final invalid = _FakeVoiceOverBridge(enabledByte: 2);
    expect(
      observeVoiceOver(
        platform: HintPlatform.macos,
        enabled: true,
        bridge: invalid,
      ),
      ScreenReaderObservation.unknown,
    );
    expect(invalid.events, contains('pool:pop'));
    expect(
      invalid.events.where((event) => event.startsWith('close:')),
      hasLength(2),
    );
  });

  test('an eligible local VoiceOver positive selects linear mode', () async {
    final bridge = _FakeVoiceOverBridge(enabledByte: 1);
    final observations = _voiceOverObservations(
      bridge: bridge,
      enabled: true,
      localSessionAttested: true,
    );

    final facts = await observations.facts(
      output: _richOutput,
      environment: const <String, String?>{},
    );
    final resolution = resolveInteraction(
      preferences: const InteractionPreferences(),
      facts: facts,
    );

    expect(facts.nativeHint, ScreenReaderObservation.positive);
    expect(facts.locality, TerminalLocality.local);
    expect(resolution, isA<ResolvedInteraction>());
    expect((resolution as ResolvedInteraction).mode, PromptMode.linear);
    expect(resolution.screenReader, isTrue);
  });

  test('ambiguous locality blocks the native hint', () async {
    for (final entry in [
      (environment: const <String, String?>{}, attested: false),
      (
        environment: const <String, String?>{
          'SSH_CONNECTION': '10.0.0.1 1 10.0.0.2 22',
        },
        attested: true,
      ),
      (
        environment: const <String, String?>{
          'TMUX': '/tmp/tmux-1/default,123,0',
        },
        attested: true,
      ),
      (
        environment: const <String, String?>{'container': 'docker'},
        attested: true,
      ),
    ]) {
      final bridge = _FakeVoiceOverBridge(enabledByte: 1);
      final facts = await _voiceOverObservations(
        bridge: bridge,
        enabled: true,
        localSessionAttested: entry.attested,
      ).facts(environment: entry.environment);
      final resolution = resolveInteraction(
        preferences: const InteractionPreferences(),
        facts: facts,
      );

      expect(
        (resolution as ResolvedInteraction).screenReader,
        isFalse,
        reason: entry.environment.toString(),
      );
    }
  });

  test(
    'the default gate and explicit preferences cannot be overridden',
    () async {
      final bridge = _FakeVoiceOverBridge(enabledByte: 1);
      final gated = _voiceOverObservations(
        bridge: bridge,
        localSessionAttested: true,
      );
      final gatedFacts = await gated.facts();
      expect(gatedFacts.nativeHint, ScreenReaderObservation.unknown);
      expect(bridge.events, isEmpty);

      final cases = [
        (
          preferences: const InteractionPreferences(
            screenReader: ScreenReaderPreference.off,
          ),
          expectedScreenReader: false,
          expectedMode: PromptMode.linear,
        ),
        (
          preferences: const InteractionPreferences(mode: PromptMode.rich),
          expectedScreenReader: false,
          expectedMode: PromptMode.rich,
        ),
        (
          preferences: const InteractionPreferences(
            applicationHint: ScreenReaderObservation.positive,
          ),
          expectedScreenReader: true,
          expectedMode: PromptMode.linear,
        ),
      ];
      for (final entry in cases) {
        final resolution = resolveInteraction(
          preferences: entry.preferences,
          facts: gatedFacts,
        );
        final resolved = resolution as ResolvedInteraction;
        expect(
          resolved.screenReader,
          entry.expectedScreenReader,
          reason: '${entry.preferences}',
        );
        expect(
          resolved.mode,
          entry.expectedMode,
          reason: '${entry.preferences}',
        );
      }
    },
  );

  test(
    'a VoiceOver negative does not veto a positive application hint',
    () async {
      final bridge = _FakeVoiceOverBridge(enabledByte: 0);
      final facts = await _voiceOverObservations(
        bridge: bridge,
        enabled: true,
        localSessionAttested: true,
      ).facts();

      final resolution = resolveInteraction(
        preferences: const InteractionPreferences(
          applicationHint: ScreenReaderObservation.positive,
        ),
        facts: facts,
      );

      expect(facts.nativeHint, ScreenReaderObservation.negative);
      expect((resolution as ResolvedInteraction).screenReader, isTrue);
    },
  );

  test('a VoiceOver observation is cached per active period', () async {
    final events = <String>[];
    final bridge = _FakeVoiceOverBridge(enabledByte: 1);
    var probeCalls = 0;
    final observed = <ResolvedInteraction>[];
    final started = Completer<void>();
    final release = Completer<void>();
    final owner = ThemeSession(
      environment: _environment(_RecordingSink(events), events),
      interaction: const InteractionPreferences(),
      hints: _voiceOverObservations(
        bridge: bridge,
        enabled: true,
        localSessionAttested: true,
        onProbe: () => probeCalls++,
      ),
      onResolved: (interaction) async => observed.add(interaction),
    );

    final first = owner.prompt((handle) async {
      started.complete();
      await release.future;
      return Accepted('one');
    });
    await started.future;
    await owner.feedback((handle) async => null);
    expect(probeCalls, 1);
    expect(observed.single.screenReader, isTrue);

    release.complete();
    await first;
    expect(events, contains('restore'));
    expect(owner.resolvedInteraction, isNull);

    bridge.enabledByte = 0;
    final second = await owner.prompt(
      (handle) async => Accepted<String>('two'),
    );

    expect(second, isA<Accepted<String>>());
    expect(probeCalls, 2);
    expect(observed, hasLength(2));
    expect(observed.last.screenReader, isFalse);
  });
}

NativeHintObservations _voiceOverObservations({
  required _FakeVoiceOverBridge bridge,
  bool enabled = macosVoiceOverHintEnabled,
  bool localSessionAttested = false,
  void Function()? onProbe,
}) => NativeHintObservations(
  platform: HintPlatform.macos,
  interactive: true,
  localSessionAttested: localSessionAttested,
  readerProbe: (platform) {
    onProbe?.call();
    return macosVoiceOverReaderProbe(enabled: enabled, bridge: bridge)(
      platform,
    );
  },
);

final _richOutput = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

final class _RecordingSink implements StringSink {
  _RecordingSink(this.events);

  final List<String> events;

  @override
  void write(Object? object) => events.add('write:$object');

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

final class _RecordingTerminal implements TerminalIo {
  _RecordingTerminal(this.input, this.output, this.events);

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final List<String> events;
  @override
  Map<String, String?> get environment => const <String, String?>{};

  @override
  bool get supportsRich => false;

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}

TerminalEnvironment _environment(StringSink output, List<String> events) =>
    TerminalEnvironment.custom(
      adapter: _RecordingTerminal(const Stream<String>.empty(), output, events),
      profile: const OutputProfile(glyphs: GlyphSet.ascii),
    );

final class _FakeVoiceOverBridge implements VoiceOverNativeBridge {
  _FakeVoiceOverBridge({
    this.enabledByte = 1,
    this.responds = true,
    this.missingClass = false,
    this.missingSelector = false,
    this.missingWorkspace = false,
    this.failureAt,
  });

  int enabledByte;
  final bool responds;
  final bool missingClass;
  final bool missingSelector;
  final bool missingWorkspace;
  final String? failureAt;
  final List<String> events = <String>[];

  static final Pointer<Void> _present = Pointer<Void>.fromAddress(1);

  void _fail(String step) {
    if (failureAt == step) throw StateError('failed $step');
  }

  @override
  Object open(String path) {
    events.add('open:$path');
    _fail('open');
    return path;
  }

  @override
  void close(Object library) {
    events.add('close:$library');
    _fail('close');
  }

  @override
  Pointer<Void> findClass(Object runtime, String name) {
    events.add('class:$name');
    _fail('class');
    return missingClass ? nullptr : _present;
  }

  @override
  Pointer<Void> registerSelector(Object runtime, String name) {
    events.add('selector:$name');
    _fail('selector');
    return missingSelector ? nullptr : _present;
  }

  @override
  bool respondsToSelector(
    Object runtime,
    Pointer<Void> object,
    Pointer<Void> respondsSelector,
    Pointer<Void> targetSelector,
  ) {
    events.add('responds');
    _fail('responds');
    return responds;
  }

  @override
  Pointer<Void> sharedWorkspace(
    Object runtime,
    Pointer<Void> workspaceClass,
    Pointer<Void> selector,
  ) {
    events.add('workspace');
    _fail('workspace');
    return missingWorkspace ? nullptr : _present;
  }

  @override
  int readVoiceOverEnabled(
    Object runtime,
    Pointer<Void> workspace,
    Pointer<Void> selector,
  ) {
    events.add('read');
    _fail('read');
    return enabledByte;
  }

  @override
  Object pushAutoreleasePool(Object runtime) {
    _fail('pool');
    events.add('pool:push');
    return 'pool';
  }

  @override
  void popAutoreleasePool(Object runtime, Object pool) {
    events.add('pool:pop');
    _fail('pop');
  }
}
