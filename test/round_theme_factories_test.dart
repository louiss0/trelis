import 'dart:async';
import 'dart:io';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

void main() {
  group('RoundTheme typed factories', () {
    final customColors = ColorThemes.signal.copyWith(
      warning: TerminalColor.rgb(255, 190, 80),
    );
    const customInstructions = InstructionDisplay.compact;
    const customHelp = ['Application-specific guidance.'];

    test('textInput forwards parameters and returns TextInput', () {
      final input = RoundTheme.textInput(
        'Name',
        initialValue: 'Ada',
        required: true,
        maxLength: 20,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(input, isA<TextInput>());
      expect(input.initialValue, 'Ada');
      expect(input.required, isTrue);
      expect(input.maxLength, 20);
      expect(input.colors, customColors);
      expect(input.structure, PromptStructure.round);
      expect(input.instructions, customInstructions);
      expect(input.supplementaryHelp, customHelp);
    });

    test('password forwards parameters and returns Password', () {
      final input = RoundTheme.password(
        'Token',
        mask: true,
        required: true,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(input, isA<Password>());
      expect(input.mask, isTrue);
      expect(input.required, isTrue);
      expect(input.colors, customColors);
      expect(input.structure, PromptStructure.round);
      expect(input.instructions, customInstructions);
      expect(input.supplementaryHelp, customHelp);
    });

    test('confirm/checkbox/toggle return their concrete types', () {
      final confirm = RoundTheme.confirm(
        'Proceed?',
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(confirm, isA<Confirm>());
      expect(confirm.colors, customColors);
      expect(confirm.structure, PromptStructure.round);
      expect(confirm.instructions, customInstructions);
      expect(confirm.supplementaryHelp, customHelp);

      final checkbox = RoundTheme.checkbox(
        'Subscribe',
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(checkbox, isA<Checkbox>());

      final toggle = RoundTheme.toggle(
        'Enable',
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(toggle, isA<Toggle>());
    });

    test('multiline forwards parameters', () {
      final input = RoundTheme.multiline(
        'Notes',
        required: true,
        maxLength: 100,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(input, isA<Multiline>());
      expect(input.required, isTrue);
      expect(input.maxLength, 100);
      expect(input.colors, customColors);
      expect(input.structure, PromptStructure.round);
      expect(input.instructions, customInstructions);
      expect(input.supplementaryHelp, customHelp);
    });

    test('select/radio/multiSelect preserve generics and choices', () {
      final choices = [Choice('a', 'Alpha'), Choice('b', 'Beta')];
      final select = RoundTheme.select<String>(
        'Letter',
        choices,
        defaultValue: 'a',
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(select, isA<Select<String>>());
      expect(select.defaultValue, 'a');
      expect(select.choices, choices);
      expect(select.colors, customColors);
      expect(select.structure, PromptStructure.round);

      final radio = RoundTheme.radio<String>(
        'Letter',
        choices,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(radio, isA<Radio<String>>());

      final multi = RoundTheme.multiSelect<String>(
        'Letters',
        choices,
        defaultValues: const ['a'],
        min: 1,
        max: 2,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(multi, isA<MultiSelect<String>>());
      expect(multi.defaultValues, const ['a']);
      expect(multi.min, 1);
      expect(multi.max, 2);
    });

    test('slider/rangeSlider forward bounds and presentation config', () {
      final slider = RoundTheme.slider(
        'Volume',
        minimum: '0',
        maximum: '10',
        step: '1',
        initialValue: '5',
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(slider, isA<Slider>());
      expect(slider.minimum, '0');
      expect(slider.maximum, '10');
      expect(slider.initialValue, '5');
      expect(slider.colors, customColors);
      expect(slider.structure, PromptStructure.round);
      expect(slider.instructions, customInstructions);
      expect(slider.supplementaryHelp, customHelp);

      final range = RoundTheme.rangeSlider(
        'Range',
        minimum: '0',
        maximum: '100',
        step: '5',
        initialLower: '20',
        initialUpper: '80',
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(range, isA<RangeSlider>());
      expect(range.colors, customColors);
      expect(range.instructions, customInstructions);
      expect(range.supplementaryHelp, customHelp);
    });

    test('treeSelect and sortableSelect forward choices', () {
      final nodes = [TreeNode<String>('a', 'Alpha', children: [])];
      final tree = RoundTheme.treeSelect<String>(
        'Node',
        nodes,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(tree, isA<TreeSelect<String>>());
      expect(tree.nodes, nodes);
      expect(tree.colors, customColors);
      expect(tree.structure, PromptStructure.round);

      final choices = [Choice('a', 'Alpha'), Choice('b', 'Beta')];
      final sortable = RoundTheme.sortableSelect<String>(
        'Order',
        choices,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(sortable, isA<SortableSelect<String>>());
      expect(sortable.choices, choices);
    });

    test('timeInput and tagInput forward specialized config', () {
      final time = RoundTheme.timeInput(
        'Start',
        twelveHour: true,
        seconds: true,
        initialValue: '01:30:00 PM',
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(time, isA<TimeInput>());
      expect(time.twelveHour, isTrue);
      expect(time.seconds, isTrue);
      expect(time.initialValue, '01:30:00 PM');
      expect(time.colors, customColors);
      expect(time.structure, PromptStructure.round);

      final tags = RoundTheme.tagInput(
        'Keywords',
        style: TagStyle.snakeCase,
        maxLength: 10,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(tags, isA<TagInput>());
      expect(tags.style, TagStyle.snakeCase);
      expect(tags.maxLength, 10);
    });

    test('autocomplete/searchSelect/commandPalette forward search config', () {
      FutureOr<List<String>> suggest(String _) => [];
      final autocomplete = RoundTheme.autocomplete(
        'Package',
        suggestions: suggest,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(autocomplete, isA<Autocomplete>());
      expect(autocomplete.colors, customColors);
      expect(autocomplete.structure, PromptStructure.round);

      final choices = [Choice('a', 'Alpha')];
      final searchSelect = RoundTheme.searchSelect<String>(
        'Find',
        choices,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(searchSelect, isA<SearchSelect<String>>());
      expect(searchSelect.colors, customColors);

      final palette = RoundTheme.commandPalette<String>(
        'Run',
        choices,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(palette, isA<CommandPalette<String>>());
      expect(palette.colors, customColors);
    });

    test('maskedInput/numberInput forward specialized config', () {
      final masked = RoundTheme.maskedInput(
        'Key',
        templates: [
          MaskTemplate('hex', [
            MaskSlot('hex digit', (s) => RegExp(r'^[0-9a-fA-F]$').hasMatch(s)),
          ]),
        ],
        interpretation: MaskInterpretation.raw,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(masked, isA<MaskedInput>());
      expect(masked.interpretation, MaskInterpretation.raw);
      expect(masked.colors, customColors);
      expect(masked.structure, PromptStructure.round);

      final number = RoundTheme.numberInput(
        'Count',
        decimal: true,
        minimum: '0',
        maximum: '100',
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(number, isA<NumberInput>());
      expect(number.decimal, isTrue);
      expect(number.minimum, '0');
      expect(number.maximum, '100');
    });

    test('network/url/email inputs forward their validation config', () {
      final port = RoundTheme.portInput(
        'Port',
        allowZero: true,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(port, isA<PortInput>());
      expect(port.allowZero, isTrue);
      expect(port.colors, customColors);
      expect(port.structure, PromptStructure.round);

      final ip = RoundTheme.ipAddressInput(
        'Address',
        cidr: true,
        scoped: true,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(ip, isA<IPAddressInput>());
      expect(ip.cidr, isTrue);
      expect(ip.scoped, isTrue);

      final url = RoundTheme.urlInput(
        'Site',
        allowedSchemes: const {'https'},
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(url, isA<URLInput>());
      expect(url.allowedSchemes, const {'https'});
      expect(url.colors, customColors);
      expect(url.structure, PromptStructure.round);

      final email = RoundTheme.emailInput(
        'Contact',
        smtpUtf8: true,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(email, isA<EmailInput>());
      expect(email.smtpUtf8, isTrue);
    });

    test('colorInput/cronInput/timezoneSelect forward their config', () {
      final color = RoundTheme.colorInput(
        'Accent',
        required: false,
        initialValue: '#ff0000',
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(color, isA<ColorInput>());
      expect(color.required, isFalse);
      expect(color.initialValue, '#ff0000');

      final cron = RoundTheme.cronInput(
        'Schedule',
        profile: CronProfile.unix,
        initialValue: '0 0 * * *',
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(cron, isA<CronInput>());
      expect(cron.profile, CronProfile.unix);
      expect(cron.initialValue, '0 0 * * *');
      expect(cron.colors, customColors);
      expect(cron.structure, PromptStructure.round);

      final tz = RoundTheme.timezoneSelect(
        'Zone',
        defaultValue: 'UTC',
        unavailable: const {'Etc/GMT': 'not available'},
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(tz, isA<TimezoneSelect>());
      expect(tz.colors, customColors);
    });

    test('path/filesystem inputs forward their target config', () {
      final base = Platform.isWindows ? r'C:\' : '/tmp';
      final path = RoundTheme.pathInput(
        'Path',
        base: base,
        allowNonexistent: true,
        target: PathTarget.directory,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(path, isA<PathInput>());
      expect(path.base, base);
      expect(path.allowNonexistent, isTrue);
      expect(path.target, PathTarget.directory);
      expect(path.colors, customColors);
      expect(path.structure, PromptStructure.round);

      final file = RoundTheme.filePicker(
        'File',
        base: base,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(file, isA<FilePicker>());
      expect(file.colors, customColors);

      final dir = RoundTheme.directoryPicker(
        'Directory',
        base: base,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(dir, isA<DirectoryPicker>());
      expect(dir.colors, customColors);
    });

    test('key capture inputs forward observation config', () {
      final keypress = RoundTheme.keypress(
        'Key',
        requireObservation: true,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(keypress, isA<Keypress>());
      expect(keypress.requireObservation, isTrue);
      expect(keypress.colors, customColors);

      final chord = RoundTheme.keyChordInput(
        'Chord',
        requireObservation: true,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(chord, isA<KeyChordInput>());
      expect(chord.colors, customColors);
    });

    test('durationInput and dateInput forward their mode config', () {
      final duration = RoundTheme.durationInput(
        'Timeout',
        durationMode: DurationInputMode.elapsed,
        signed: true,
        allowZero: false,
        minimumMicroseconds: 1000,
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(duration, isA<DurationInput>());
      expect(duration.durationMode, DurationInputMode.elapsed);
      expect(duration.signed, isTrue);
      expect(duration.allowZero, isFalse);
      expect(duration.minimumMicroseconds, 1000);

      final date = RoundTheme.dateInput(
        'Date',
        order: DateFieldOrder.yearMonthDay,
        calendar: DateCalendar.gregorian,
        digits: DateDigits.ascii,
        initialValue: '2026/01/15',
        colors: customColors,
        instructions: customInstructions,
        supplementaryHelp: customHelp,
      );
      expect(date, isA<DateInput>());
      expect(date.order, DateFieldOrder.yearMonthDay);
      expect(date.calendar, DateCalendar.gregorian);
      expect(date.digits, DateDigits.ascii);
    });

    test('feedback factories accept colors and return concrete types', () {
      final text = RoundTheme.text(
        'Hello',
        kind: TextKind.success,
        colors: customColors,
      );
      expect(text, isA<Text>());
      expect(text.kind, TextKind.success);
      expect(text.colors, customColors);

      final progress = RoundTheme.progress(
        'Copy',
        total: 100,
        milestone: 25,
        colors: customColors,
      );
      expect(progress, isA<Progress>());
      expect(progress.total, 100);
      expect(progress.milestone, 25);
      expect(progress.colors, customColors);

      final spinner = RoundTheme.spinner('Work', colors: customColors);
      expect(spinner, isA<Spinner>());
      expect(spinner.colors, customColors);

      final multi = RoundTheme.multiSpinner(
        const ['a', 'b'],
        interval: const Duration(seconds: 1),
        colors: customColors,
      );
      expect(multi, isA<MultiSpinner>());
      expect(multi.colors, customColors);
    });

    test('factories do not invoke prompt/present/start or produce output', () {
      final output = StringBuffer();
      RoundTheme.textInput('Name', colors: customColors);
      RoundTheme.progress('Work', colors: customColors);
      expect(output.toString(), isEmpty);
    });
  });
}
