import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/testing/compat_api.dart';

final _richOutput = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

const _linearOutput = OutputProfile();

typedef _PreferenceCase = ({
  String name,
  InteractionPreferences preferences,
  OutputProfile output,
  PromptMode expectedMode,
  bool expectedScreenReader,
  bool expectConflict,
});

typedef _HintCase = ({
  String name,
  InteractionPreferences preferences,
  ScreenReaderObservation applicationHint,
  ScreenReaderObservation nativeHint,
  TerminalLocality locality,
  bool interactive,
  PromptMode expectedMode,
  bool expectedScreenReader,
});

typedef _OutcomeCase = ({
  String name,
  InteractionPreferences preferences,
  InteractionFacts facts,
  bool expectConflict,
  bool expectUnavailable,
});

void main() {
  final preferenceCases = <_PreferenceCase>[
    (
      name: 'automatic interaction uses rich on a capable output',
      preferences: const InteractionPreferences(),
      output: _richOutput,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
      expectConflict: false,
    ),
    (
      name:
          'automatic interaction falls back to linear without rich capability',
      preferences: const InteractionPreferences(),
      output: _linearOutput,
      expectedMode: PromptMode.linear,
      expectedScreenReader: false,
      expectConflict: false,
    ),
    (
      name: 'explicit rich stays requested when rich is unsupported',
      preferences: const InteractionPreferences(mode: PromptMode.rich),
      output: _linearOutput,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
      expectConflict: false,
    ),
    (
      name: 'explicit linear stays linear on a rich-capable output',
      preferences: const InteractionPreferences(mode: PromptMode.linear),
      output: _richOutput,
      expectedMode: PromptMode.linear,
      expectedScreenReader: false,
      expectConflict: false,
    ),
    (
      name: 'explicit screen reader on selects linear',
      preferences: const InteractionPreferences(
        screenReader: ScreenReaderPreference.on,
      ),
      output: _richOutput,
      expectedMode: PromptMode.linear,
      expectedScreenReader: true,
      expectConflict: false,
    ),
    (
      name: 'explicit screen reader off permits automatic rich',
      preferences: const InteractionPreferences(
        screenReader: ScreenReaderPreference.off,
      ),
      output: _richOutput,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
      expectConflict: false,
    ),
    (
      name: 'explicit screen reader on with explicit rich is a conflict',
      preferences: const InteractionPreferences(
        mode: PromptMode.rich,
        screenReader: ScreenReaderPreference.on,
      ),
      output: _richOutput,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
      expectConflict: true,
    ),
  ];

  for (final entry in preferenceCases) {
    test(entry.name, () {
      final result = resolveInteraction(
        preferences: entry.preferences,
        facts: InteractionFacts(output: entry.output),
      );

      if (entry.expectConflict) {
        expect(result, isA<InteractionConflict>());
        expect((result as InteractionConflict).reason, isNotEmpty);
        return;
      }
      expect(result, isA<ResolvedInteraction>());
      final resolved = result as ResolvedInteraction;
      expect(resolved.mode, entry.expectedMode);
      expect(resolved.screenReader, entry.expectedScreenReader);
    });
  }

  final hintCases = <_HintCase>[
    (
      name: 'positive application hint enables automatic linear reader mode',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.positive,
      nativeHint: ScreenReaderObservation.unknown,
      locality: TerminalLocality.unknown,
      interactive: false,
      expectedMode: PromptMode.linear,
      expectedScreenReader: true,
    ),
    (
      name: 'negative application hint leaves automatic rich unchanged',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.negative,
      nativeHint: ScreenReaderObservation.unknown,
      locality: TerminalLocality.unknown,
      interactive: false,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
    ),
    (
      name: 'unknown application hint leaves automatic rich unchanged',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.unknown,
      nativeHint: ScreenReaderObservation.unknown,
      locality: TerminalLocality.unknown,
      interactive: false,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
    ),
    (
      name: 'failed application hint does not block automatic rich',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.failed,
      nativeHint: ScreenReaderObservation.unknown,
      locality: TerminalLocality.unknown,
      interactive: false,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
    ),
    (
      name:
          'eligible positive native hint enables automatic linear reader mode',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.unknown,
      nativeHint: ScreenReaderObservation.positive,
      locality: TerminalLocality.local,
      interactive: true,
      expectedMode: PromptMode.linear,
      expectedScreenReader: true,
    ),
    (
      name: 'positive native hint in a noninteractive session is ineligible',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.unknown,
      nativeHint: ScreenReaderObservation.positive,
      locality: TerminalLocality.local,
      interactive: false,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
    ),
    (
      name: 'positive native hint in a remote session is ineligible',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.unknown,
      nativeHint: ScreenReaderObservation.positive,
      locality: TerminalLocality.remote,
      interactive: true,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
    ),
    (
      name: 'positive native hint in an ambiguous session is ineligible',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.unknown,
      nativeHint: ScreenReaderObservation.positive,
      locality: TerminalLocality.ambiguous,
      interactive: true,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
    ),
    (
      name: 'positive native hint with unknown locality is ineligible',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.unknown,
      nativeHint: ScreenReaderObservation.positive,
      locality: TerminalLocality.unknown,
      interactive: true,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
    ),
    (
      name: 'negative native hint does not veto a positive application hint',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.positive,
      nativeHint: ScreenReaderObservation.negative,
      locality: TerminalLocality.local,
      interactive: true,
      expectedMode: PromptMode.linear,
      expectedScreenReader: true,
    ),
    (
      name: 'failed native hint does not veto a positive application hint',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.positive,
      nativeHint: ScreenReaderObservation.failed,
      locality: TerminalLocality.local,
      interactive: true,
      expectedMode: PromptMode.linear,
      expectedScreenReader: true,
    ),
    (
      name: 'negative application hint does not veto an eligible native hint',
      preferences: const InteractionPreferences(),
      applicationHint: ScreenReaderObservation.negative,
      nativeHint: ScreenReaderObservation.positive,
      locality: TerminalLocality.local,
      interactive: true,
      expectedMode: PromptMode.linear,
      expectedScreenReader: true,
    ),
    (
      name: 'explicit screen reader off defeats both affirmative hints',
      preferences: const InteractionPreferences(
        screenReader: ScreenReaderPreference.off,
      ),
      applicationHint: ScreenReaderObservation.positive,
      nativeHint: ScreenReaderObservation.positive,
      locality: TerminalLocality.local,
      interactive: true,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
    ),
    (
      name: 'explicit rich defeats automatic detection from either hint',
      preferences: const InteractionPreferences(mode: PromptMode.rich),
      applicationHint: ScreenReaderObservation.positive,
      nativeHint: ScreenReaderObservation.positive,
      locality: TerminalLocality.local,
      interactive: true,
      expectedMode: PromptMode.rich,
      expectedScreenReader: false,
    ),
    (
      name: 'explicit linear with reader off ignores affirmative hints',
      preferences: const InteractionPreferences(
        mode: PromptMode.linear,
        screenReader: ScreenReaderPreference.off,
      ),
      applicationHint: ScreenReaderObservation.positive,
      nativeHint: ScreenReaderObservation.positive,
      locality: TerminalLocality.local,
      interactive: true,
      expectedMode: PromptMode.linear,
      expectedScreenReader: false,
    ),
  ];

  for (final entry in hintCases) {
    test(entry.name, () {
      final result = resolveInteraction(
        preferences: InteractionPreferences(
          mode: entry.preferences.mode,
          screenReader: entry.preferences.screenReader,
          applicationHint: entry.applicationHint,
        ),
        facts: InteractionFacts(
          output: _richOutput,
          nativeHint: entry.nativeHint,
          locality: entry.locality,
          interactive: entry.interactive,
        ),
      );

      expect(result, isA<ResolvedInteraction>());
      final resolved = result as ResolvedInteraction;
      expect(resolved.mode, entry.expectedMode);
      expect(resolved.screenReader, entry.expectedScreenReader);
    });
  }

  final outcomeCases = <_OutcomeCase>[
    (
      name: 'injected unavailable interaction is a distinct outcome',
      preferences: const InteractionPreferences(),
      facts: const InteractionFacts(
        output: OutputProfile(),
        interactionAvailable: false,
      ),
      expectConflict: false,
      expectUnavailable: true,
    ),
    (
      name: 'unavailable explicit rich is not a configuration conflict',
      preferences: const InteractionPreferences(mode: PromptMode.rich),
      facts: const InteractionFacts(
        output: OutputProfile(),
        interactionAvailable: false,
      ),
      expectConflict: false,
      expectUnavailable: true,
    ),
    (
      name: 'unavailable with affirmative hints is still not a conflict',
      preferences: const InteractionPreferences(
        applicationHint: ScreenReaderObservation.positive,
      ),
      facts: const InteractionFacts(
        nativeHint: ScreenReaderObservation.positive,
        locality: TerminalLocality.local,
        interactive: true,
        interactionAvailable: false,
      ),
      expectConflict: false,
      expectUnavailable: true,
    ),
    (
      name: 'a conflicting preference remains a conflict when unavailable',
      preferences: const InteractionPreferences(
        mode: PromptMode.rich,
        screenReader: ScreenReaderPreference.on,
      ),
      facts: const InteractionFacts(interactionAvailable: false),
      expectConflict: true,
      expectUnavailable: false,
    ),
  ];

  for (final entry in outcomeCases) {
    test(entry.name, () {
      final result = resolveInteraction(
        preferences: entry.preferences,
        facts: entry.facts,
      );

      if (entry.expectUnavailable) {
        expect(result, isA<InteractionUnavailable>());
        expect((result as InteractionUnavailable).reason, isNotEmpty);
      } else if (entry.expectConflict) {
        expect(result, isA<InteractionConflict>());
      } else {
        expect(result, isA<ResolvedInteraction>());
      }
    });
  }

  test('a runnable screen-reader result is always linear', () {
    final results = <InteractionResolution>[
      for (final entry in preferenceCases)
        resolveInteraction(
          preferences: entry.preferences,
          facts: InteractionFacts(output: entry.output),
        ),
      for (final entry in hintCases)
        resolveInteraction(
          preferences: InteractionPreferences(
            mode: entry.preferences.mode,
            screenReader: entry.preferences.screenReader,
            applicationHint: entry.applicationHint,
          ),
          facts: InteractionFacts(
            output: _richOutput,
            nativeHint: entry.nativeHint,
            locality: entry.locality,
            interactive: entry.interactive,
          ),
        ),
    ];
    for (final result in results.whereType<ResolvedInteraction>()) {
      if (result.screenReader) {
        expect(result.mode, PromptMode.linear);
      }
    }
  });

  test('the resolved value rejects screen-reader rich interaction', () {
    expect(
      () => ResolvedInteraction(mode: PromptMode.rich, screenReader: true),
      throwsArgumentError,
    );
  });
}
