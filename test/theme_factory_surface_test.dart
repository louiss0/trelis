import 'dart:async';
import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

/// The typed factory surface of all fifteen structural namespaces.
///
/// This inventory exists because the factory surface is a contract, not a
/// convenience: every one of the fifteen classes must expose all 38 typed
/// factories with the same concrete return type, the same generics and the same
/// positional/named arguments, and each factory must forward what it was given
/// while doing nothing else. The proof is in two halves:
///
/// * **Compile time.** Every namespace's tear-off is assigned to a map whose
///   value type is the factory's exact function type (`_TextInputFactory` and
///   friends). A namespace that drops a method, widens a return type to the
///   shared base class, loses a generic or renames an argument does not
///   compile: 15 namespaces x 38 factories = 570 class-method pairs.
/// * **Run time.** Every pair is invoked with non-default, distinguishable
///   arguments and the configured object is inspected. The counts below are
///   assertions over the executed inventory, and construction purity is checked
///   by callbacks that fail the test if a factory calls them.
///
/// No factory invokes `prompt`, `present` or `start`, and no factory takes an
/// output sink, so construction cannot perform terminal I/O. Feedback factories
/// take no instruction parameters, which is itself part of the signature
/// contract the typedefs enforce.

/// The number of typed factories on each structural namespace.
const _factoryCount = 38;

/// The number of structural namespaces.
const _namespaceCount = 15;

/// Every class-method pair the specification requires.
const _pairCount = _factoryCount * _namespaceCount; // 570

/// An absolute, existing directory a path or picker factory may be configured
/// with. Nothing in the inventory reads it: construction only stores it.
final String _baseDirectory = Directory.systemTemp.path;

/// Distinguishable non-default construction arguments.
final class _Args {
  final ColorTheme colors = ColorThemes.signal.copyWith(
    warning: TerminalColor.rgb(255, 190, 80),
  );
  final InstructionDisplay instructions = InstructionDisplay.compact;
  final List<String> help = const ['Application-specific guidance.'];

  /// Counts callbacks a factory was asked for but must not invoke.
  int validated = 0;
  int suggested = 0;
  int conventionAsked = 0;

  String? validate(String value) {
    validated++;
    return null;
  }

  List<String> suggest(String query) {
    suggested++;
    return const [];
  }

  NumericConvention? conventionProvider() {
    conventionAsked++;
    return null;
  }
}

/// One factory's typed surface across the fifteen namespaces.
abstract class _SurfaceProbe {
  const _SurfaceProbe(this.name);

  /// The namespace name to tear-off map, typed by the subclass.
  Map<String, Object> get factories;

  /// The factory method name, used in failure reasons.
  final String name;

  /// Invokes the named namespace's factory and returns the structure the
  /// returned object was configured with.
  PromptStructure invokeFor(String theme, _Args args);
}

/// A factory whose tear-offs are all of type [F].
final class _Probe<F extends Function> extends _SurfaceProbe {
  const _Probe(super.name, this.factories, this.invoke);

  /// The namespace name to tear-off map, typed with the factory's exact
  /// function type.
  @override
  final Map<String, F> factories;
  final PromptStructure Function(F factory, _Args args) invoke;

  @override
  PromptStructure invokeFor(String theme, _Args args) =>
      invoke(factories[theme]!, args);
}

void main() {
  group('the typed factory surface', () {
    test(
      'all $_namespaceCount namespaces expose all $_factoryCount factories',
      () {
        expect(_structures, hasLength(_namespaceCount));
        expect(_probes, hasLength(_factoryCount));
        expect(
          _probes.map((probe) => probe.name).toSet(),
          hasLength(_factoryCount),
          reason: 'each factory is inventoried once',
        );
        for (final probe in _probes) {
          expect(
            probe.factories.keys,
            containsAll(_structures.values),
            reason: '${probe.name} is missing from a namespace',
          );
          expect(
            probe.factories,
            hasLength(_namespaceCount),
            reason: '${probe.name} is declared once per namespace',
          );
        }
        expect(
          _probes.fold<int>(0, (sum, probe) => sum + probe.factories.length),
          _pairCount,
        );
      },
    );

    test('every pair configures its own structure and forwards arguments', () {
      var pairs = 0;
      for (final entry in _structures.entries) {
        for (final probe in _probes) {
          final args = _Args();
          expect(
            probe.invokeFor(entry.value, args),
            entry.key,
            reason:
                '${entry.value}.${probe.name} did not configure its '
                'declared structure',
          );
          pairs++;
        }
      }
      expect(pairs, _pairCount);
    });

    test('construction invokes no callback', () {
      final args = _Args();
      for (final entry in _structures.entries) {
        for (final probe in _probes) {
          probe.invokeFor(entry.value, args);
        }
      }
      expect(args.validated, 0, reason: 'a factory validated an answer');
      expect(args.suggested, 0, reason: 'a factory queried suggestions');
      expect(
        args.conventionAsked,
        0,
        reason: 'a factory resolved the numeric convention',
      );
    });

    test('the generic factories keep their type argument', () {
      for (final theme in _structures.values) {
        final select = _selectSurface[theme]!(
          'Letter',
          [Choice('a', 'Alpha')],
          defaultValue: 'a',
          colors: _Args().colors,
        );
        expect(select, isA<Select<String>>());

        final multi = _multiSelectSurface[theme]!(
          'Letters',
          [Choice('a', 'Alpha')],
          defaultValues: const ['a'],
          min: 0,
        );
        expect(multi, isA<MultiSelect<String>>());

        final tree = _treeSelectSurface[theme]!('Tree', [
          TreeNode('a', 'A'),
        ], defaultValue: 'a');
        expect(tree, isA<TreeSelect<String>>());

        final search = _searchSelectSurface[theme]!('Fruit', [
          Choice('a', 'Apple'),
        ], defaultValue: 'a');
        expect(search, isA<SearchSelect<String>>());

        final palette = _commandPaletteSurface[theme]!('Commands', [
          Choice('save', 'Save'),
        ], defaultValue: 'save');
        expect(palette, isA<CommandPalette<String>>());

        final sortable = _sortableSelectSurface[theme]!('Order', [
          Choice('a', 'A'),
        ]);
        expect(sortable, isA<SortableSelect<String>>());

        final radio = _radioSurface[theme]!('Signal', [
          Choice('a', 'Red'),
        ], defaultValue: 'a');
        expect(radio, isA<Radio<String>>());
      }
    });
  });
}

/// The `textInput` factory every structural namespace must expose.
typedef _TextInputFactory = TextInput Function(
  String, {
  String initialValue,
  bool required,
  String? Function(String)? validate,
  int? maxLength,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `password` factory every structural namespace must expose.
typedef _PasswordFactory = Password Function(
  String, {
  String initialValue,
  bool mask,
  bool required,
  String? Function(String)? validate,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `confirm` factory every structural namespace must expose.
typedef _ConfirmFactory = Confirm Function(
  String, {
  bool initialValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `checkbox` factory every structural namespace must expose.
typedef _CheckboxFactory = Checkbox Function(
  String, {
  bool initialValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `toggle` factory every structural namespace must expose.
typedef _ToggleFactory = Toggle Function(
  String, {
  bool initialValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `multiline` factory every structural namespace must expose.
typedef _MultilineFactory = Multiline Function(
  String, {
  String initialValue,
  bool required,
  String? Function(String)? validate,
  int? maxLength,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `select` factory every structural namespace must expose.
typedef _SelectFactory = Select<T> Function<T>(
  String,
  List<Choice<T>>, {
  T? defaultValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `radio` factory every structural namespace must expose.
typedef _RadioFactory = Radio<T> Function<T>(
  String,
  List<Choice<T>>, {
  T? defaultValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `multiSelect` factory every structural namespace must expose.
typedef _MultiSelectFactory = MultiSelect<T> Function<T>(
  String,
  List<Choice<T>>, {
  List<T> defaultValues,
  int min,
  int? max,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `slider` factory every structural namespace must expose.
typedef _SliderFactory = Slider Function(
  String, {
  required String minimum,
  required String maximum,
  required String step,
  String? initialValue,
  int? precision,
  String? units,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `rangeSlider` factory every structural namespace must expose.
typedef _RangeSliderFactory = RangeSlider Function(
  String, {
  required String minimum,
  required String maximum,
  required String step,
  String minimumGap,
  String? initialLower,
  String? initialUpper,
  int? precision,
  String? units,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `treeSelect` factory every structural namespace must expose.
typedef _TreeSelectFactory = TreeSelect<T> Function<T>(
  String,
  List<TreeNode<T>>, {
  bool Function(T value)? isCurrent,
  T? defaultValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `timeInput` factory every structural namespace must expose.
typedef _TimeInputFactory = TimeInput Function(
  String, {
  bool twelveHour,
  bool seconds,
  String? initialValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `tagInput` factory every structural namespace must expose.
typedef _TagInputFactory = TagInput Function(
  String, {
  TagStyle style,
  int? maxLength,
  String? Function(String)? validate,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `autocomplete` factory every structural namespace must expose.
typedef _AutocompleteFactory = Autocomplete Function(
  String, {
  required FutureOr<List<String>> Function(String) suggestions,
  String initialValue,
  bool required,
  String? Function(String)? validate,
  int? maxLength,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `searchSelect` factory every structural namespace must expose.
typedef _SearchSelectFactory = SearchSelect<T> Function<T>(
  String,
  List<Choice<T>>, {
  T? defaultValue,
  FutureOr<List<Choice<T>>> Function(String query)? search,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `sortableSelect` factory every structural namespace must expose.
typedef _SortableSelectFactory = SortableSelect<T> Function<T>(
  String,
  List<Choice<T>>, {
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `commandPalette` factory every structural namespace must expose.
typedef _CommandPaletteFactory = CommandPalette<T> Function<T>(
  String,
  List<Choice<T>>, {
  T? defaultValue,
  FutureOr<List<Choice<T>>> Function(String query)? search,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `maskedInput` factory every structural namespace must expose.
typedef _MaskedInputFactory = MaskedInput Function(
  String, {
  required List<MaskTemplate> templates,
  MaskedValue? initialValue,
  MaskInterpretation interpretation,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `numberInput` factory every structural namespace must expose.
typedef _NumberInputFactory = NumberInput Function(
  String, {
  NumericConvention? convention,
  NumericConvention? Function()? conventionProvider,
  bool decimal,
  String? minimum,
  String? maximum,
  int? precision,
  bool required,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `portInput` factory every structural namespace must expose.
typedef _PortInputFactory = PortInput Function(
  String, {
  bool allowZero,
  String initialValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `ipAddressInput` factory every structural namespace must expose.
typedef _IpAddressInputFactory = IPAddressInput Function(
  String, {
  bool cidr,
  bool scoped,
  String initialValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `urlInput` factory every structural namespace must expose.
typedef _UrlInputFactory = URLInput Function(
  String, {
  required Set<String> allowedSchemes,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `emailInput` factory every structural namespace must expose.
typedef _EmailInputFactory = EmailInput Function(
  String, {
  bool smtpUtf8,
  String initialValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `colorInput` factory every structural namespace must expose.
typedef _ColorInputFactory = ColorInput Function(
  String, {
  bool required,
  String initialValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `cronInput` factory every structural namespace must expose.
typedef _CronInputFactory = CronInput Function(
  String, {
  required CronProfile profile,
  String initialValue,
  CronPreviewConfig? preview,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `timezoneSelect` factory every structural namespace must expose.
typedef _TimezoneSelectFactory = TimezoneSelect Function(
  String, {
  String? defaultValue,
  Map<String, String> unavailable,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `pathInput` factory every structural namespace must expose.
typedef _PathInputFactory = PathInput Function(
  String, {
  String? base,
  String initialValue,
  bool allowNonexistent,
  PathTarget target,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `filePicker` factory every structural namespace must expose.
typedef _FilePickerFactory = FilePicker Function(
  String, {
  String? base,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `directoryPicker` factory every structural namespace must expose.
typedef _DirectoryPickerFactory = DirectoryPicker Function(
  String, {
  String? base,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `keypress` factory every structural namespace must expose.
typedef _KeypressFactory = Keypress Function(
  String, {
  bool requireObservation,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `keyChordInput` factory every structural namespace must expose.
typedef _KeyChordInputFactory = KeyChordInput Function(
  String, {
  bool requireObservation,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `durationInput` factory every structural namespace must expose.
typedef _DurationInputFactory = DurationInput Function(
  String, {
  required DurationInputMode durationMode,
  bool signed,
  bool allowZero,
  int? minimumMicroseconds,
  String? initialValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `dateInput` factory every structural namespace must expose.
typedef _DateInputFactory = DateInput Function(
  String, {
  DateFieldOrder? order,
  DateCalendar? calendar,
  DateDigits? digits,
  String? initialValue,
  ColorTheme colors,
  InstructionDisplay instructions,
  List<String> supplementaryHelp,
});

/// The `text` factory every structural namespace must expose.
typedef _TextFactory = Text Function(
  String, {
  TextKind kind,
  ColorTheme colors,
});

/// The `progress` factory every structural namespace must expose.
typedef _ProgressFactory = Progress Function(
  String, {
  int? total,
  Duration interval,
  int milestone,
  ColorTheme colors,
});

/// The `spinner` factory every structural namespace must expose.
typedef _SpinnerFactory = Spinner Function(String, {ColorTheme colors});

/// The `multiSpinner` factory every structural namespace must expose.
typedef _MultiSpinnerFactory = MultiSpinner Function(
  Iterable<String>, {
  Duration interval,
  ColorTheme colors,
});

/// The fifteen `textInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _TextInputFactory> _textInputSurface =
    <String, _TextInputFactory>{
      'PlainTheme': PlainTheme.textInput,
      'RailTheme': RailTheme.textInput,
      'BranchTheme': BranchTheme.textInput,
      'BoxTheme': BoxTheme.textInput,
      'RoundTheme': RoundTheme.textInput,
      'DoubleTheme': DoubleTheme.textInput,
      'MinimalTheme': MinimalTheme.textInput,
      'AsciiTheme': AsciiTheme.textInput,
      'ChevronTheme': ChevronTheme.textInput,
      'BracketTheme': BracketTheme.textInput,
      'FormTheme': FormTheme.textInput,
      'LedgerTheme': LedgerTheme.textInput,
      'ColonTheme': ColonTheme.textInput,
      'LineTheme': LineTheme.textInput,
      'BlockTheme': BlockTheme.textInput,
    };

/// The fifteen `password` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _PasswordFactory> _passwordSurface =
    <String, _PasswordFactory>{
      'PlainTheme': PlainTheme.password,
      'RailTheme': RailTheme.password,
      'BranchTheme': BranchTheme.password,
      'BoxTheme': BoxTheme.password,
      'RoundTheme': RoundTheme.password,
      'DoubleTheme': DoubleTheme.password,
      'MinimalTheme': MinimalTheme.password,
      'AsciiTheme': AsciiTheme.password,
      'ChevronTheme': ChevronTheme.password,
      'BracketTheme': BracketTheme.password,
      'FormTheme': FormTheme.password,
      'LedgerTheme': LedgerTheme.password,
      'ColonTheme': ColonTheme.password,
      'LineTheme': LineTheme.password,
      'BlockTheme': BlockTheme.password,
    };

/// The fifteen `confirm` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _ConfirmFactory> _confirmSurface = <String, _ConfirmFactory>{
  'PlainTheme': PlainTheme.confirm,
  'RailTheme': RailTheme.confirm,
  'BranchTheme': BranchTheme.confirm,
  'BoxTheme': BoxTheme.confirm,
  'RoundTheme': RoundTheme.confirm,
  'DoubleTheme': DoubleTheme.confirm,
  'MinimalTheme': MinimalTheme.confirm,
  'AsciiTheme': AsciiTheme.confirm,
  'ChevronTheme': ChevronTheme.confirm,
  'BracketTheme': BracketTheme.confirm,
  'FormTheme': FormTheme.confirm,
  'LedgerTheme': LedgerTheme.confirm,
  'ColonTheme': ColonTheme.confirm,
  'LineTheme': LineTheme.confirm,
  'BlockTheme': BlockTheme.confirm,
};

/// The fifteen `checkbox` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _CheckboxFactory> _checkboxSurface =
    <String, _CheckboxFactory>{
      'PlainTheme': PlainTheme.checkbox,
      'RailTheme': RailTheme.checkbox,
      'BranchTheme': BranchTheme.checkbox,
      'BoxTheme': BoxTheme.checkbox,
      'RoundTheme': RoundTheme.checkbox,
      'DoubleTheme': DoubleTheme.checkbox,
      'MinimalTheme': MinimalTheme.checkbox,
      'AsciiTheme': AsciiTheme.checkbox,
      'ChevronTheme': ChevronTheme.checkbox,
      'BracketTheme': BracketTheme.checkbox,
      'FormTheme': FormTheme.checkbox,
      'LedgerTheme': LedgerTheme.checkbox,
      'ColonTheme': ColonTheme.checkbox,
      'LineTheme': LineTheme.checkbox,
      'BlockTheme': BlockTheme.checkbox,
    };

/// The fifteen `toggle` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _ToggleFactory> _toggleSurface = <String, _ToggleFactory>{
  'PlainTheme': PlainTheme.toggle,
  'RailTheme': RailTheme.toggle,
  'BranchTheme': BranchTheme.toggle,
  'BoxTheme': BoxTheme.toggle,
  'RoundTheme': RoundTheme.toggle,
  'DoubleTheme': DoubleTheme.toggle,
  'MinimalTheme': MinimalTheme.toggle,
  'AsciiTheme': AsciiTheme.toggle,
  'ChevronTheme': ChevronTheme.toggle,
  'BracketTheme': BracketTheme.toggle,
  'FormTheme': FormTheme.toggle,
  'LedgerTheme': LedgerTheme.toggle,
  'ColonTheme': ColonTheme.toggle,
  'LineTheme': LineTheme.toggle,
  'BlockTheme': BlockTheme.toggle,
};

/// The fifteen `multiline` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _MultilineFactory> _multilineSurface =
    <String, _MultilineFactory>{
      'PlainTheme': PlainTheme.multiline,
      'RailTheme': RailTheme.multiline,
      'BranchTheme': BranchTheme.multiline,
      'BoxTheme': BoxTheme.multiline,
      'RoundTheme': RoundTheme.multiline,
      'DoubleTheme': DoubleTheme.multiline,
      'MinimalTheme': MinimalTheme.multiline,
      'AsciiTheme': AsciiTheme.multiline,
      'ChevronTheme': ChevronTheme.multiline,
      'BracketTheme': BracketTheme.multiline,
      'FormTheme': FormTheme.multiline,
      'LedgerTheme': LedgerTheme.multiline,
      'ColonTheme': ColonTheme.multiline,
      'LineTheme': LineTheme.multiline,
      'BlockTheme': BlockTheme.multiline,
    };

/// The fifteen `select` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _SelectFactory> _selectSurface = <String, _SelectFactory>{
  'PlainTheme': PlainTheme.select,
  'RailTheme': RailTheme.select,
  'BranchTheme': BranchTheme.select,
  'BoxTheme': BoxTheme.select,
  'RoundTheme': RoundTheme.select,
  'DoubleTheme': DoubleTheme.select,
  'MinimalTheme': MinimalTheme.select,
  'AsciiTheme': AsciiTheme.select,
  'ChevronTheme': ChevronTheme.select,
  'BracketTheme': BracketTheme.select,
  'FormTheme': FormTheme.select,
  'LedgerTheme': LedgerTheme.select,
  'ColonTheme': ColonTheme.select,
  'LineTheme': LineTheme.select,
  'BlockTheme': BlockTheme.select,
};

/// The fifteen `radio` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _RadioFactory> _radioSurface = <String, _RadioFactory>{
  'PlainTheme': PlainTheme.radio,
  'RailTheme': RailTheme.radio,
  'BranchTheme': BranchTheme.radio,
  'BoxTheme': BoxTheme.radio,
  'RoundTheme': RoundTheme.radio,
  'DoubleTheme': DoubleTheme.radio,
  'MinimalTheme': MinimalTheme.radio,
  'AsciiTheme': AsciiTheme.radio,
  'ChevronTheme': ChevronTheme.radio,
  'BracketTheme': BracketTheme.radio,
  'FormTheme': FormTheme.radio,
  'LedgerTheme': LedgerTheme.radio,
  'ColonTheme': ColonTheme.radio,
  'LineTheme': LineTheme.radio,
  'BlockTheme': BlockTheme.radio,
};

/// The fifteen `multiSelect` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _MultiSelectFactory> _multiSelectSurface =
    <String, _MultiSelectFactory>{
      'PlainTheme': PlainTheme.multiSelect,
      'RailTheme': RailTheme.multiSelect,
      'BranchTheme': BranchTheme.multiSelect,
      'BoxTheme': BoxTheme.multiSelect,
      'RoundTheme': RoundTheme.multiSelect,
      'DoubleTheme': DoubleTheme.multiSelect,
      'MinimalTheme': MinimalTheme.multiSelect,
      'AsciiTheme': AsciiTheme.multiSelect,
      'ChevronTheme': ChevronTheme.multiSelect,
      'BracketTheme': BracketTheme.multiSelect,
      'FormTheme': FormTheme.multiSelect,
      'LedgerTheme': LedgerTheme.multiSelect,
      'ColonTheme': ColonTheme.multiSelect,
      'LineTheme': LineTheme.multiSelect,
      'BlockTheme': BlockTheme.multiSelect,
    };

/// The fifteen `slider` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _SliderFactory> _sliderSurface = <String, _SliderFactory>{
  'PlainTheme': PlainTheme.slider,
  'RailTheme': RailTheme.slider,
  'BranchTheme': BranchTheme.slider,
  'BoxTheme': BoxTheme.slider,
  'RoundTheme': RoundTheme.slider,
  'DoubleTheme': DoubleTheme.slider,
  'MinimalTheme': MinimalTheme.slider,
  'AsciiTheme': AsciiTheme.slider,
  'ChevronTheme': ChevronTheme.slider,
  'BracketTheme': BracketTheme.slider,
  'FormTheme': FormTheme.slider,
  'LedgerTheme': LedgerTheme.slider,
  'ColonTheme': ColonTheme.slider,
  'LineTheme': LineTheme.slider,
  'BlockTheme': BlockTheme.slider,
};

/// The fifteen `rangeSlider` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _RangeSliderFactory> _rangeSliderSurface =
    <String, _RangeSliderFactory>{
      'PlainTheme': PlainTheme.rangeSlider,
      'RailTheme': RailTheme.rangeSlider,
      'BranchTheme': BranchTheme.rangeSlider,
      'BoxTheme': BoxTheme.rangeSlider,
      'RoundTheme': RoundTheme.rangeSlider,
      'DoubleTheme': DoubleTheme.rangeSlider,
      'MinimalTheme': MinimalTheme.rangeSlider,
      'AsciiTheme': AsciiTheme.rangeSlider,
      'ChevronTheme': ChevronTheme.rangeSlider,
      'BracketTheme': BracketTheme.rangeSlider,
      'FormTheme': FormTheme.rangeSlider,
      'LedgerTheme': LedgerTheme.rangeSlider,
      'ColonTheme': ColonTheme.rangeSlider,
      'LineTheme': LineTheme.rangeSlider,
      'BlockTheme': BlockTheme.rangeSlider,
    };

/// The fifteen `treeSelect` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _TreeSelectFactory> _treeSelectSurface =
    <String, _TreeSelectFactory>{
      'PlainTheme': PlainTheme.treeSelect,
      'RailTheme': RailTheme.treeSelect,
      'BranchTheme': BranchTheme.treeSelect,
      'BoxTheme': BoxTheme.treeSelect,
      'RoundTheme': RoundTheme.treeSelect,
      'DoubleTheme': DoubleTheme.treeSelect,
      'MinimalTheme': MinimalTheme.treeSelect,
      'AsciiTheme': AsciiTheme.treeSelect,
      'ChevronTheme': ChevronTheme.treeSelect,
      'BracketTheme': BracketTheme.treeSelect,
      'FormTheme': FormTheme.treeSelect,
      'LedgerTheme': LedgerTheme.treeSelect,
      'ColonTheme': ColonTheme.treeSelect,
      'LineTheme': LineTheme.treeSelect,
      'BlockTheme': BlockTheme.treeSelect,
    };

/// The fifteen `timeInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _TimeInputFactory> _timeInputSurface =
    <String, _TimeInputFactory>{
      'PlainTheme': PlainTheme.timeInput,
      'RailTheme': RailTheme.timeInput,
      'BranchTheme': BranchTheme.timeInput,
      'BoxTheme': BoxTheme.timeInput,
      'RoundTheme': RoundTheme.timeInput,
      'DoubleTheme': DoubleTheme.timeInput,
      'MinimalTheme': MinimalTheme.timeInput,
      'AsciiTheme': AsciiTheme.timeInput,
      'ChevronTheme': ChevronTheme.timeInput,
      'BracketTheme': BracketTheme.timeInput,
      'FormTheme': FormTheme.timeInput,
      'LedgerTheme': LedgerTheme.timeInput,
      'ColonTheme': ColonTheme.timeInput,
      'LineTheme': LineTheme.timeInput,
      'BlockTheme': BlockTheme.timeInput,
    };

/// The fifteen `tagInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _TagInputFactory> _tagInputSurface =
    <String, _TagInputFactory>{
      'PlainTheme': PlainTheme.tagInput,
      'RailTheme': RailTheme.tagInput,
      'BranchTheme': BranchTheme.tagInput,
      'BoxTheme': BoxTheme.tagInput,
      'RoundTheme': RoundTheme.tagInput,
      'DoubleTheme': DoubleTheme.tagInput,
      'MinimalTheme': MinimalTheme.tagInput,
      'AsciiTheme': AsciiTheme.tagInput,
      'ChevronTheme': ChevronTheme.tagInput,
      'BracketTheme': BracketTheme.tagInput,
      'FormTheme': FormTheme.tagInput,
      'LedgerTheme': LedgerTheme.tagInput,
      'ColonTheme': ColonTheme.tagInput,
      'LineTheme': LineTheme.tagInput,
      'BlockTheme': BlockTheme.tagInput,
    };

/// The fifteen `autocomplete` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _AutocompleteFactory> _autocompleteSurface =
    <String, _AutocompleteFactory>{
      'PlainTheme': PlainTheme.autocomplete,
      'RailTheme': RailTheme.autocomplete,
      'BranchTheme': BranchTheme.autocomplete,
      'BoxTheme': BoxTheme.autocomplete,
      'RoundTheme': RoundTheme.autocomplete,
      'DoubleTheme': DoubleTheme.autocomplete,
      'MinimalTheme': MinimalTheme.autocomplete,
      'AsciiTheme': AsciiTheme.autocomplete,
      'ChevronTheme': ChevronTheme.autocomplete,
      'BracketTheme': BracketTheme.autocomplete,
      'FormTheme': FormTheme.autocomplete,
      'LedgerTheme': LedgerTheme.autocomplete,
      'ColonTheme': ColonTheme.autocomplete,
      'LineTheme': LineTheme.autocomplete,
      'BlockTheme': BlockTheme.autocomplete,
    };

/// The fifteen `searchSelect` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _SearchSelectFactory> _searchSelectSurface =
    <String, _SearchSelectFactory>{
      'PlainTheme': PlainTheme.searchSelect,
      'RailTheme': RailTheme.searchSelect,
      'BranchTheme': BranchTheme.searchSelect,
      'BoxTheme': BoxTheme.searchSelect,
      'RoundTheme': RoundTheme.searchSelect,
      'DoubleTheme': DoubleTheme.searchSelect,
      'MinimalTheme': MinimalTheme.searchSelect,
      'AsciiTheme': AsciiTheme.searchSelect,
      'ChevronTheme': ChevronTheme.searchSelect,
      'BracketTheme': BracketTheme.searchSelect,
      'FormTheme': FormTheme.searchSelect,
      'LedgerTheme': LedgerTheme.searchSelect,
      'ColonTheme': ColonTheme.searchSelect,
      'LineTheme': LineTheme.searchSelect,
      'BlockTheme': BlockTheme.searchSelect,
    };

/// The fifteen `sortableSelect` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _SortableSelectFactory> _sortableSelectSurface =
    <String, _SortableSelectFactory>{
      'PlainTheme': PlainTheme.sortableSelect,
      'RailTheme': RailTheme.sortableSelect,
      'BranchTheme': BranchTheme.sortableSelect,
      'BoxTheme': BoxTheme.sortableSelect,
      'RoundTheme': RoundTheme.sortableSelect,
      'DoubleTheme': DoubleTheme.sortableSelect,
      'MinimalTheme': MinimalTheme.sortableSelect,
      'AsciiTheme': AsciiTheme.sortableSelect,
      'ChevronTheme': ChevronTheme.sortableSelect,
      'BracketTheme': BracketTheme.sortableSelect,
      'FormTheme': FormTheme.sortableSelect,
      'LedgerTheme': LedgerTheme.sortableSelect,
      'ColonTheme': ColonTheme.sortableSelect,
      'LineTheme': LineTheme.sortableSelect,
      'BlockTheme': BlockTheme.sortableSelect,
    };

/// The fifteen `commandPalette` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _CommandPaletteFactory> _commandPaletteSurface =
    <String, _CommandPaletteFactory>{
      'PlainTheme': PlainTheme.commandPalette,
      'RailTheme': RailTheme.commandPalette,
      'BranchTheme': BranchTheme.commandPalette,
      'BoxTheme': BoxTheme.commandPalette,
      'RoundTheme': RoundTheme.commandPalette,
      'DoubleTheme': DoubleTheme.commandPalette,
      'MinimalTheme': MinimalTheme.commandPalette,
      'AsciiTheme': AsciiTheme.commandPalette,
      'ChevronTheme': ChevronTheme.commandPalette,
      'BracketTheme': BracketTheme.commandPalette,
      'FormTheme': FormTheme.commandPalette,
      'LedgerTheme': LedgerTheme.commandPalette,
      'ColonTheme': ColonTheme.commandPalette,
      'LineTheme': LineTheme.commandPalette,
      'BlockTheme': BlockTheme.commandPalette,
    };

/// The fifteen `maskedInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _MaskedInputFactory> _maskedInputSurface =
    <String, _MaskedInputFactory>{
      'PlainTheme': PlainTheme.maskedInput,
      'RailTheme': RailTheme.maskedInput,
      'BranchTheme': BranchTheme.maskedInput,
      'BoxTheme': BoxTheme.maskedInput,
      'RoundTheme': RoundTheme.maskedInput,
      'DoubleTheme': DoubleTheme.maskedInput,
      'MinimalTheme': MinimalTheme.maskedInput,
      'AsciiTheme': AsciiTheme.maskedInput,
      'ChevronTheme': ChevronTheme.maskedInput,
      'BracketTheme': BracketTheme.maskedInput,
      'FormTheme': FormTheme.maskedInput,
      'LedgerTheme': LedgerTheme.maskedInput,
      'ColonTheme': ColonTheme.maskedInput,
      'LineTheme': LineTheme.maskedInput,
      'BlockTheme': BlockTheme.maskedInput,
    };

/// The fifteen `numberInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _NumberInputFactory> _numberInputSurface =
    <String, _NumberInputFactory>{
      'PlainTheme': PlainTheme.numberInput,
      'RailTheme': RailTheme.numberInput,
      'BranchTheme': BranchTheme.numberInput,
      'BoxTheme': BoxTheme.numberInput,
      'RoundTheme': RoundTheme.numberInput,
      'DoubleTheme': DoubleTheme.numberInput,
      'MinimalTheme': MinimalTheme.numberInput,
      'AsciiTheme': AsciiTheme.numberInput,
      'ChevronTheme': ChevronTheme.numberInput,
      'BracketTheme': BracketTheme.numberInput,
      'FormTheme': FormTheme.numberInput,
      'LedgerTheme': LedgerTheme.numberInput,
      'ColonTheme': ColonTheme.numberInput,
      'LineTheme': LineTheme.numberInput,
      'BlockTheme': BlockTheme.numberInput,
    };

/// The fifteen `portInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _PortInputFactory> _portInputSurface =
    <String, _PortInputFactory>{
      'PlainTheme': PlainTheme.portInput,
      'RailTheme': RailTheme.portInput,
      'BranchTheme': BranchTheme.portInput,
      'BoxTheme': BoxTheme.portInput,
      'RoundTheme': RoundTheme.portInput,
      'DoubleTheme': DoubleTheme.portInput,
      'MinimalTheme': MinimalTheme.portInput,
      'AsciiTheme': AsciiTheme.portInput,
      'ChevronTheme': ChevronTheme.portInput,
      'BracketTheme': BracketTheme.portInput,
      'FormTheme': FormTheme.portInput,
      'LedgerTheme': LedgerTheme.portInput,
      'ColonTheme': ColonTheme.portInput,
      'LineTheme': LineTheme.portInput,
      'BlockTheme': BlockTheme.portInput,
    };

/// The fifteen `ipAddressInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _IpAddressInputFactory> _ipAddressInputSurface =
    <String, _IpAddressInputFactory>{
      'PlainTheme': PlainTheme.ipAddressInput,
      'RailTheme': RailTheme.ipAddressInput,
      'BranchTheme': BranchTheme.ipAddressInput,
      'BoxTheme': BoxTheme.ipAddressInput,
      'RoundTheme': RoundTheme.ipAddressInput,
      'DoubleTheme': DoubleTheme.ipAddressInput,
      'MinimalTheme': MinimalTheme.ipAddressInput,
      'AsciiTheme': AsciiTheme.ipAddressInput,
      'ChevronTheme': ChevronTheme.ipAddressInput,
      'BracketTheme': BracketTheme.ipAddressInput,
      'FormTheme': FormTheme.ipAddressInput,
      'LedgerTheme': LedgerTheme.ipAddressInput,
      'ColonTheme': ColonTheme.ipAddressInput,
      'LineTheme': LineTheme.ipAddressInput,
      'BlockTheme': BlockTheme.ipAddressInput,
    };

/// The fifteen `urlInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _UrlInputFactory> _urlInputSurface =
    <String, _UrlInputFactory>{
      'PlainTheme': PlainTheme.urlInput,
      'RailTheme': RailTheme.urlInput,
      'BranchTheme': BranchTheme.urlInput,
      'BoxTheme': BoxTheme.urlInput,
      'RoundTheme': RoundTheme.urlInput,
      'DoubleTheme': DoubleTheme.urlInput,
      'MinimalTheme': MinimalTheme.urlInput,
      'AsciiTheme': AsciiTheme.urlInput,
      'ChevronTheme': ChevronTheme.urlInput,
      'BracketTheme': BracketTheme.urlInput,
      'FormTheme': FormTheme.urlInput,
      'LedgerTheme': LedgerTheme.urlInput,
      'ColonTheme': ColonTheme.urlInput,
      'LineTheme': LineTheme.urlInput,
      'BlockTheme': BlockTheme.urlInput,
    };

/// The fifteen `emailInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _EmailInputFactory> _emailInputSurface =
    <String, _EmailInputFactory>{
      'PlainTheme': PlainTheme.emailInput,
      'RailTheme': RailTheme.emailInput,
      'BranchTheme': BranchTheme.emailInput,
      'BoxTheme': BoxTheme.emailInput,
      'RoundTheme': RoundTheme.emailInput,
      'DoubleTheme': DoubleTheme.emailInput,
      'MinimalTheme': MinimalTheme.emailInput,
      'AsciiTheme': AsciiTheme.emailInput,
      'ChevronTheme': ChevronTheme.emailInput,
      'BracketTheme': BracketTheme.emailInput,
      'FormTheme': FormTheme.emailInput,
      'LedgerTheme': LedgerTheme.emailInput,
      'ColonTheme': ColonTheme.emailInput,
      'LineTheme': LineTheme.emailInput,
      'BlockTheme': BlockTheme.emailInput,
    };

/// The fifteen `colorInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _ColorInputFactory> _colorInputSurface =
    <String, _ColorInputFactory>{
      'PlainTheme': PlainTheme.colorInput,
      'RailTheme': RailTheme.colorInput,
      'BranchTheme': BranchTheme.colorInput,
      'BoxTheme': BoxTheme.colorInput,
      'RoundTheme': RoundTheme.colorInput,
      'DoubleTheme': DoubleTheme.colorInput,
      'MinimalTheme': MinimalTheme.colorInput,
      'AsciiTheme': AsciiTheme.colorInput,
      'ChevronTheme': ChevronTheme.colorInput,
      'BracketTheme': BracketTheme.colorInput,
      'FormTheme': FormTheme.colorInput,
      'LedgerTheme': LedgerTheme.colorInput,
      'ColonTheme': ColonTheme.colorInput,
      'LineTheme': LineTheme.colorInput,
      'BlockTheme': BlockTheme.colorInput,
    };

/// The fifteen `cronInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _CronInputFactory> _cronInputSurface =
    <String, _CronInputFactory>{
      'PlainTheme': PlainTheme.cronInput,
      'RailTheme': RailTheme.cronInput,
      'BranchTheme': BranchTheme.cronInput,
      'BoxTheme': BoxTheme.cronInput,
      'RoundTheme': RoundTheme.cronInput,
      'DoubleTheme': DoubleTheme.cronInput,
      'MinimalTheme': MinimalTheme.cronInput,
      'AsciiTheme': AsciiTheme.cronInput,
      'ChevronTheme': ChevronTheme.cronInput,
      'BracketTheme': BracketTheme.cronInput,
      'FormTheme': FormTheme.cronInput,
      'LedgerTheme': LedgerTheme.cronInput,
      'ColonTheme': ColonTheme.cronInput,
      'LineTheme': LineTheme.cronInput,
      'BlockTheme': BlockTheme.cronInput,
    };

/// The fifteen `timezoneSelect` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _TimezoneSelectFactory> _timezoneSelectSurface =
    <String, _TimezoneSelectFactory>{
      'PlainTheme': PlainTheme.timezoneSelect,
      'RailTheme': RailTheme.timezoneSelect,
      'BranchTheme': BranchTheme.timezoneSelect,
      'BoxTheme': BoxTheme.timezoneSelect,
      'RoundTheme': RoundTheme.timezoneSelect,
      'DoubleTheme': DoubleTheme.timezoneSelect,
      'MinimalTheme': MinimalTheme.timezoneSelect,
      'AsciiTheme': AsciiTheme.timezoneSelect,
      'ChevronTheme': ChevronTheme.timezoneSelect,
      'BracketTheme': BracketTheme.timezoneSelect,
      'FormTheme': FormTheme.timezoneSelect,
      'LedgerTheme': LedgerTheme.timezoneSelect,
      'ColonTheme': ColonTheme.timezoneSelect,
      'LineTheme': LineTheme.timezoneSelect,
      'BlockTheme': BlockTheme.timezoneSelect,
    };

/// The fifteen `pathInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _PathInputFactory> _pathInputSurface =
    <String, _PathInputFactory>{
      'PlainTheme': PlainTheme.pathInput,
      'RailTheme': RailTheme.pathInput,
      'BranchTheme': BranchTheme.pathInput,
      'BoxTheme': BoxTheme.pathInput,
      'RoundTheme': RoundTheme.pathInput,
      'DoubleTheme': DoubleTheme.pathInput,
      'MinimalTheme': MinimalTheme.pathInput,
      'AsciiTheme': AsciiTheme.pathInput,
      'ChevronTheme': ChevronTheme.pathInput,
      'BracketTheme': BracketTheme.pathInput,
      'FormTheme': FormTheme.pathInput,
      'LedgerTheme': LedgerTheme.pathInput,
      'ColonTheme': ColonTheme.pathInput,
      'LineTheme': LineTheme.pathInput,
      'BlockTheme': BlockTheme.pathInput,
    };

/// The fifteen `filePicker` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _FilePickerFactory> _filePickerSurface =
    <String, _FilePickerFactory>{
      'PlainTheme': PlainTheme.filePicker,
      'RailTheme': RailTheme.filePicker,
      'BranchTheme': BranchTheme.filePicker,
      'BoxTheme': BoxTheme.filePicker,
      'RoundTheme': RoundTheme.filePicker,
      'DoubleTheme': DoubleTheme.filePicker,
      'MinimalTheme': MinimalTheme.filePicker,
      'AsciiTheme': AsciiTheme.filePicker,
      'ChevronTheme': ChevronTheme.filePicker,
      'BracketTheme': BracketTheme.filePicker,
      'FormTheme': FormTheme.filePicker,
      'LedgerTheme': LedgerTheme.filePicker,
      'ColonTheme': ColonTheme.filePicker,
      'LineTheme': LineTheme.filePicker,
      'BlockTheme': BlockTheme.filePicker,
    };

/// The fifteen `directoryPicker` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _DirectoryPickerFactory> _directoryPickerSurface =
    <String, _DirectoryPickerFactory>{
      'PlainTheme': PlainTheme.directoryPicker,
      'RailTheme': RailTheme.directoryPicker,
      'BranchTheme': BranchTheme.directoryPicker,
      'BoxTheme': BoxTheme.directoryPicker,
      'RoundTheme': RoundTheme.directoryPicker,
      'DoubleTheme': DoubleTheme.directoryPicker,
      'MinimalTheme': MinimalTheme.directoryPicker,
      'AsciiTheme': AsciiTheme.directoryPicker,
      'ChevronTheme': ChevronTheme.directoryPicker,
      'BracketTheme': BracketTheme.directoryPicker,
      'FormTheme': FormTheme.directoryPicker,
      'LedgerTheme': LedgerTheme.directoryPicker,
      'ColonTheme': ColonTheme.directoryPicker,
      'LineTheme': LineTheme.directoryPicker,
      'BlockTheme': BlockTheme.directoryPicker,
    };

/// The fifteen `keypress` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _KeypressFactory> _keypressSurface =
    <String, _KeypressFactory>{
      'PlainTheme': PlainTheme.keypress,
      'RailTheme': RailTheme.keypress,
      'BranchTheme': BranchTheme.keypress,
      'BoxTheme': BoxTheme.keypress,
      'RoundTheme': RoundTheme.keypress,
      'DoubleTheme': DoubleTheme.keypress,
      'MinimalTheme': MinimalTheme.keypress,
      'AsciiTheme': AsciiTheme.keypress,
      'ChevronTheme': ChevronTheme.keypress,
      'BracketTheme': BracketTheme.keypress,
      'FormTheme': FormTheme.keypress,
      'LedgerTheme': LedgerTheme.keypress,
      'ColonTheme': ColonTheme.keypress,
      'LineTheme': LineTheme.keypress,
      'BlockTheme': BlockTheme.keypress,
    };

/// The fifteen `keyChordInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _KeyChordInputFactory> _keyChordInputSurface =
    <String, _KeyChordInputFactory>{
      'PlainTheme': PlainTheme.keyChordInput,
      'RailTheme': RailTheme.keyChordInput,
      'BranchTheme': BranchTheme.keyChordInput,
      'BoxTheme': BoxTheme.keyChordInput,
      'RoundTheme': RoundTheme.keyChordInput,
      'DoubleTheme': DoubleTheme.keyChordInput,
      'MinimalTheme': MinimalTheme.keyChordInput,
      'AsciiTheme': AsciiTheme.keyChordInput,
      'ChevronTheme': ChevronTheme.keyChordInput,
      'BracketTheme': BracketTheme.keyChordInput,
      'FormTheme': FormTheme.keyChordInput,
      'LedgerTheme': LedgerTheme.keyChordInput,
      'ColonTheme': ColonTheme.keyChordInput,
      'LineTheme': LineTheme.keyChordInput,
      'BlockTheme': BlockTheme.keyChordInput,
    };

/// The fifteen `durationInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _DurationInputFactory> _durationInputSurface =
    <String, _DurationInputFactory>{
      'PlainTheme': PlainTheme.durationInput,
      'RailTheme': RailTheme.durationInput,
      'BranchTheme': BranchTheme.durationInput,
      'BoxTheme': BoxTheme.durationInput,
      'RoundTheme': RoundTheme.durationInput,
      'DoubleTheme': DoubleTheme.durationInput,
      'MinimalTheme': MinimalTheme.durationInput,
      'AsciiTheme': AsciiTheme.durationInput,
      'ChevronTheme': ChevronTheme.durationInput,
      'BracketTheme': BracketTheme.durationInput,
      'FormTheme': FormTheme.durationInput,
      'LedgerTheme': LedgerTheme.durationInput,
      'ColonTheme': ColonTheme.durationInput,
      'LineTheme': LineTheme.durationInput,
      'BlockTheme': BlockTheme.durationInput,
    };

/// The fifteen `dateInput` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _DateInputFactory> _dateInputSurface =
    <String, _DateInputFactory>{
      'PlainTheme': PlainTheme.dateInput,
      'RailTheme': RailTheme.dateInput,
      'BranchTheme': BranchTheme.dateInput,
      'BoxTheme': BoxTheme.dateInput,
      'RoundTheme': RoundTheme.dateInput,
      'DoubleTheme': DoubleTheme.dateInput,
      'MinimalTheme': MinimalTheme.dateInput,
      'AsciiTheme': AsciiTheme.dateInput,
      'ChevronTheme': ChevronTheme.dateInput,
      'BracketTheme': BracketTheme.dateInput,
      'FormTheme': FormTheme.dateInput,
      'LedgerTheme': LedgerTheme.dateInput,
      'ColonTheme': ColonTheme.dateInput,
      'LineTheme': LineTheme.dateInput,
      'BlockTheme': BlockTheme.dateInput,
    };

/// The fifteen `text` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _TextFactory> _textSurface = <String, _TextFactory>{
  'PlainTheme': PlainTheme.text,
  'RailTheme': RailTheme.text,
  'BranchTheme': BranchTheme.text,
  'BoxTheme': BoxTheme.text,
  'RoundTheme': RoundTheme.text,
  'DoubleTheme': DoubleTheme.text,
  'MinimalTheme': MinimalTheme.text,
  'AsciiTheme': AsciiTheme.text,
  'ChevronTheme': ChevronTheme.text,
  'BracketTheme': BracketTheme.text,
  'FormTheme': FormTheme.text,
  'LedgerTheme': LedgerTheme.text,
  'ColonTheme': ColonTheme.text,
  'LineTheme': LineTheme.text,
  'BlockTheme': BlockTheme.text,
};

/// The fifteen `progress` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _ProgressFactory> _progressSurface =
    <String, _ProgressFactory>{
      'PlainTheme': PlainTheme.progress,
      'RailTheme': RailTheme.progress,
      'BranchTheme': BranchTheme.progress,
      'BoxTheme': BoxTheme.progress,
      'RoundTheme': RoundTheme.progress,
      'DoubleTheme': DoubleTheme.progress,
      'MinimalTheme': MinimalTheme.progress,
      'AsciiTheme': AsciiTheme.progress,
      'ChevronTheme': ChevronTheme.progress,
      'BracketTheme': BracketTheme.progress,
      'FormTheme': FormTheme.progress,
      'LedgerTheme': LedgerTheme.progress,
      'ColonTheme': ColonTheme.progress,
      'LineTheme': LineTheme.progress,
      'BlockTheme': BlockTheme.progress,
    };

/// The fifteen `spinner` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _SpinnerFactory> _spinnerSurface = <String, _SpinnerFactory>{
  'PlainTheme': PlainTheme.spinner,
  'RailTheme': RailTheme.spinner,
  'BranchTheme': BranchTheme.spinner,
  'BoxTheme': BoxTheme.spinner,
  'RoundTheme': RoundTheme.spinner,
  'DoubleTheme': DoubleTheme.spinner,
  'MinimalTheme': MinimalTheme.spinner,
  'AsciiTheme': AsciiTheme.spinner,
  'ChevronTheme': ChevronTheme.spinner,
  'BracketTheme': BracketTheme.spinner,
  'FormTheme': FormTheme.spinner,
  'LedgerTheme': LedgerTheme.spinner,
  'ColonTheme': ColonTheme.spinner,
  'LineTheme': LineTheme.spinner,
  'BlockTheme': BlockTheme.spinner,
};

/// The fifteen `multiSpinner` tear-offs.
///
/// The map value type is the typedef, so a namespace whose signature,
/// return type or generics drift fails to compile here.
final Map<String, _MultiSpinnerFactory> _multiSpinnerSurface =
    <String, _MultiSpinnerFactory>{
      'PlainTheme': PlainTheme.multiSpinner,
      'RailTheme': RailTheme.multiSpinner,
      'BranchTheme': BranchTheme.multiSpinner,
      'BoxTheme': BoxTheme.multiSpinner,
      'RoundTheme': RoundTheme.multiSpinner,
      'DoubleTheme': DoubleTheme.multiSpinner,
      'MinimalTheme': MinimalTheme.multiSpinner,
      'AsciiTheme': AsciiTheme.multiSpinner,
      'ChevronTheme': ChevronTheme.multiSpinner,
      'BracketTheme': BracketTheme.multiSpinner,
      'FormTheme': FormTheme.multiSpinner,
      'LedgerTheme': LedgerTheme.multiSpinner,
      'ColonTheme': ColonTheme.multiSpinner,
      'LineTheme': LineTheme.multiSpinner,
      'BlockTheme': BlockTheme.multiSpinner,
    };

/// The fifteen structural namespaces, keyed by the structure they render.
const _structures = <PromptStructure, String>{
  PromptStructure.plain: 'PlainTheme',
  PromptStructure.rail: 'RailTheme',
  PromptStructure.branch: 'BranchTheme',
  PromptStructure.box: 'BoxTheme',
  PromptStructure.round: 'RoundTheme',
  PromptStructure.double: 'DoubleTheme',
  PromptStructure.minimal: 'MinimalTheme',
  PromptStructure.ascii: 'AsciiTheme',
  PromptStructure.chevron: 'ChevronTheme',
  PromptStructure.bracket: 'BracketTheme',
  PromptStructure.form: 'FormTheme',
  PromptStructure.ledger: 'LedgerTheme',
  PromptStructure.colon: 'ColonTheme',
  PromptStructure.line: 'LineTheme',
  PromptStructure.block: 'BlockTheme',
};

/// The runtime half of the inventory: every factory invoked with non-default,
/// distinguishable arguments, and its result inspected.
final _probes = <_SurfaceProbe>[
  _Probe('textInput', _textInputSurface, (f, a) {
    final value = f(
      'Name',
      initialValue: 'seed',
      required: true,
      maxLength: 20,
      validate: a.validate,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<TextInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    expect(value.supplementaryHelp, a.help);
    return value.structure;
  }),
  _Probe('password', _passwordSurface, (f, a) {
    final value = f(
      'Token',
      mask: true,
      required: true,
      validate: a.validate,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<Password>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    expect(value.supplementaryHelp, a.help);
    return value.structure;
  }),
  _Probe('confirm', _confirmSurface, (f, a) {
    final value = f(
      'Proceed?',
      initialValue: true,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<Confirm>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    expect(value.supplementaryHelp, a.help);
    return value.structure;
  }),
  _Probe('checkbox', _checkboxSurface, (f, a) {
    final value = f(
      'Subscribe',
      initialValue: true,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<Checkbox>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    expect(value.supplementaryHelp, a.help);
    return value.structure;
  }),
  _Probe('toggle', _toggleSurface, (f, a) {
    final value = f(
      'Enable',
      initialValue: true,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<Toggle>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    expect(value.supplementaryHelp, a.help);
    return value.structure;
  }),
  _Probe('multiline', _multilineSurface, (f, a) {
    final value = f(
      'Notes',
      initialValue: 'seed',
      required: true,
      maxLength: 100,
      validate: a.validate,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<Multiline>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    expect(value.supplementaryHelp, a.help);
    return value.structure;
  }),
  _Probe('select', _selectSurface, (f, a) {
    final choices = [Choice('a', 'Alpha'), Choice('b', 'Beta')];
    final value = f(
      'Letter',
      choices,
      defaultValue: 'a',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<Select<String>>());
    expect(value.choices, choices);
    expect(value.defaultValue, 'a');
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('radio', _radioSurface, (f, a) {
    final choices = [Choice('a', 'Red'), Choice('b', 'Green')];
    final value = f(
      'Signal',
      choices,
      defaultValue: 'a',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<Radio<String>>());
    expect(value.choices, choices);
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('multiSelect', _multiSelectSurface, (f, a) {
    final choices = [Choice('a', 'Alpha'), Choice('b', 'Beta')];
    final value = f(
      'Choices',
      choices,
      defaultValues: const ['b'],
      min: 1,
      max: 2,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<MultiSelect<String>>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('slider', _sliderSurface, (f, a) {
    final value = f(
      'Volume',
      minimum: '0',
      maximum: '1',
      step: '0.2',
      initialValue: '0.4',
      precision: 2,
      units: 'dB',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<Slider>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('rangeSlider', _rangeSliderSurface, (f, a) {
    final value = f(
      'Window',
      minimum: '0',
      maximum: '10',
      step: '1',
      minimumGap: '2',
      initialLower: '3',
      initialUpper: '5',
      units: 'px',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<RangeSlider>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('treeSelect', _treeSelectSurface, (f, a) {
    final nodes = [TreeNode('a', 'A'), TreeNode('b', 'B')];
    final value = f(
      'Tree',
      nodes,
      defaultValue: 'b',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<TreeSelect<String>>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('timeInput', _timeInputSurface, (f, a) {
    final value = f(
      'Time',
      twelveHour: true,
      seconds: true,
      initialValue: '11:59:30 AM',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<TimeInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('tagInput', _tagInputSurface, (f, a) {
    final value = f(
      'Tags',
      style: TagStyle.snakeCase,
      maxLength: 8,
      validate: a.validate,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<TagInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('autocomplete', _autocompleteSurface, (f, a) {
    final value = f(
      'Suggestion',
      suggestions: a.suggest,
      initialValue: 'seed',
      required: true,
      maxLength: 20,
      validate: a.validate,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<Autocomplete>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('searchSelect', _searchSelectSurface, (f, a) {
    final value = f(
      'Fruit',
      [Choice('a', 'Apple')],
      defaultValue: 'a',
      search: (query) => [Choice('a', 'Apple')],
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<SearchSelect<String>>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('sortableSelect', _sortableSelectSurface, (f, a) {
    final value = f(
      'Order',
      [Choice('a', 'A'), Choice('b', 'B')],
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<SortableSelect<String>>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('commandPalette', _commandPaletteSurface, (f, a) {
    final value = f(
      'Commands',
      [Choice('save', 'Save')],
      defaultValue: 'save',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<CommandPalette<String>>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('maskedInput', _maskedInputSurface, (f, a) {
    final value = f(
      'Code',
      templates: [
        MaskTemplate('code', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ],
      initialValue: MaskedValue('code', ['1'], '1'),
      interpretation: MaskInterpretation.formatted,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<MaskedInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('numberInput', _numberInputSurface, (f, a) {
    final value = f(
      'Count',
      convention: NumericConvention.ascii(),
      decimal: true,
      minimum: '0',
      maximum: '99',
      precision: 1,
      conventionProvider: a.conventionProvider,
      required: false,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<NumberInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('portInput', _portInputSurface, (f, a) {
    final value = f(
      'Port',
      allowZero: true,
      initialValue: '8080',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<PortInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('ipAddressInput', _ipAddressInputSurface, (f, a) {
    final value = f(
      'Address',
      cidr: true,
      scoped: true,
      initialValue: '192.0.2.7/24',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<IPAddressInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('urlInput', _urlInputSurface, (f, a) {
    final value = f(
      'URL',
      allowedSchemes: const {'https'},
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<URLInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('emailInput', _emailInputSurface, (f, a) {
    final value = f(
      'Email',
      smtpUtf8: true,
      initialValue: 'ada@example.com',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<EmailInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('colorInput', _colorInputSurface, (f, a) {
    final value = f(
      'Colour',
      required: false,
      initialValue: '#fff',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<ColorInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('cronInput', _cronInputSurface, (f, a) {
    final value = f(
      'Schedule',
      profile: CronProfile.unix,
      initialValue: '* * * * *',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<CronInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('timezoneSelect', _timezoneSelectSurface, (f, a) {
    final value = f(
      'Zone',
      defaultValue: 'UTC',
      unavailable: const {'Pacific/Kiritimati': 'Not provisioned'},
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<TimezoneSelect>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('pathInput', _pathInputSurface, (f, a) {
    final value = f(
      'Path',
      base: _baseDirectory,
      initialValue: 'draft',
      allowNonexistent: true,
      target: PathTarget.file,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<PathInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('filePicker', _filePickerSurface, (f, a) {
    final value = f(
      'Workspace',
      base: _baseDirectory,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<FilePicker>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('directoryPicker', _directoryPickerSurface, (f, a) {
    final value = f(
      'Workspace',
      base: _baseDirectory,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<DirectoryPicker>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('keypress', _keypressSurface, (f, a) {
    final value = f(
      'Shortcut',
      requireObservation: true,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<Keypress>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('keyChordInput', _keyChordInputSurface, (f, a) {
    final value = f(
      'Sequence',
      requireObservation: true,
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<KeyChordInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('durationInput', _durationInputSurface, (f, a) {
    final value = f(
      'Span',
      durationMode: DurationInputMode.elapsed,
      signed: true,
      allowZero: false,
      minimumMicroseconds: 1000,
      initialValue: '1s',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<DurationInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('dateInput', _dateInputSurface, (f, a) {
    final value = f(
      'Date',
      order: DateFieldOrder.dayMonthYear,
      calendar: DateCalendar.gregorian,
      digits: DateDigits.ascii,
      initialValue: '29/02/2024',
      colors: a.colors,
      instructions: a.instructions,
      supplementaryHelp: a.help,
    );
    expect(value, isA<DateInput>());
    expect(value.colors, a.colors);
    expect(value.instructions, a.instructions);
    return value.structure;
  }),
  _Probe('text', _textSurface, (f, a) {
    final value = f('Build finished', kind: TextKind.success, colors: a.colors);
    expect(value, isA<Text>());
    expect(value.kind, TextKind.success);
    expect(value.colors, a.colors);
    return value.structure;
  }),
  _Probe('progress', _progressSurface, (f, a) {
    final value = f(
      'Copy',
      total: 4,
      interval: const Duration(seconds: 1),
      milestone: 25,
      colors: a.colors,
    );
    expect(value, isA<Progress>());
    expect(value.colors, a.colors);
    return value.structure;
  }),
  _Probe('spinner', _spinnerSurface, (f, a) {
    final value = f('Index', colors: a.colors);
    expect(value, isA<Spinner>());
    expect(value.colors, a.colors);
    return value.structure;
  }),
  _Probe('multiSpinner', _multiSpinnerSurface, (f, a) {
    final value = f(
      const ['fetch', 'build'],
      interval: const Duration(seconds: 1),
      colors: a.colors,
    );
    expect(value, isA<MultiSpinner>());
    expect(value.colors, a.colors);
    return value.structure;
  }),
];
