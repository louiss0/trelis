/// Internal end-to-end tracer for one theme-owned text input.
///
/// The tracer captures immutable component configuration, resolves its
/// component colour override inside the owner's active period, and delegates
/// input, selected output and lifecycle to [ThemeSession]. It is deliberately
/// absent from the public export barrel.
library;

import 'dart:async';

import 'color_resolution.dart';
import 'interaction_resolution.dart';
import 'terminal_io.dart';
import 'text_input.dart' show PromptResult, TextInput;
import 'theme_session.dart';

final class ThemeTextInputTracer {
  ThemeTextInputTracer(
    this.label, {
    required TerminalEnvironment io,
    this.initialValue = '',
    this.colors = const ComponentColors(),
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
  }) : _owner = ThemeSession(
         environment: io,
         colors: themeColors,
         interaction: interaction,
         onResolved: onResolved,
         factsForPeriod: factsForPeriod,
       );

  final String label;
  final String initialValue;
  final ComponentColors colors;
  final ThemeSession _owner;

  Future<PromptResult<String>> prompt() => _owner.prompt((handle) {
    return TextInput(
      label,
      initialValue: initialValue,
      colors: _componentPalette(handle).palette,
    ).prompt(session: handle.session);
  });

  /// Starts live feedback that shares this tracer's active period.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
  }) => _owner.startFeedback(start, stop: stop);

  /// Layers the component override over the palette the period resolved.
  ///
  /// The theme owner has already selected the background and applied application
  /// preferences, so those decisions are carried forward rather than resolved
  /// twice. The pure colour resolver still applies the component replacement
  /// and its shared and variant roles.
  ResolvedColors _componentPalette(ThemeSessionHandle handle) {
    final period = handle.colors;
    final background = switch (period.background) {
      BackgroundVariant.light => BackgroundPreference.light,
      BackgroundVariant.dark => BackgroundPreference.dark,
    };
    return resolveColors(
      facts: ColorDetectionFacts(
        outputProfile: period.outputProfile,
        noColor: handle.environment.environment['NO_COLOR'],
      ),
      lightDefault: period.palette,
      darkDefault: period.palette,
      preferences: ColorPreferences(background: background),
      component: colors,
    );
  }
}
