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
import 'presentation.dart' show DisplayText;
import 'prompt_structure.dart' show PromptStructure;
import 'state_help_presentation.dart'
    show
        ComponentRoute,
        PresentationMode,
        compactHint,
        composePromptPresentation;
import 'terminal_io.dart';
import 'text_input.dart'
    show InstructionDisplay, Password, PromptMode, PromptResult, TextInput;
import 'theme_session.dart';

final class ThemeTextInputTracer {
  ThemeTextInputTracer(
    this.label, {
    required TerminalEnvironment io,
    this.initialValue = '',
    this.required = false,
    this.validate,
    this.maxLength,
    this.secret = false,
    this.mask = false,
    this.instructions = InstructionDisplay.themeDefault,
    this.colors = const ComponentColors(),
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    this.structure = PromptStructure.plain,
    this.palettes = ThemePaletteDefaults.terminalNative,
  }) : _owner = ThemeSession(
         environment: io,
         colors: themeColors,
         interaction: interaction,
         onResolved: onResolved,
         factsForPeriod: factsForPeriod,
         palettes: palettes,
       );

  final String label;
  final String initialValue;
  final bool required;
  final String? Function(String)? validate;
  final int? maxLength;
  final bool secret;
  final bool mask;
  final InstructionDisplay instructions;
  final ComponentColors colors;

  /// The structure this tracer renders, fixed by the owning theme.
  final PromptStructure structure;

  /// The owning theme's adaptive light/dark defaults.
  final ThemePaletteDefaults palettes;

  final ThemeSession _owner;

  /// Restoration failures retained after a successful primary operation.
  List<Object> get cleanupFailures => _owner.cleanupFailures;

  Future<PromptResult<String>> prompt() => _owner.prompt((handle) {
    final palette = _componentPalette(handle).palette;
    final mode = handle.interaction.screenReader
        ? PresentationMode.screenReader
        : handle.interaction.mode == PromptMode.rich
        ? PresentationMode.rich
        : PresentationMode.linear;
    if (mode == PresentationMode.screenReader) {
      final presentation = composePromptPresentation(
        mode: mode,
        prompt: DisplayText.from(label).value,
        essential: DisplayText.from('$label entry.').value,
        hint: compactHint(
          mode: mode,
          component: secret ? ComponentRoute.secret : ComponentRoute.standard,
          primaryAction: 'Enter submits',
          shortPrimaryAction: 'Enter',
        ),
      );
      handle.session.presentText(presentation.essentialBefore!);
    }
    if (secret) {
      return Password(
        label,
        initialValue: initialValue,
        required: required,
        validate: validate,
        mask: mask,
        instructions: instructions,
        colors: palette,
        structure: structure,
      ).prompt(session: handle.session);
    }
    return TextInput(
      label,
      initialValue: initialValue,
      required: required,
      validate: validate,
      maxLength: maxLength,
      instructions: instructions,
      colors: palette,
      structure: structure,
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
