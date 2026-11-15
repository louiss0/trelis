part of 'text_input.dart';

/// Searches commands and returns an explicitly accepted identity. The caller
/// owns command execution; this component never invokes application actions.
final class CommandPalette<T> {
  CommandPalette(
    String label,
    List<Choice<T>> commands, {
    T? defaultValue,
    FutureOr<List<Choice<T>>> Function(String query)? search,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : _select = SearchSelect<T>._palette(
         label,
         commands,
         defaultValue: defaultValue,
         search: search,
         colors: colors,
         instructions: instructions,
         supplementaryHelp: supplementaryHelp,
       );

  ColorTheme get colors => _select.colors;

  InstructionDisplay get instructions => _select.instructions;

  List<String> get supplementaryHelp => _select.supplementaryHelp;

  final SearchSelect<T> _select;

  Future<PromptResult<T>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) => _select.prompt(
    source: source,
    mode: mode,
    userPreference: userPreference,
    applicationPreference: applicationPreference,
    output: output,
    terminal: terminal,
    outputProfile: outputProfile,
    session: session,
  );
}
