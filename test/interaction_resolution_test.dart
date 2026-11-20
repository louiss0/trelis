import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/trelis.dart';

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
}
