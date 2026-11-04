import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:characters/characters.dart';

part 'autocomplete.dart';

sealed class PromptResult<T> {}

final class Accepted<T> extends PromptResult<T> {
  Accepted(this.value);
  final T value;
}

final class InputEnded<T> extends PromptResult<T> {}

final class Cancelled<T> extends PromptResult<T> {}

final class Interrupted<T> extends PromptResult<T> {}

final class Unavailable<T> extends PromptResult<T> {
  Unavailable(this.reason);
  final String reason;
}

sealed class PromptSource {}

final class SuppliedAnswer extends PromptSource {
  SuppliedAnswer(this.value);
  final String value;
}

final class ScriptedInput extends PromptSource {
  ScriptedInput(this.input, this.output, {this.supportsRich = true});
  final Stream<String> input;
  final StringSink output;
  final bool supportsRich;
}

enum PromptMode { rich, linear, automatic }

bool _terminalActive = false;

final class TextInput {
  TextInput(
    this.label, {
    this.initialValue = '',
    this.required = false,
    this.validate,
    this.maxLength,
  }) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (maxLength != null && maxLength! < 0) {
      throw ArgumentError.value(maxLength, 'maxLength');
    }
    if (initialValue.runes.any((c) => c < 32 || c == 127) ||
        (maxLength != null && initialValue.characters.length > maxLength!)) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }
  final String label;
  final String initialValue;
  final bool required;
  final int? maxLength;
  final String? Function(String)? validate;
  bool _active = false;
  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          return await _terminal<String>(
            selected,
            output ?? stderr,
            (source, mode, restore) => _run(source, mode, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<String>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    if (source is SuppliedAnswer) {
      final value = source.value;
      if ((required && value.isEmpty) ||
          value.contains('\r') ||
          value.contains('\n') ||
          (maxLength != null && value.characters.length > maxLength!)) {
        return Unavailable(
          'Supplied answer does not satisfy text constraints.',
        );
      }
      final error = validate?.call(value);
      if (error != null) return Unavailable(error);
      return Accepted(value);
    }
    final scripted = source as ScriptedInput;
    if (mode == PromptMode.rich && !scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = scripted.supportsRich ? PromptMode.rich : PromptMode.linear;
    }
    scripted.output.writeln(
      '$label (${required ? 'Required' : 'Optional'}${maxLength == null ? '' : ', maximum $maxLength graphemes'}).',
    );
    scripted.output.writeln(
      'Left/Right move; Home/End go to boundaries; Backspace/Delete erase; Enter submits. Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
    );
    if (mode == PromptMode.linear) {
      scripted.output.writeln(
        r'Exact /help and /cancel are commands. Quote a command with a backslash; double a leading backslash to enter one. Identified paste is literal.',
      );
    }
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    var value = initialValue;
    try {
      while (true) {
        final result = await _edit(
          keys,
          value,
          scripted.output,
          linear: mode == PromptMode.linear,
          sequential: mode != PromptMode.rich,
          maxLength: maxLength,
        );
        if (result.action == 'cancel') return Cancelled();
        if (result.action == 'interrupt') return Interrupted();
        if (result.action != 'submit') return InputEnded();
        value = result.value;
        if (required && value.isEmpty) {
          scripted.output.writeln(
            'Required: enter a non-empty value and submit again.',
          );
          continue;
        }
        final error = validate?.call(value);
        if (error != null) {
          scripted.output.writeln(error);
          continue;
        }
        return Accepted(value);
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }
}

Future<({String action, String value})> _edit(
  _Keys keys,
  String initial,
  StringSink output, {
  bool linear = false,
  bool sequential = false,
  bool secret = false,
  bool mask = false,
  bool clearHelpCommand = false,
  int? maxLength,
  String? Function(String key, String text)? intercept,
  void Function(String text)? onChanged,
  int? pasteMaxLength,
  Set<String> extraCommands = const {},
  bool multilinePaste = false,
}) async {
  var chars = initial.characters.toList();
  var pos = chars.length;
  var provenance = List<bool>.filled(chars.length, false, growable: true);
  var synthetic = -1;
  if (linear &&
      (initial == '/cancel' ||
          initial == '/help' ||
          extraCommands.contains(initial) ||
          initial.startsWith('\\'))) {
    chars.insert(0, '\\');
    provenance.insert(0, false);
    pos++;
    synthetic = 0;
  }
  void insert(String data, bool isPaste) {
    final candidate = chars.take(pos).join() + data + chars.skip(pos).join();
    final count = candidate.characters.length - (synthetic >= 0 ? 1 : 0);
    final limit = isPaste ? (pasteMaxLength ?? maxLength) : maxLength;
    final commandPrefix =
        !isPaste &&
        extraCommands.isNotEmpty &&
        ({'/help', '/cancel', ...extraCommands}).any(
          (command) =>
              command.startsWith(candidate) ||
              ('\\$command').startsWith(candidate),
        );
    if (limit != null && count > limit && !commandPrefix) {
      output.writeln(
        'Insertion rejected: character limit is $limit graphemes.',
      );
      return;
    }
    final added = data.characters.toList();
    chars.insertAll(pos, added);
    if (synthetic >= pos) synthetic += added.length;
    provenance.insertAll(pos, List<bool>.filled(added.length, isPaste));
    pos += added.length;
    final caretOffset = chars.take(pos).join().length;
    final syntheticOffset = synthetic < 0
        ? -1
        : chars.take(synthetic).join().length;
    final flags = <bool>[];
    for (var i = 0; i < chars.length; i++) {
      flags.addAll(List<bool>.filled(chars[i].length, provenance[i]));
    }
    chars = chars.join().characters.toList();
    provenance = <bool>[];
    var offset = 0;
    pos = 0;
    synthetic = -1;
    for (var i = 0; i < chars.length; i++) {
      final end = offset + chars[i].length;
      provenance.add(flags.sublist(offset, end).contains(true));
      if (offset < caretOffset) pos = i + 1;
      if (syntheticOffset >= offset && syntheticOffset < end) synthetic = i;
      offset = end;
    }
  }

  void display() {
    if (secret) {
      if (mask) output.writeln('*' * chars.length);
      return;
    }
    if (sequential) {
      output.writeln('Current text: ${chars.join()}');
      output.writeln('Cursor position: $pos of ${chars.length} graphemes.');
      return;
    }
    output.write(
      '\r\x1b[2K> ${chars.take(pos).join()}\x1b[s${chars.skip(pos).join()}\x1b[u',
    );
  }

  display();
  onChanged?.call(chars.join());
  var help = false;
  while (true) {
    final key = await keys.next();
    if (key == null || key == '\x1a') return (action: 'eof', value: '');
    if (key == '\x03') return (action: 'interrupt', value: '');
    if (!help) {
      final action = intercept?.call(key, chars.join());
      if (action != null) return (action: action, value: chars.join());
    }
    if (key == '\x1b') {
      if (!help) return (action: 'cancel', value: '');
      help = false;
      output.writeln('Help dismissed.');
      display();
      continue;
    }
    if (key == '\x14') {
      help = true;
      output.writeln(
        'Help: arrows move, Backspace/Delete erase, Enter submits. Escape dismisses help; Ctrl+C interrupts.',
      );
      continue;
    }
    if (help) continue;
    if (key == '\r' || key == '\n') {
      output.writeln();
      var text = chars.join();
      if (synthetic >= 0) {
        final answer = chars.toList();
        answer[synthetic] = answer[synthetic].substring(1);
        text = answer.join();
      } else if (linear && !provenance.contains(true)) {
        if (text == '/help') {
          if (extraCommands.isNotEmpty) {
            output.writeln(
              'Help: ${extraCommands.join(', ')}, /help and /cancel are exact commands. Quote a command with a backslash; double a leading backslash. Identified paste is literal; unframed paste cannot be distinguished from typing.',
            );
          } else {
            output.writeln(
              r'Edit text; /cancel cancels. Use \/cancel or \/help for literal commands; double a leading backslash.',
            );
          }
          if (clearHelpCommand || extraCommands.isNotEmpty) {
            chars.clear();
            provenance.clear();
            pos = 0;
          }
          display();
          continue;
        }
        if (text == '/cancel') return (action: 'cancel', value: '');
        if (extraCommands.contains(text)) {
          return (action: 'command', value: text);
        }
        if (text.startsWith(r'\\') ||
            (text.startsWith(r'\') &&
                ({
                  '/cancel',
                  '/help',
                  ...extraCommands,
                }).contains(text.substring(1)))) {
          text = text.substring(1);
        }
      }
      return (action: 'submit', value: text);
    }
    if (key == '\x1b[D') {
      if (pos > 0) pos--;
    } else if (key == '\x1b[C') {
      if (pos < chars.length) pos++;
    } else if (key == '\x1b[H' || key == '\x01') {
      pos = 0;
    } else if (key == '\x1b[F' || key == '\x05') {
      pos = chars.length;
    } else if (key == '\x7f' || key == '\x08') {
      if (pos > 0) {
        pos--;
        chars.removeAt(pos);
        provenance.removeAt(pos);
        if (pos == synthetic) {
          synthetic = -1;
        } else if (pos < synthetic) {
          synthetic--;
        }
      }
    } else if (key == '\x1b[3~') {
      if (pos < chars.length) {
        chars.removeAt(pos);
        provenance.removeAt(pos);
        if (pos == synthetic) {
          synthetic = -1;
        } else if (pos < synthetic) {
          synthetic--;
        }
      }
    } else if (key == '\x1b[999~') {
      output.writeln('Paste rejected: exceeds 4096 UTF-16 code units.');
    } else if (key.startsWith('\x1b[200~')) {
      var data = key.substring(6, key.length - 6);
      if (multilinePaste) {
        data = data.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      }
      if (data.runes.any(
        (r) => (r < 32 && !(multilinePaste && (r == 9 || r == 10))) || r == 127,
      )) {
        output.writeln('Paste rejected: single-line printable text only.');
        display();
        continue;
      }
      insert(data, true);
    } else if (!key.startsWith('\x1b') && key.codeUnitAt(0) >= 32) {
      insert(key, false);
    }
    display();
    onChanged?.call(chars.join());
  }
}

class _Keys {
  final _controller = StreamController<String>();
  late final StreamSubscription<String> _subscription;
  late final StreamIterator<String> _iterator;
  String _buffer = '';
  bool _discardPaste = false;
  bool _afterCarriageReturn = false;
  Timer? _timer;
  _Keys(Stream<List<int>> source) {
    _iterator = StreamIterator(_controller.stream);
    _subscription = source
        .transform(utf8.decoder)
        .listen(
          (data) {
            _buffer += data;
            _parse();
          },
          onError: _controller.addError,
          onDone: () {
            _timer?.cancel();
            _controller.close();
          },
        );
  }
  void _parse() {
    _timer?.cancel();
    while (_buffer.isNotEmpty) {
      if (_discardPaste) {
        final end = _buffer.indexOf('\x1b[201~');
        if (end < 0) {
          if (_buffer.length > 5) {
            _buffer = _buffer.substring(_buffer.length - 5);
          }
          return;
        }
        _buffer = _buffer.substring(end + 6);
        _discardPaste = false;
        _controller.add('\x1b[999~');
        continue;
      }
      if (_buffer.startsWith('\x1b[200~')) {
        final end = _buffer.indexOf('\x1b[201~', 6);
        if (end >= 0) {
          _controller.add(
            end - 6 > 4096 ? '\x1b[999~' : _buffer.substring(0, end + 6),
          );
          _buffer = _buffer.substring(end + 6);
          continue;
        }
        if (_buffer.length > 4107) {
          _discardPaste = true;
          _buffer = _buffer.substring(_buffer.length - 5);
        }
        return;
      }
      if (_buffer.startsWith('\x1b')) {
        final match = RegExp(r'^\x1b\[[0-9;]*[A-Za-z~]').firstMatch(_buffer);
        if (match != null) {
          final s = match.group(0)!;
          _controller.add(s);
          _buffer = _buffer.substring(s.length);
          continue;
        }
        if (_buffer == '\x1b' || _buffer.startsWith('\x1b[')) {
          _timer = Timer(const Duration(milliseconds: 80), () {
            _controller.add('\x1b');
            _buffer = _buffer.substring(1);
            _parse();
          });
          return;
        }
      }
      final rune = _buffer.runes.first;
      final s = String.fromCharCode(rune);
      _controller.add(s);
      _buffer = _buffer.substring(s.length);
    }
  }

  Future<String?> next() async {
    while (await _iterator.moveNext()) {
      final key = _iterator.current;
      if (_afterCarriageReturn && key == '\n') {
        _afterCarriageReturn = false;
        continue;
      }
      _afterCarriageReturn = key == '\r';
      return key;
    }
    return null;
  }

  Future<void> close() async {
    _timer?.cancel();
    await _subscription.cancel();
    await _iterator.cancel();
  }
}

class _Console {
  final _dll = DynamicLibrary.open('kernel32.dll');
  late final int Function(int) getHandle = _dll
      .lookupFunction<IntPtr Function(Int32), int Function(int)>(
        'GetStdHandle',
      );
  late final int Function(int, Pointer<Uint32>) getMode = _dll
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetConsoleMode');
  late final int Function(int, Pointer<Uint32>) numberOfEvents = _dll
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetNumberOfConsoleInputEvents');
  late final int Function(int, Pointer<Uint8>, int, Pointer<Uint32>) readInput =
      _dll.lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>),
        int Function(int, Pointer<Uint8>, int, Pointer<Uint32>)
      >('ReadConsoleInputW');
  late final int Function(int, int) setMode = _dll
      .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'SetConsoleMode',
      );
}

// Read from the already-authorized console handle without subscribing to stdin:
// cancelling Dart's stdin subscription closes the process handle on Windows.
Stream<String> _consoleInput(_Console console, int handle) {
  late StreamController<String> controller;
  Timer? timer;
  StreamSubscription<ProcessSignal>? signals;
  int? highSurrogate;
  final count = calloc<Uint32>();
  final read = calloc<Uint32>();
  final records = calloc<Uint8>(20 * 64);
  void poll(Timer _) {
    if (console.numberOfEvents(handle, count) == 0) {
      controller.addError(StateError('Cannot inspect console input.'));
      return;
    }
    final available = count.value.clamp(0, 1);
    if (available == 0) return;
    if (console.readInput(handle, records, available, read) == 0) {
      controller.addError(StateError('Cannot read console input.'));
      return;
    }
    final bytes = ByteData.sublistView(records.asTypedList(20 * read.value));
    for (var i = 0; i < read.value; i++) {
      final base = i * 20;
      if (bytes.getUint16(base, Endian.little) != 1 ||
          bytes.getInt32(base + 4, Endian.little) == 0) {
        continue;
      }
      final code = bytes.getUint16(base + 14, Endian.little);
      final vk = bytes.getUint16(base + 10, Endian.little);
      if (code >= 0xd800 && code <= 0xdbff) {
        highSurrogate = code;
        continue;
      }
      if (highSurrogate != null && code >= 0xdc00 && code <= 0xdfff) {
        controller.add(String.fromCharCodes([highSurrogate!, code]));
        highSurrogate = null;
        continue;
      }
      if (highSurrogate != null) {
        controller.add('\ufffd');
        highSurrogate = null;
      }
      final key = code != 0
          ? String.fromCharCode(code)
          : switch (vk) {
              0x25 => '\x1b[D',
              0x26 => '\x1b[A',
              0x27 => '\x1b[C',
              0x28 => '\x1b[B',
              0x24 => '\x1b[H',
              0x23 => '\x1b[F',
              0x2e => '\x1b[3~',
              _ => '',
            };
      if (key.isNotEmpty) controller.add(key);
    }
  }

  controller = StreamController<String>(
    onListen: () {
      signals = ProcessSignal.sigint.watch().listen(
        (_) => controller.add('\x03'),
      );
      timer = Timer.periodic(const Duration(milliseconds: 5), poll);
    },
    onCancel: () async {
      timer?.cancel();
      await signals?.cancel();
      calloc.free(count);
      calloc.free(read);
      calloc.free(records);
    },
  );
  return controller.stream;
}

Future<PromptResult<T>> _terminal<T>(
  PromptMode mode,
  Stdout outputStream,
  Future<PromptResult<T>> Function(ScriptedInput, PromptMode, void Function())
  run,
) async {
  if (!Platform.isWindows || !stdin.hasTerminal) {
    return Unavailable(
      'Interactive console input is unavailable; supply an explicit input source.',
    );
  }
  final rich =
      mode == PromptMode.rich ||
      (mode == PromptMode.automatic && outputStream.hasTerminal);
  if (rich && !outputStream.hasTerminal) {
    return Unavailable(
      'Rich interaction unavailable on the selected output; use linear or automatic mode.',
    );
  }
  final console = _Console();
  final input = console.getHandle(-10);
  final output = console.getHandle(identical(outputStream, stdout) ? -11 : -12);
  final inputMode = calloc<Uint32>();
  final outputMode = calloc<Uint32>();
  var inputAcquired = false;
  var outputAcquired = false;
  void restore() {
    try {
      if (outputAcquired) {
        outputAcquired = false;
        try {
          outputStream.write('\x1b[?2004l\n');
        } finally {
          if (console.setMode(output, outputMode.value) == 0) {
            throw StateError('Cannot restore console output.');
          }
        }
      }
    } finally {
      if (inputAcquired) {
        inputAcquired = false;
        if (console.setMode(input, inputMode.value) == 0) {
          throw StateError('Cannot restore console input.');
        }
      }
    }
  }

  try {
    if (console.getMode(input, inputMode) == 0 ||
        (outputStream.hasTerminal &&
            console.getMode(output, outputMode) == 0)) {
      return Unavailable('Console capability unavailable.');
    }
    if (console.setMode(input, inputMode.value & ~0x207) == 0) {
      return Unavailable('Cannot acquire console input.');
    }
    inputAcquired = true;
    if (outputStream.hasTerminal) {
      if (console.setMode(output, outputMode.value | 4) == 0) {
        return Unavailable('Cannot enable rich console output.');
      }
      outputAcquired = true;
      outputStream.write('\x1b[?2004h');
    }
    return await run(
      ScriptedInput(
        _consoleInput(console, input),
        outputStream,
        supportsRich: outputStream.hasTerminal,
      ),
      rich ? PromptMode.rich : PromptMode.linear,
      restore,
    );
  } finally {
    try {
      restore();
    } finally {
      calloc.free(inputMode);
      calloc.free(outputMode);
    }
  }
}

/// A secret prompt. Masking discloses the secret's length; prefill retains a
/// caller-provided secret in memory. Terminal and screen-reader echo behavior
/// requires independent verification.
final class Password {
  Password(
    this.label, {
    this.initialValue = '',
    this.mask = false,
    this.required = false,
    this.validate,
  }) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (initialValue.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError('Invalid secret prefill.');
    }
  }
  final String label;
  final String initialValue;
  final bool mask;
  final bool required;
  final String? Function(String)? validate;
  bool _active = false;

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          return await _terminal<String>(
            selected,
            output ?? stderr,
            (source, mode, restore) => _run(source, mode, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected);
    } on _SecretValidationException {
      return Unavailable('Secret validation failed.');
    } finally {
      _active = false;
    }
  }

  bool _validationFailed(String value) {
    try {
      return validate?.call(value) != null;
    } catch (_) {
      throw const _SecretValidationException();
    }
  }

  Future<PromptResult<String>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    if (source is SuppliedAnswer) {
      final value = source.value;
      if ((required && value.isEmpty) ||
          value.contains('\r') ||
          value.contains('\n') ||
          _validationFailed(value)) {
        return Unavailable('Secret does not satisfy the requirements.');
      }
      return Accepted(value);
    }
    final scripted = source as ScriptedInput;
    if (mode == PromptMode.rich && !scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    scripted.output.writeln(
      '$label (${required ? 'Required' : 'Optional'}). Hidden entry; Enter opens actions. Ctrl+T for help; Escape cancels; Ctrl+C interrupts.',
    );
    if (mask) {
      scripted.output.writeln('Masking is enabled and discloses length.');
    }
    if (initialValue.isNotEmpty) {
      scripted.output.writeln(
        'Secret prefill is enabled; the secret is retained in memory.',
      );
    }
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    var value = initialValue;
    try {
      while (true) {
        final edit = await _edit(
          keys,
          value,
          scripted.output,
          secret: true,
          mask: mask,
        );
        if (edit.action == 'cancel') return Cancelled();
        if (edit.action == 'interrupt') return Interrupted();
        if (edit.action != 'submit') return InputEnded();
        value = edit.value;
        while (true) {
          scripted.output.writeln(
            'Actions: submit, edit, clear, help, cancel. /help and /cancel are also available. Enter an action:',
          );
          final action = await _edit(keys, '', scripted.output, secret: true);
          if (action.action == 'cancel') return Cancelled();
          if (action.action == 'interrupt') return Interrupted();
          if (action.action != 'submit') return InputEnded();
          switch (action.value) {
            case 'submit':
              if ((required && value.isEmpty) || _validationFailed(value)) {
                scripted.output.writeln(
                  'Secret does not satisfy the requirements. Choose edit or clear and try again.',
                );
                continue;
              }
              return Accepted(value);
            case 'edit':
              break;
            case 'clear':
              value = '';
              break;
            case 'cancel':
            case '/cancel':
              return Cancelled();
            case 'help':
            case '/help':
              scripted.output.writeln(
                'Submit validates; edit reopens the secret; clear starts empty; cancel ends the prompt.',
              );
              continue;
            default:
              scripted.output.writeln('Choose one of the listed actions.');
              continue;
          }
          break;
        }
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }
}

final class _SecretValidationException implements Exception {
  const _SecretValidationException();
}

/// A Yes/No question whose draft is not submitted by a shortcut.
final class Confirm extends _BooleanPrompt {
  Confirm(super.label, {super.initialValue = false})
    : super(kind: _BooleanKind.confirm);
}

final class Checkbox extends _BooleanPrompt {
  Checkbox(super.label, {super.initialValue = false})
    : super(kind: _BooleanKind.checkbox);
}

final class Toggle extends _BooleanPrompt {
  Toggle(super.label, {super.initialValue = false})
    : super(kind: _BooleanKind.toggle);
}

enum _BooleanKind { confirm, checkbox, toggle }

abstract class _BooleanPrompt {
  _BooleanPrompt(this.label, {required this.initialValue, required this.kind}) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
  }
  final String label;
  final bool initialValue;
  final _BooleanKind kind;
  bool _active = false;

  Future<PromptResult<bool>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          return await _terminal<bool>(
            selected,
            output ?? stderr,
            (source, mode, restore) => _run(source, mode, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected);
    } finally {
      _active = false;
    }
  }

  String _state(bool value) => switch (kind) {
    _BooleanKind.confirm => value ? 'Yes' : 'No',
    _BooleanKind.checkbox => value ? 'checked' : 'unchecked',
    _BooleanKind.toggle => value ? 'on' : 'off',
  };

  bool? _parse(String value) => switch (value.toLowerCase()) {
    'yes' || 'y' => true,
    'no' || 'n' => false,
    _ => null,
  };

  Future<PromptResult<bool>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    if (source is SuppliedAnswer) {
      final value = _parse(source.value);
      return value == null ? Unavailable('Supply yes or no.') : Accepted(value);
    }
    final scripted = source as ScriptedInput;
    if (mode == PromptMode.rich && !scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = scripted.supportsRich ? PromptMode.rich : PromptMode.linear;
    }
    final out = scripted.output;
    var draft = initialValue;
    out.writeln(
      '$label Default: ${_state(initialValue)}. Draft: ${_state(draft)}.',
    );
    if (mode == PromptMode.linear) {
      out.writeln(
        r'Enter yes/y or no/n, or an empty line for the displayed default. Exact /help and /cancel are commands; quote commands with a backslash and double a leading backslash. Identified paste is literal.',
      );
    } else {
      out.writeln(
        '${kind == _BooleanKind.confirm ? 'Y/N changes the draft' : 'Space toggles the draft'}; Enter submits. Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
      );
    }
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    try {
      if (mode == PromptMode.linear) {
        var entry = '';
        while (true) {
          final result = await _edit(
            keys,
            entry,
            out,
            linear: true,
            sequential: true,
            clearHelpCommand: true,
          );
          if (result.action == 'cancel') return Cancelled();
          if (result.action == 'interrupt') return Interrupted();
          if (result.action != 'submit') return InputEnded();
          entry = result.value;
          final answer = entry.isEmpty ? draft : _parse(entry);
          if (answer != null) {
            out.writeln('Accepted: ${_state(answer)}.');
            return Accepted(answer);
          }
          out.writeln(
            'Enter yes/y or no/n, or erase the line and submit the displayed default.',
          );
        }
      }
      var help = false;
      while (true) {
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          out.writeln('Help dismissed. Draft: ${_state(draft)}.');
          continue;
        }
        if (key == '\x14') {
          help = true;
          out.writeln(
            'Help: ${kind == _BooleanKind.confirm ? 'Y/N changes the draft' : 'Space toggles the draft'}; Enter submits. Escape dismisses help; Ctrl+C interrupts.',
          );
          continue;
        }
        if (help) continue;
        if (key == '\r' || key == '\n') {
          out.writeln('Accepted: ${_state(draft)}.');
          return Accepted(draft);
        }
        if (kind == _BooleanKind.confirm &&
            (key == 'y' || key == 'Y' || key == 'n' || key == 'N')) {
          draft = key.toLowerCase() == 'y';
          out.writeln('Draft: ${_state(draft)}.');
        } else if (kind != _BooleanKind.confirm && key == ' ') {
          draft = !draft;
          out.writeln('Draft: ${_state(draft)}.');
        }
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }
}

final class Multiline {
  Multiline(
    this.label, {
    this.initialValue = '',
    this.required = false,
    this.validate,
    this.maxLength,
  }) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (maxLength != null && maxLength! < 0) {
      throw ArgumentError.value(maxLength, 'maxLength');
    }
    if (maxLength != null &&
        _normalize(initialValue).characters.length > maxLength!) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }
  final String label;
  final String initialValue;
  final bool required;
  final String? Function(String)? validate;
  final int? maxLength;
  bool _active = false;
  static String _normalize(String value) =>
      value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  String? _error(String value) {
    if (required && value.isEmpty) return 'Required: enter a non-empty value.';
    if (maxLength != null && value.characters.length > maxLength!) {
      return 'Maximum $maxLength graphemes.';
    }
    return validate?.call(value);
  }

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          return await _terminal<String>(
            selected,
            output ?? stderr,
            (source, mode, restore) => _run(source, mode, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<String>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    if (source is SuppliedAnswer) {
      final value = _normalize(source.value);
      final error = _error(value);
      return error == null ? Accepted(value) : Unavailable(error);
    }
    final scripted = source as ScriptedInput;
    if (mode == PromptMode.rich && !scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = scripted.supportsRich ? PromptMode.rich : PromptMode.linear;
    }
    final out = scripted.output;
    out.writeln(
      mode == PromptMode.linear
          ? '$label (${required ? 'Required' : 'Optional'}${maxLength == null ? '' : ', maximum $maxLength graphemes'}). Enter a line; /list, /edit, /insert, /remove, /done, /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal; unframed paste cannot be distinguished from typing.'
          : '$label (${required ? 'Required' : 'Optional'}${maxLength == null ? '' : ', maximum $maxLength graphemes'}). Enter inserts a newline. Tab selects Finish or Insert tab; Enter activates the action. Arrows move, Home/End reach line boundaries, Backspace/Delete erase. Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
    );
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    if (mode == PromptMode.linear) {
      final lines = initialValue.isEmpty
          ? <String>[]
          : _normalize(initialValue).split('\n');
      try {
        while (true) {
          final result = await _edit(
            keys,
            '',
            out,
            linear: true,
            sequential: true,
            extraCommands: const {
              '/list',
              '/edit',
              '/insert',
              '/remove',
              '/done',
            },
            multilinePaste: true,
            maxLength: maxLength == null
                ? null
                : (maxLength! -
                          (lines.isEmpty
                              ? 0
                              : lines.join('\n').characters.length + 1))
                      .clamp(0, maxLength!),
            pasteMaxLength: maxLength == null
                ? null
                : (maxLength! -
                          (lines.isEmpty
                              ? 0
                              : lines.join('\n').characters.length + 1))
                      .clamp(0, maxLength!),
          );
          if (result.action == 'cancel') return Cancelled();
          if (result.action == 'interrupt') return Interrupted();
          if (result.action != 'submit' && result.action != 'command') {
            return InputEnded();
          }
          if (result.action == 'submit') {
            lines.addAll(result.value.split('\n'));
            continue;
          }
          if (result.value == '/done') {
            final value = lines.join('\n');
            final error = _error(value);
            if (error == null) return Accepted(value);
            out.writeln(error);
            continue;
          }
          if (result.value == '/list') {
            for (var i = 0; i < lines.length; i++) {
              out.writeln('${i + 1}: ${lines[i]}');
            }
            continue;
          }
          if (result.value == '/edit' ||
              result.value == '/insert' ||
              result.value == '/remove') {
            out.writeln('Enter line number:');
            final number = await _edit(
              keys,
              '',
              out,
              linear: true,
              sequential: true,
            );
            if (number.action == 'cancel') return Cancelled();
            if (number.action == 'interrupt') return Interrupted();
            if (number.action != 'submit') return InputEnded();
            final index = (int.tryParse(number.value) ?? 0) - 1;
            if (index < 0 ||
                index >= lines.length + (result.value == '/insert' ? 1 : 0)) {
              out.writeln('Invalid line number.');
              continue;
            }
            if (result.value == '/remove') {
              out.writeln('Remove line ${index + 1}? Enter y to confirm.');
              final confirm = await _edit(
                keys,
                '',
                out,
                linear: true,
                sequential: true,
              );
              if (confirm.action == 'cancel') return Cancelled();
              if (confirm.action == 'interrupt') return Interrupted();
              if (confirm.action != 'submit') return InputEnded();
              if (confirm.value == 'y') lines.removeAt(index);
            } else {
              out.writeln('Edit line:');
              final edited = await _edit(
                keys,
                result.value == '/edit' ? lines[index] : '',
                out,
                linear: true,
                sequential: true,
                extraCommands: const {
                  '/list',
                  '/edit',
                  '/insert',
                  '/remove',
                  '/done',
                },
                multilinePaste: true,
                maxLength: maxLength == null
                    ? null
                    : (maxLength! -
                              (result.value == '/edit'
                                  ? lines.join('\n').characters.length -
                                        lines[index].characters.length
                                  : lines.isEmpty
                                  ? 0
                                  : lines.join('\n').characters.length + 1))
                          .clamp(0, maxLength!),
                pasteMaxLength: maxLength == null
                    ? null
                    : (maxLength! -
                              (result.value == '/edit'
                                  ? lines.join('\n').characters.length -
                                        lines[index].characters.length
                                  : lines.isEmpty
                                  ? 0
                                  : lines.join('\n').characters.length + 1))
                          .clamp(0, maxLength!),
              );
              if (edited.action == 'cancel') return Cancelled();
              if (edited.action == 'interrupt') return Interrupted();
              if (edited.action == 'command') {
                out.writeln('Quote commands to enter them as text.');
                continue;
              }
              if (edited.action != 'submit') return InputEnded();
              if (result.value == '/edit') lines.removeAt(index);
              lines.insertAll(index, edited.value.split('\n'));
            }
            continue;
          }
          lines.add(result.value);
        }
      } finally {
        try {
          beforeClose?.call();
        } finally {
          await keys.close();
        }
      }
    }
    var chars = _normalize(initialValue).characters.toList();
    var pos = chars.length;
    var action = 0;
    var help = false;
    void insert(String text) {
      final before = chars.take(pos).join() + text;
      final candidate = before + chars.skip(pos).join();
      if (maxLength != null && candidate.characters.length > maxLength!) {
        out.writeln(
          'Insertion rejected: character limit is $maxLength graphemes.',
        );
        return;
      }
      chars = candidate.characters.toList();
      var offset = 0;
      pos = 0;
      while (pos < chars.length && offset < before.length) {
        offset += chars[pos].length;
        pos++;
      }
    }

    void display() {
      var start = pos;
      while (start > 0 && chars[start - 1] != '\n') {
        start--;
      }
      var end = pos;
      while (end < chars.length && chars[end] != '\n') {
        end++;
      }
      final line = chars.take(start).where((c) => c == '\n').length + 1;
      String visible(Iterable<String> part) =>
          part.join().replaceAll('\t', '⇥');
      out.write(
        '\r\x1b[2KLine $line: ${visible(chars.getRange(start, pos))}\x1b[s${visible(chars.getRange(pos, end))}\x1b[u',
      );
    }

    display();
    try {
      while (true) {
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x14') {
          help = true;
          out.writeln(
            'Help: arrows move; Home/End move to line boundaries; Backspace/Delete erase; Enter inserts a newline. Tab selects Finish or Insert tab; Enter activates an action. Escape dismisses help or cancels; Ctrl+C interrupts.',
          );
          continue;
        }
        if (help) {
          if (key == '\x1b') {
            help = false;
            out.writeln('Help dismissed.');
          }
          continue;
        }
        if (key == '\x1b') {
          if (action != 0) {
            action = 0;
            out.writeln('Edit');
            continue;
          }
          return Cancelled();
        }
        if (key == '\t') {
          action = (action + 1) % 3;
          out.writeln(['Edit', 'Finish', 'Insert tab'][action]);
          continue;
        }
        if (key == '\r' || key == '\n') {
          if (action == 1) {
            final value = chars.join();
            final error = _error(value);
            if (error == null) return Accepted(value);
            out.writeln(error);
            action = 0;
            continue;
          }
          if (action == 2) {
            insert('\t');
            action = 0;
          } else {
            insert('\n');
          }
        } else if (action != 0) {
          continue;
        } else if (key == '\x1b[A' || key == '\x1b[B') {
          var start = pos;
          while (start > 0 && chars[start - 1] != '\n') {
            start--;
          }
          final column = pos - start;
          if (key == '\x1b[A' && start > 0) {
            final end = start - 1;
            var previous = end;
            while (previous > 0 && chars[previous - 1] != '\n') {
              previous--;
            }
            pos = (previous + column).clamp(previous, end);
          } else if (key == '\x1b[B') {
            var end = pos;
            while (end < chars.length && chars[end] != '\n') {
              end++;
            }
            if (end < chars.length) {
              final next = end + 1;
              var nextEnd = next;
              while (nextEnd < chars.length && chars[nextEnd] != '\n') {
                nextEnd++;
              }
              pos = (next + column).clamp(next, nextEnd);
            }
          }
        } else if (key == '\x1b[D') {
          if (pos > 0) pos--;
        } else if (key == '\x1b[C') {
          if (pos < chars.length) pos++;
        } else if (key == '\x1b[H' || key == '\x01') {
          while (pos > 0 && chars[pos - 1] != '\n') {
            pos--;
          }
        } else if (key == '\x1b[F' || key == '\x05') {
          while (pos < chars.length && chars[pos] != '\n') {
            pos++;
          }
        } else if (key == '\x7f' || key == '\x08') {
          if (pos > 0) {
            chars.removeAt(--pos);
          }
        } else if (key == '\x1b[3~') {
          if (pos < chars.length) {
            chars.removeAt(pos);
          }
        } else if (key == '\x1b[999~') {
          out.writeln('Paste rejected: exceeds 4096 UTF-16 code units.');
        } else if (key.startsWith('\x1b[200~')) {
          final data = _normalize(key.substring(6, key.length - 6));
          if (data.runes.any(
            (r) => (r < 32 && r != 9 && r != 10) || r == 127,
          )) {
            out.writeln('Paste rejected: unsupported control character.');
          } else {
            insert(data);
          }
        } else if (!key.startsWith('\x1b') &&
            key.codeUnitAt(0) >= 32 &&
            key.codeUnitAt(0) != 127) {
          insert(key);
        }
        display();
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }
}

/// One choice, identified independently of its display label.
final class Choice<T> {
  Choice(this.value, this.label, {this.disabledReason}) {
    if (label.trim().isEmpty ||
        label.runes.any((c) => c < 32 || c == 127) ||
        (disabledReason != null &&
            (disabledReason!.trim().isEmpty ||
                disabledReason!.runes.any((c) => c < 32 || c == 127)))) {
      throw ArgumentError(
        'Choice labels and reasons must be nonempty safe text.',
      );
    }
  }
  final T value;
  final String label;
  final String? disabledReason;
}

final class Select<T> extends _SingleChoice<T> {
  Select(super.label, super.choices, {super.defaultValue})
    : super(radio: false);
}

final class Radio<T> extends _SingleChoice<T> {
  Radio(super.label, super.choices, {super.defaultValue}) : super(radio: true);
}

abstract class _SingleChoice<T> {
  _SingleChoice(
    this.label,
    List<Choice<T>> choices, {
    this.defaultValue,
    required this.radio,
  }) : choices = List.unmodifiable(choices) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (choices.map((c) => c.value).toSet().length != choices.length) {
      throw ArgumentError('Choice identities must be unique.');
    }
    if (defaultValue != null && !choices.any((c) => c.value == defaultValue)) {
      throw ArgumentError('Default identity is not a choice.');
    }
  }
  final String label;
  final List<Choice<T>> choices;
  final T? defaultValue;
  final bool radio;
  bool _active = false;

  Future<PromptResult<T>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          return await _terminal<T>(
            selected,
            output ?? stderr,
            (source, mode, restore) => _run(source, mode, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<T>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    if (source is SuppliedAnswer) {
      final n = int.tryParse(source.value);
      if (n == null ||
          n < 1 ||
          n > choices.length ||
          choices[n - 1].disabledReason != null) {
        return Unavailable('Supply an enabled choice reference.');
      }
      return Accepted(choices[n - 1].value);
    }
    final scripted = source as ScriptedInput;
    if (mode == PromptMode.rich && !scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = scripted.supportsRich ? PromptMode.rich : PromptMode.linear;
    }
    final out = scripted.output;
    var focus = defaultValue == null
        ? -1
        : choices.indexWhere((c) => c.value == defaultValue);
    if (focus < 0) focus = choices.indexWhere((c) => c.disabledReason == null);
    if (focus < 0 && choices.isNotEmpty) focus = 0;
    var page = 0;
    const pageSize = 10;
    void show() {
      out.writeln(
        '$label ${radio ? 'Radio' : 'Select'}: ${choices.length} choices.',
      );
      if (choices.isEmpty) out.writeln('No choices available.');
      final start = mode == PromptMode.linear ? page * pageSize : 0;
      final end = mode == PromptMode.linear
          ? (start + pageSize).clamp(0, choices.length)
          : choices.length;
      if (mode == PromptMode.linear && choices.isNotEmpty) {
        out.writeln(
          'Page ${page + 1} of ${(choices.length + pageSize - 1) ~/ pageSize}.',
        );
      }
      for (var i = start; i < end; i++) {
        final c = choices[i];
        out.writeln(
          '${i + 1}. ${radio ? '( ) ' : ''}${c.label}${i == focus ? ' [focused]' : ''}${defaultValue != null && c.value == defaultValue ? ' [default]' : ''}${c.disabledReason == null ? '' : ' [unavailable: ${c.disabledReason}]'}',
        );
      }
    }

    show();
    out.writeln(
      mode == PromptMode.rich
          ? 'Up/Down navigate; Enter accepts the focused enabled choice. Ctrl+T help; Escape cancels; Ctrl+C interrupts.'
          : r'Enter a stable choice number to accept it. /next, /previous, /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal.',
    );
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    try {
      if (mode == PromptMode.linear) {
        var entry = '';
        while (true) {
          final result = await _edit(
            keys,
            entry,
            out,
            linear: true,
            sequential: true,
            extraCommands: const {'/next', '/previous'},
          );
          if (result.action == 'cancel') return Cancelled();
          if (result.action == 'interrupt') return Interrupted();
          if (result.action == 'command') {
            if (result.value == '/next' &&
                (page + 1) * pageSize < choices.length) {
              page++;
            }
            if (result.value == '/previous' && page > 0) page--;
            entry = '';
            show();
            continue;
          }
          if (result.action != 'submit') return InputEnded();
          entry = result.value;
          final n = int.tryParse(entry);
          if (n == null || n < 1 || n > choices.length) {
            out.writeln('Enter a valid choice reference.');
            continue;
          }
          final c = choices[n - 1];
          if (c.disabledReason != null) {
            out.writeln(
              'Unavailable: ${c.disabledReason}. Choose an enabled reference.',
            );
            continue;
          }
          out.writeln('Accepted: ${c.label}.');
          return Accepted(c.value);
        }
      }
      var help = false;
      while (true) {
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          show();
          continue;
        }
        if (key == '\x14') {
          help = true;
          out.writeln(
            'Help: Up/Down navigate; Enter accepts the focused enabled choice; Escape dismisses help.',
          );
          continue;
        }
        if (help) continue;
        if (key == '\x1b[A' && focus > 0) {
          focus--;
          show();
        }
        if (key == '\x1b[B' && focus >= 0 && focus < choices.length - 1) {
          focus++;
          show();
        }
        if (key == '\r' || key == '\n') {
          if (focus < 0) {
            out.writeln('No choice available.');
            continue;
          }
          final c = choices[focus];
          if (c.disabledReason != null) {
            out.writeln(
              'Unavailable: ${c.disabledReason}. Navigate to an enabled choice.',
            );
            continue;
          }
          out.writeln('Accepted: ${c.label}.');
          return Accepted(c.value);
        }
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }
}
