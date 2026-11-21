// External-package positive fixture: only the public barrel is imported.
import 'dart:async';
import 'dart:io';

import 'package:trelis/trelis.dart';

void exercise(StructuralTheme theme, List<Object> sink) {
  final ThemePrompt<String> text = theme.textInput('Name');
  final ThemePrompt<String> secret = theme.password('Secret');
  final ThemePrompt<String> multiline = theme.multiline('Notes');
  final ThemePrompt<bool> confirm = theme.confirm('Proceed?');
  final ThemePrompt<bool> checkbox = theme.checkbox('Accept');
  final ThemePrompt<bool> toggle = theme.toggle('Enable');
  final ThemePrompt<int> select = theme.select<int>('Choice', [Choice(1, 'A')]);
  final ThemePrompt<int> radio = theme.radio<int>('Choice', [Choice(1, 'A')]);
  final ThemePrompt<List<int>> multi = theme.multiSelect<int>('Choices', [
    Choice(1, 'A'),
  ]);
  final ThemePrompt<String> slider = theme.slider(
    'Volume',
    minimum: '0',
    maximum: '10',
    step: '1',
  );
  final ThemePrompt<(String, String)> range = theme.rangeSlider(
    'Window',
    minimum: '0',
    maximum: '10',
    step: '1',
  );
  final ThemePrompt<int> tree = theme.treeSelect<int>('Tree', [
    TreeNode(1, 'A'),
  ]);
  final ThemePrompt<({int hour, int minute, int? second})> time =
      theme.timeInput('Time');
  final ThemePrompt<List<String>> tags = theme.tagInput('Tags');
  final ThemePrompt<String> autocomplete = theme.autocomplete(
    'Package',
    suggestions: (_) async => const ['Ada'],
  );
  final ThemePrompt<int> search = theme.searchSelect<int>('Find', [
    Choice(1, 'A'),
  ]);
  final ThemePrompt<List<int>> order = theme.sortableSelect<int>('Order', [
    Choice(1, 'A'),
  ]);
  final ThemePrompt<int> palette = theme.commandPalette<int>('Run', [
    Choice(1, 'A'),
  ]);
  final ThemePrompt<MaskedValue> masked = theme.maskedInput(
    'Code',
    templates: [MaskTemplate('digit', [MaskSlot('d', (v) => v == '1')])],
  );
  final ThemePrompt<NumericAnswer?> number = theme.numberInput('Count');
  final ThemePrompt<int> port = theme.portInput('Port');
  final ThemePrompt<IPAddressValue> ip = theme.ipAddressInput('Address');
  final ThemePrompt<String> url = theme.urlInput('URL', allowedSchemes: {
    'https',
  });
  final ThemePrompt<String> email = theme.emailInput('Email');
  final ThemePrompt<ColorValue?> color = theme.colorInput('Color');
  final ThemePrompt<CronExpression> cron = theme.cronInput(
    'Schedule',
    profile: CronProfile.unix,
  );
  final ThemePrompt<String> timezone = theme.timezoneSelect('Zone');
  final ThemePrompt<String> path = theme.pathInput('Path');
  final ThemePrompt<String> file = theme.filePicker('File');
  final ThemePrompt<String> directory = theme.directoryPicker('Directory');
  final ThemePrompt<KeyGesture> key = theme.keypress('Shortcut');
  final ThemePrompt<List<KeyGesture>> chord = theme.keyChordInput('Sequence');
  final ThemePrompt<DurationValue> duration = theme.durationInput(
    'Span',
    durationMode: DurationInputMode.elapsed,
  );
  final ThemePrompt<CivilDate> date = theme.dateInput('Date');
  final ThemeFeedback feedback = theme.text('Done');
  final ThemeLiveFeedback progress = theme.progress('Work');
  final ThemeLiveFeedback spinner = theme.spinner('Work');
  final ThemeLiveFeedback multiSpinner = theme.multiSpinner(['build', 'test']);

  sink.addAll([
    text,
    secret,
    multiline,
    confirm,
    checkbox,
    toggle,
    select,
    radio,
    multi,
    slider,
    range,
    tree,
    time,
    tags,
    autocomplete,
    search,
    order,
    palette,
    masked,
    number,
    port,
    ip,
    url,
    email,
    color,
    cron,
    timezone,
    path,
    file,
    directory,
    key,
    chord,
    duration,
    date,
    feedback,
    progress,
    spinner,
    multiSpinner,
  ]);
}

void main() {
  final io = TerminalEnvironment.scripted(
    input: const Stream<String>.empty(),
    output: stdout,
  );
  final themes = <StructuralTheme>[
    PlainTheme(io: io),
    RailTheme(io: io),
    AsciiTheme(io: io),
    DoubleTheme(io: io),
    ChevronTheme(io: io),
    ColonTheme(io: io),
    BoxTheme(io: io),
    BracketTheme(io: io),
    BlockTheme(io: io),
    BranchTheme(io: io),
    RoundTheme(io: io),
    LineTheme(io: io),
    MinimalTheme(io: io),
    FormTheme(io: io),
    LedgerTheme(io: io),
  ];
  final sink = <Object>[];
  for (final theme in themes) {
    exercise(theme, sink);
  }
  stdout.writeln('${themes.length} themes, ${sink.length} public members');
}
