/// Internal theme-owned tree, ordering and search component families.
///
/// Each instance captures immutable component configuration and binds to one
/// [ThemeSession]. The session resolves interaction and colour before the first
/// output and owns the reader, writer and lifecycle; the real components are
/// delegated to with that session, so no second external prompt, reader or
/// invocation-level I/O is introduced. State glyphs, disclosure markers, query
/// identity rules and help come from the shared state/help primitives and are
/// fixed by the theme, not by a prompt invocation. This library is deliberately
/// absent from the public export barrel; the breaking public cutover is a
/// later ticket.
library;

import 'dart:async';

import 'color_resolution.dart';
import 'hint_observations.dart';
import 'interaction_resolution.dart';
import 'output_profile.dart';
import 'prompt_structure.dart';
import 'state_help_presentation.dart'
    show
        ChoicePresentationConfig,
        ChoiceRestriction,
        ComponentRoute,
        PresentationMode,
        SingleSelectionStyle,
        StateGlyphs,
        compactHint,
        composePromptPresentation;
import 'terminal_io.dart';
import 'text_input.dart'
    show InstructionDisplay, PromptResult, TreeSelect, TreeNode;
import 'theme_session.dart';

/// ThemeSession-backed TreeSelect prompt.
final class ThemeTreeSelectPrompt<T> {
  ThemeTreeSelectPrompt(
    this.label,
    List<TreeNode<T>> nodes, {
    required TerminalEnvironment io,
    this.defaultValue,
    T? selectedValue,
    this.isCurrent,
    this.instructions = InstructionDisplay.themeDefault,
    this.supplementaryHelp = const [],
    this.colors = const ComponentColors(),
    this.structure = PromptStructure.plain,
    StateGlyphs glyphs = StateGlyphs.unicode,
    this.selectionStyle = SingleSelectionStyle.circles,
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) : nodes = List.unmodifiable(nodes),
       _nodeCount = _countNodes(nodes),
       _config = ChoicePresentationConfig(
         glyphs: glyphs,
         style: selectionStyle,
         selectedReference: _referenceOf(nodes, selectedValue),
         restrictions: _restrictionsOf(nodes),
       ),
       _owner = ThemeSession(
         environment: io,
         interaction: interaction,
         colors: themeColors,
         onResolved: onResolved,
         factsForPeriod: factsForPeriod,
         hints: hints,
       );

  final String label;
  final List<TreeNode<T>> nodes;
  final T? defaultValue;
  final bool Function(T value)? isCurrent;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final ComponentColors colors;
  final PromptStructure structure;
  final SingleSelectionStyle selectionStyle;
  final int _nodeCount;
  final ChoicePresentationConfig _config;
  final ThemeSession _owner;

  /// Restoration failures retained after a successful primary operation.
  List<Object> get cleanupFailures => _owner.cleanupFailures;

  Future<PromptResult<T>> prompt() => _owner.prompt((handle) {
    final mode = handle.presentationMode;
    if (mode == PresentationMode.screenReader) {
      handle.session.presentText(_essential(mode));
    }
    return TreeSelect<T>(
      label,
      nodes,
      isCurrent: isCurrent,
      defaultValue: defaultValue,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
      colors: handle.componentColors(colors).palette,
      structure: structure,
      presentation: _outputConfig(handle, _config),
    ).prompt(session: handle.session);
  });

  /// Starts live feedback sharing this prompt's active period.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
  }) => _owner.startFeedback(start, stop: stop);

  String _essential(PresentationMode mode) {
    final (primary, short) = switch (mode) {
      PresentationMode.rich => (
        'Right expands or enters; Enter chooses',
        'Right; Enter',
      ),
      _ => ('/open expands; /choose accepts', '/open; /choose'),
    };
    return composePromptPresentation(
      mode: mode,
      prompt: label,
      essential: '$label, tree selection of $_nodeCount nodes.',
      hint: compactHint(
        mode: mode,
        component: ComponentRoute.standard,
        primaryAction: primary,
        shortPrimaryAction: short,
      ),
    ).essentialBefore!;
  }

  static int _countNodes<T>(List<TreeNode<T>> nodes) =>
      nodes.fold(0, (count, node) => count + 1 + _countNodes(node.children));

  static int? _referenceOf<T>(List<TreeNode<T>> nodes, T? selected) {
    if (selected == null) return null;
    var reference = 0;
    int? found;
    void visit(List<TreeNode<T>> level) {
      for (final node in level) {
        reference++;
        if (node.value == selected) found = reference;
        visit(node.children);
      }
    }

    visit(nodes);
    return found;
  }

  static Map<int, ChoiceRestriction> _restrictionsOf<T>(
    List<TreeNode<T>> nodes,
  ) {
    final restrictions = <int, ChoiceRestriction>{};
    var reference = 0;
    void visit(List<TreeNode<T>> level) {
      for (final node in level) {
        reference++;
        if (node.disabledReason != null ||
            node.childrenUnavailableReason != null) {
          restrictions[reference] = ChoiceRestriction.unavailable;
        } else if (!node.canSelect) {
          restrictions[reference] = ChoiceRestriction.locked;
        }
        visit(node.children);
      }
    }

    visit(nodes);
    return Map.unmodifiable(restrictions);
  }
}

/// Reuses the period's glyph decision while keeping the theme-wide style.
ChoicePresentationConfig _outputConfig(
  ThemeSessionHandle handle,
  ChoicePresentationConfig config,
) {
  final glyphs = handle.environment.profile.glyphs == GlyphSet.ascii
      ? StateGlyphs.ascii
      : config.glyphs;
  if (glyphs == config.glyphs) return config;
  return ChoicePresentationConfig(
    glyphs: glyphs,
    style: config.style,
    selectedReference: config.selectedReference,
    restrictions: config.restrictions,
    showReference: config.showReference,
  );
}
