/// Internal Plain presentation seam.
///
/// It drives real components through the theme-owned session while keeping the
/// existing static factories buildable. App preferences, background detection
/// and I/O stay on the theme; a component call can only replace or layer its
/// palette. Nothing in this library is exported from the public barrel.
library;

import 'dart:async';

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/prompt_structure.dart';
import 'package:trelis/src/terminal_io.dart';
import 'package:trelis/src/text_input.dart'
    show Choice, InstructionDisplay, PromptResult, Select, TextInputTranscript;
import 'package:trelis/src/text_input_tracer.dart';
import 'package:trelis/src/theme_session.dart';

import 'plain_sepia_palettes.dart';

/// The pre-cutover internal owner for Plain's adaptive presentation.
final class PlainAdaptivePresentation {
  PlainAdaptivePresentation({
    required this.io,
    this.colors = const ColorPreferences(),
    this.interaction = const InteractionPreferences(),
  });

  final TerminalEnvironment io;
  final ColorPreferences colors;
  final InteractionPreferences interaction;

  /// Places Plain's defaults at the application palette layer for this owner.
  ///
  /// The shared resolver still applies the reviewed order: these variant
  /// palettes are replaced or layered by the application, then a component
  /// whole palette replaces the complete effective application palette before
  /// its own roles apply. No component declaration reaches background choice,
  /// detection or I/O.
  ColorPreferences get _themeColors => ColorPreferences(
    background: colors.background,
    allowBackgroundQuery: colors.allowBackgroundQuery,
    colors: ComponentColors(
      lightPalette:
          colors.colors.lightPalette ??
          colors.colors.palette ??
          PlainSepiaPalettes.light,
      darkPalette:
          colors.colors.darkPalette ??
          colors.colors.palette ??
          PlainSepiaPalettes.dark,
      roles: colors.colors.roles,
      lightRoles: colors.colors.lightRoles,
      darkRoles: colors.colors.darkRoles,
    ),
  );

  /// Resolves this owner's palette for [facts] without touching the terminal.
  ResolvedColors resolve({
    ColorDetectionFacts facts = const ColorDetectionFacts(),
    ComponentColors? component,
  }) => resolvePlainColors(
    facts: facts,
    preferences: _themeColors,
    component: component,
  );

  /// Runs a real Plain text input through the theme-owned tracer.
  Future<PromptResult<String>> textInput(
    String label, {
    String initialValue = '',
    bool required = false,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    ComponentColors colors = const ComponentColors(),
    TextInputTranscript? transcript,
  }) => ThemeTextInputTracer(
    label,
    io: io,
    initialValue: initialValue,
    required: required,
    instructions: instructions,
    colors: colors,
    themeColors: _themeColors,
    interaction: interaction,
  ).prompt();

  /// Runs a real Plain choice component through the theme-owned session.
  Future<PromptResult<T>> select<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    ComponentColors colors = const ComponentColors(),
  }) {
    final owner = ThemeSession(
      environment: io,
      colors: _themeColors,
      interaction: interaction,
    );
    return owner.prompt((handle) {
      final palette = _componentPalette(
        handle.colors,
        colors,
        handle.environment,
      );
      return Select<T>(
        label,
        choices,
        defaultValue: defaultValue,
        structure: PromptStructure.plain,
        instructions: instructions,
        colors: palette.palette,
      ).prompt(session: handle.session);
    });
  }

  /// Layers a component override over the palette the period already resolved.
  ///
  /// The owner has chosen the background and applied app preferences, so those
  /// decisions are carried forward rather than resolved twice.
  ResolvedColors _componentPalette(
    ResolvedColors period,
    ComponentColors component,
    TerminalEnvironment environment,
  ) {
    final background = switch (period.background) {
      BackgroundVariant.light => BackgroundPreference.light,
      BackgroundVariant.dark => BackgroundPreference.dark,
    };
    return resolveColors(
      facts: ColorDetectionFacts(
        outputProfile: period.outputProfile,
        noColor: environment.environment['NO_COLOR'],
      ),
      lightDefault: period.palette,
      darkDefault: period.palette,
      preferences: ColorPreferences(background: background),
      component: component,
    );
  }
}
