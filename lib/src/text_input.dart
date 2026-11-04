import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:characters/characters.dart';

part 'autocomplete.dart';
part 'search_select.dart';

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
  bool allowCommandPrefixes = false,
  int? maxLength,
  String? Function(String key, String text)? intercept,
  void Function(String text)? onChanged,
  void Function(bool literal)? onSubmit,
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
        (extraCommands.isNotEmpty || allowCommandPrefixes) &&
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
      if (action == 'handled') {
        display();
        continue;
      }
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
      final literal =
          synthetic >= 0 ||
          provenance.contains(true) ||
          (linear &&
              (text.startsWith(r'\\') ||
                  (text.startsWith(r'\') &&
                      {
                        '/cancel',
                        '/help',
                        ...extraCommands,
                      }.contains(text.substring(1)))));
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
      onSubmit?.call(literal);
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

/// A draft set of choices, submitted in their original order.
final class MultiSelect<T> {
  MultiSelect(
    this.label,
    List<Choice<T>> choices, {
    List<T> defaultValues = const [],
    this.min = 0,
    this.max,
  }) : choices = List.unmodifiable(choices),
       defaultValues = List.unmodifiable(defaultValues) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (choices.map((c) => c.value).toSet().length != choices.length) {
      throw ArgumentError('Choice identities must be unique.');
    }
    if (min < 0 || (max != null && (max! < min || max! < 0))) {
      throw ArgumentError('Invalid selection bounds.');
    }
    if (defaultValues.toSet().length != defaultValues.length ||
        defaultValues.any(
          (v) => !choices.any((c) => c.value == v && c.disabledReason == null),
        ) ||
        (max != null && defaultValues.length > max!)) {
      throw ArgumentError('Invalid default choices.');
    }
  }
  final String label;
  final List<Choice<T>> choices;
  final List<T> defaultValues;
  final int min;
  final int? max;
  bool _active = false;

  Future<PromptResult<List<T>>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selectedMode =
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
          return await _terminal<List<T>>(
            selectedMode,
            output ?? stderr,
            (source, mode, restore) => _run(source, mode, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selectedMode);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<List<T>>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    if (source is SuppliedAnswer) {
      final refs = source.value.isEmpty ? <String>[] : source.value.split(',');
      final indices = <int>{};
      for (final ref in refs) {
        if (!RegExp(r'^[1-9][0-9]*$').hasMatch(ref)) {
          return Unavailable('Supply comma-separated choice references.');
        }
        final n = int.tryParse(ref);
        if (n == null ||
            n > choices.length ||
            choices[n - 1].disabledReason != null ||
            !indices.add(n - 1)) {
          return Unavailable('Supply unique enabled choice references.');
        }
      }
      if (indices.length < min || (max != null && indices.length > max!)) {
        return Unavailable('Selection count is outside the configured bounds.');
      }
      return Accepted([
        for (var i = 0; i < choices.length; i++)
          if (indices.contains(i)) choices[i].value,
      ]);
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
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    final selected = <int>{
      for (var i = 0; i < choices.length; i++)
        if (defaultValues.contains(choices[i].value)) i,
    };
    var filter = '';
    var focus = 0;
    var page = 0;
    const size = 10;
    List<int> visible() => [
      for (var i = 0; i < choices.length; i++)
        if (choices[i].label.toLowerCase().contains(filter.toLowerCase())) i,
    ];
    void show() {
      final items = visible();
      final hidden = selected.where((i) => !items.contains(i)).length;
      out.writeln(
        '$label MultiSelect: ${selected.length} selected, $hidden hidden selected; ${items.length} results. Minimum $min${max == null ? '' : ', maximum $max'}.',
      );
      if (items.isEmpty) out.writeln('No matching choices.');
      final shown = mode == PromptMode.linear
          ? items.skip(page * size).take(size)
          : items;
      if (mode == PromptMode.linear && items.isNotEmpty) {
        out.writeln(
          'Page ${page + 1} of ${(items.length + size - 1) ~/ size}.',
        );
      }
      for (final i in shown) {
        final c = choices[i];
        out.writeln(
          '${i + 1}. ${c.label} [${selected.contains(i) ? 'checked' : 'unchecked'}]${mode == PromptMode.rich && items.isNotEmpty && items[focus] == i ? ' [focused]' : ''}${defaultValues.contains(c.value) ? ' [default]' : ''}${c.disabledReason == null ? '' : ' [unavailable: ${c.disabledReason}]'}',
        );
      }
    }

    void review() {
      out.writeln('Selected: ${selected.length}.');
      for (var i = 0; i < choices.length; i++) {
        if (selected.contains(i)) {
          out.writeln(
            '${i + 1}. ${choices[i].label}${visible().contains(i) ? '' : ' [hidden]'}',
          );
        }
      }
    }

    void toggle(int i) {
      final c = choices[i];
      if (c.disabledReason != null) {
        out.writeln('Unavailable: ${c.disabledReason}.');
        return;
      }
      if (selected.contains(i)) {
        selected.remove(i);
      } else if (max != null && selected.length >= max!) {
        out.writeln('Maximum $max selections.');
        return;
      } else {
        selected.add(i);
      }
      out.writeln(
        '${c.label}: ${selected.contains(i) ? 'checked' : 'unchecked'}.',
      );
    }

    void bulk(bool add) {
      final enabled = visible()
          .where((i) => choices[i].disabledReason == null)
          .toSet();
      if (add && max != null && selected.union(enabled).length > max!) {
        out.writeln('Maximum $max selections; no changes made.');
        return;
      }
      if (add) {
        selected.addAll(enabled);
      } else {
        selected.removeAll(enabled);
      }
    }

    PromptResult<List<T>>? submit() {
      if (selected.length < min) {
        out.writeln('Minimum $min selections required.');
        return null;
      }
      return Accepted([
        for (var i = 0; i < choices.length; i++)
          if (selected.contains(i)) choices[i].value,
      ]);
    }

    show();
    out.writeln(
      mode == PromptMode.linear
          ? 'Enter a choice number to toggle. /done, /selected, /filter, /select-visible, /clear-visible, /next, /previous, /help and /cancel are exact commands. Quote commands with a backslash; double a leading backslash. Identified paste is literal; unframed paste cannot be distinguished from typing.'
          : 'Up/Down navigate; Space toggles; Enter submits; / filters; Ctrl+A select visible; Ctrl+X clear visible; Ctrl+R review; Ctrl+T help; Escape cancels; Ctrl+C interrupts.',
    );
    try {
      if (mode == PromptMode.linear) {
        while (true) {
          final r = await _edit(
            keys,
            '',
            out,
            linear: true,
            sequential: true,
            extraCommands: const {
              '/done',
              '/selected',
              '/filter',
              '/select-visible',
              '/clear-visible',
              '/next',
              '/previous',
            },
          );
          if (r.action == 'cancel') return Cancelled();
          if (r.action == 'interrupt') return Interrupted();
          if (r.action == 'eof') return InputEnded();
          if (r.action == 'command') {
            switch (r.value) {
              case '/done':
                final result = submit();
                if (result != null) return result;
              case '/selected':
                review();
              case '/select-visible':
                bulk(true);
                show();
              case '/clear-visible':
                bulk(false);
                show();
              case '/next':
                if ((page + 1) * size < visible().length) page++;
                show();
              case '/previous':
                if (page > 0) page--;
                show();
              case '/filter':
                out.writeln('Enter filter text (empty clears):');
                final f = await _edit(
                  keys,
                  '',
                  out,
                  linear: true,
                  sequential: true,
                );
                if (f.action == 'cancel') return Cancelled();
                if (f.action == 'interrupt') return Interrupted();
                if (f.action != 'submit') return InputEnded();
                filter = f.value;
                page = 0;
                focus = 0;
                show();
            }
          } else {
            final n = int.tryParse(r.value);
            if (n == null ||
                n < 1 ||
                n > choices.length ||
                !visible().contains(n - 1)) {
              out.writeln('Enter a visible choice reference.');
            } else {
              toggle(n - 1);
            }
          }
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
            'Help: Space toggles; Enter submits; / filters; Ctrl+A selects visible; Ctrl+X clears visible; Ctrl+R reviews; Escape dismisses help.',
          );
          continue;
        }
        if (help) continue;
        final items = visible();
        if (key == '\x1b[A' && focus > 0) {
          focus--;
          show();
        }
        if (key == '\x1b[B' && focus < items.length - 1) {
          focus++;
          show();
        }
        if (key == ' ' && items.isNotEmpty) {
          toggle(items[focus]);
          show();
        }
        if (key == '\x01') {
          bulk(true);
          show();
        }
        if (key == '\x18') {
          bulk(false);
          show();
        }
        if (key == '\x12') review();
        if (key == '/') {
          out.writeln('Enter filter text (empty clears):');
          final f = await _edit(keys, '', out);
          if (f.action == 'interrupt') return Interrupted();
          if (f.action == 'eof') return InputEnded();
          if (f.action == 'submit') {
            filter = f.value;
            focus = 0;
            show();
          }
        }
        if (key == '\r' || key == '\n') {
          final result = submit();
          if (result != null) return result;
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

/// Exact decimal slider input. Decimal values are represented as strings.
final class Slider {
  Slider(
    this.label, {
    required this.minimum,
    required this.maximum,
    required this.step,
    this.initialValue,
    this.precision,
    this.units,
  }) {
    if (label.trim().isEmpty ||
        label.runes.any((c) => c < 32 || c == 127) ||
        (units != null && units!.runes.any((c) => c < 32 || c == 127))) {
      throw ArgumentError('Invalid label or units.');
    }
    final min = _decimal(minimum);
    final max = _decimal(maximum);
    final increment = _decimal(step);
    if (min == null ||
        max == null ||
        increment == null ||
        _compare(min, max) > 0 ||
        increment.$1 <= BigInt.zero ||
        (precision != null &&
            (precision! < 0 ||
                min.$2 > precision! ||
                max.$2 > precision! ||
                increment.$2 > precision!))) {
      throw ArgumentError('Invalid slider bounds or step.');
    }
    if (initialValue != null && _validate(initialValue!) != null) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }

  final String label;
  final String minimum;
  final String maximum;
  final String step;
  final String? initialValue;
  final int? precision;
  final String? units;
  String get _description =>
      '$label (minimum $minimum, maximum $maximum, step $step${units == null ? '' : ', units $units'}${precision == null ? '' : ', maximum $precision decimal places'})';

  String? _validate(String value) {
    final number = _decimal(value);
    final min = _decimal(minimum)!;
    final max = _decimal(maximum)!;
    final increment = _decimal(step)!;
    if (number == null ||
        (precision != null && number.$2 > precision!) ||
        _compare(number, min) < 0 ||
        _compare(number, max) > 0) {
      return 'Enter a value between $minimum and $maximum on the $step grid.';
    }
    final scale = [
      number.$2,
      min.$2,
      increment.$2,
    ].reduce((a, b) => a > b ? a : b);
    final n = number.$1 * BigInt.from(10).pow(scale - number.$2);
    final m = min.$1 * BigInt.from(10).pow(scale - min.$2);
    final s = increment.$1 * BigInt.from(10).pow(scale - increment.$2);
    return (n - m) % s == BigInt.zero
        ? null
        : 'Enter a value between $minimum and $maximum on the $step grid.';
  }

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
    if (source is SuppliedAnswer ||
        (source is ScriptedInput &&
            (mode == PromptMode.linear ||
                (mode == PromptMode.automatic && !source.supportsRich)))) {
      try {
        return await TextInput(
          _description,
          required: true,
          initialValue: initialValue ?? '',
          validate: _validate,
        ).prompt(source: source, mode: PromptMode.linear);
      } finally {
        beforeClose?.call();
      }
    }
    final scripted = source as ScriptedInput;
    if (!scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    final out = scripted.output;
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    var value = initialValue ?? '';
    var focus = 0;
    var help = false;
    void show() {
      out.writeln(
        '$_description. Value: ${value.isEmpty ? 'not set' : value}.',
      );
      out.writeln(
        'Focus: ${['Slider', 'Edit', 'Submit'][focus]}. Tab moves; arrows adjust Slider; Enter activates Edit or Submit; Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
      );
    }

    show();
    try {
      while (true) {
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          out.writeln('Help dismissed.');
          show();
          continue;
        }
        if (key == '\x14') {
          help = true;
          out.writeln(
            'Help: Tab moves through controls; arrows adjust a focused value; Enter activates Edit or Submit. Escape dismisses help; Ctrl+C interrupts.',
          );
          continue;
        }
        if (help) continue;
        if (key == '\t') {
          focus = (focus + 1) % 3;
          show();
          continue;
        }
        if (focus == 0 &&
            (key == '\x1b[C' ||
                key == '\x1b[A' ||
                key == '\x1b[D' ||
                key == '\x1b[B')) {
          if (_validate(value) == null) {
            final candidate = _addDecimal(
              value,
              step,
              key == '\x1b[C' || key == '\x1b[A' ? 1 : -1,
            );
            if (_validate(candidate) == null) value = candidate;
          } else {
            out.writeln('Edit a valid value before adjusting.');
          }
          show();
          continue;
        }
        if ((key == '\r' || key == '\n') && focus == 1) {
          out.writeln('Edit value; Enter finishes editing.');
          final edit = await _edit(keys, value, out);
          if (edit.action == 'interrupt') return Interrupted();
          if (edit.action == 'cancel') {
            out.writeln('Edit dismissed.');
            show();
            continue;
          }
          if (edit.action != 'submit') return InputEnded();
          value = edit.value;
          final error = _validate(value);
          if (error != null) out.writeln(error);
          show();
          continue;
        }
        if ((key == '\r' || key == '\n') && focus == 2) {
          final error = _validate(value);
          if (error == null) return Accepted(value);
          out.writeln(error);
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

(BigInt, int)? _decimal(String text) {
  if (!RegExp(r'^-?[0-9]+(?:\.[0-9]+)?$').hasMatch(text)) return null;
  final parts = text.split('.');
  return (BigInt.parse(parts.join()), parts.length == 2 ? parts[1].length : 0);
}

int _compare((BigInt, int) a, (BigInt, int) b) {
  final scale = a.$2 > b.$2 ? a.$2 : b.$2;
  return (a.$1 * BigInt.from(10).pow(scale - a.$2)).compareTo(
    b.$1 * BigInt.from(10).pow(scale - b.$2),
  );
}

String _addDecimal(String value, String step, int direction) {
  final a = _decimal(value)!;
  final b = _decimal(step)!;
  final scale = a.$2 > b.$2 ? a.$2 : b.$2;
  final number =
      a.$1 * BigInt.from(10).pow(scale - a.$2) +
      b.$1 * BigInt.from(10).pow(scale - b.$2) * BigInt.from(direction);
  final negative = number.isNegative;
  var digits = number.abs().toString().padLeft(scale + 1, '0');
  if (scale > 0) {
    digits =
        '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
  }
  return '${negative ? '-' : ''}$digits';
}

/// An exact pair of slider endpoints.
final class RangeSlider {
  RangeSlider(
    String label, {
    required String minimum,
    required String maximum,
    required String step,
    this.minimumGap = '0',
    this.initialLower,
    this.initialUpper,
    int? precision,
    String? units,
  }) : _slider = Slider(
         label,
         minimum: minimum,
         maximum: maximum,
         step: step,
         precision: precision,
         units: units,
       ) {
    final gap = _decimal(minimumGap);
    if (gap == null ||
        gap.$1.isNegative ||
        (precision != null && gap.$2 > precision)) {
      throw ArgumentError.value(minimumGap, 'minimumGap');
    }
    if ((initialLower == null) != (initialUpper == null) ||
        (initialLower != null &&
            _pairError(initialLower!, initialUpper!) != null)) {
      throw ArgumentError('Invalid initial range.');
    }
  }

  final String minimumGap;
  final String? initialLower;
  final String? initialUpper;

  String? _pairError(String lower, String upper) {
    final l = _slider._validate(lower);
    if (l != null) return 'Lower: $l';
    final u = _slider._validate(upper);
    if (u != null) return 'Upper: $u';
    if (_compare(
          _decimal(_addDecimal(lower, minimumGap, 1))!,
          _decimal(upper)!,
        ) >
        0) {
      return 'Lower and Upper must remain ordered with minimum gap $minimumGap.';
    }
    return null;
  }

  final Slider _slider;
  bool _active = false;

  Future<PromptResult<(String, String)>> prompt({
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
          return await _terminal<(String, String)>(
            selected,
            output ?? stderr,
            (source, mode, restore) => _run(source, mode, restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, null);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<(String, String)>> _run(
    PromptSource source,
    PromptMode mode,
    void Function()? beforeClose,
  ) async {
    if (source is SuppliedAnswer) {
      final parts = source.value.split(',');
      if (parts.length != 2) {
        return Unavailable(
          'Supply Lower,Upper as two decimal values separated by a comma.',
        );
      }
      final error = _pairError(parts[0], parts[1]);
      return error == null
          ? Accepted((parts[0], parts[1]))
          : Unavailable(error);
    }
    final scripted = source as ScriptedInput;
    if (mode == PromptMode.rich && !scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.rich ||
        (mode == PromptMode.automatic && scripted.supportsRich)) {
      return _rich(scripted, beforeClose);
    }
    final out = scripted.output;
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    var lower = initialLower ?? '';
    var upper = initialUpper ?? '';
    try {
      out.writeln('${_slider._description}, minimum gap $minimumGap.');
      while (true) {
        out.writeln('Lower endpoint:');
        final l = await _edit(keys, lower, out, linear: true, sequential: true);
        if (l.action == 'cancel') return Cancelled();
        if (l.action == 'interrupt') return Interrupted();
        if (l.action != 'submit') return InputEnded();
        lower = l.value;
        final lowerError = _slider._validate(lower);
        if (lowerError != null) {
          out.writeln(lowerError);
          continue;
        }
        while (true) {
          out.writeln('Upper endpoint:');
          final u = await _edit(
            keys,
            upper,
            out,
            linear: true,
            sequential: true,
          );
          if (u.action == 'cancel') return Cancelled();
          if (u.action == 'interrupt') return Interrupted();
          if (u.action != 'submit') return InputEnded();
          upper = u.value;
          final upperError = _slider._validate(upper);
          if (upperError != null) {
            out.writeln(upperError);
            continue;
          }
          final pairError = _pairError(lower, upper);
          if (pairError != null) {
            out.writeln(pairError);
            break;
          }
          out.writeln(
            'Review Lower $lower, Upper $upper. Submit: press Enter.',
          );
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
          if (confirm.value.isEmpty) return Accepted((lower, upper));
          out.writeln('Enter an empty line to submit, or edit the pair.');
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

  Future<PromptResult<(String, String)>> _rich(
    ScriptedInput source,
    void Function()? beforeClose,
  ) async {
    final out = source.output;
    final keys = _Keys(source.input.transform(utf8.encoder));
    var lower = initialLower ?? '';
    var upper = initialUpper ?? '';
    var focus = 0;
    var help = false;
    const names = ['Lower', 'Upper', 'Edit Lower', 'Edit Upper', 'Submit'];
    void show() {
      out.writeln(
        '${_slider._description}, minimum gap $minimumGap. Lower: ${lower.isEmpty ? 'not set' : lower}; Upper: ${upper.isEmpty ? 'not set' : upper}.',
      );
      out.writeln(
        'Focus: ${names[focus]}. Tab moves; arrows adjust endpoints; Enter activates Edit or Submit; Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.',
      );
    }

    try {
      show();
      while (true) {
        final key = await keys.next();
        if (key == null || key == '\x1a') return InputEnded();
        if (key == '\x03') return Interrupted();
        if (key == '\x1b') {
          if (!help) return Cancelled();
          help = false;
          out.writeln('Help dismissed.');
          show();
          continue;
        }
        if (key == '\x14') {
          help = true;
          out.writeln(
            'Help: Tab moves through controls; arrows adjust a focused value; Enter activates Edit or Submit. Escape dismisses help; Ctrl+C interrupts.',
          );
          continue;
        }
        if (help) continue;
        if (key == '\t') {
          focus = (focus + 1) % names.length;
          show();
          continue;
        }
        if (focus < 2 &&
            (key == '\x1b[A' ||
                key == '\x1b[B' ||
                key == '\x1b[C' ||
                key == '\x1b[D')) {
          if (_pairError(lower, upper) == null) {
            final current = focus == 0 ? lower : upper;
            final next = _addDecimal(
              current,
              _slider.step,
              key == '\x1b[A' || key == '\x1b[C' ? 1 : -1,
            );
            if (_pairError(
                  focus == 0 ? next : lower,
                  focus == 1 ? next : upper,
                ) ==
                null) {
              if (focus == 0) {
                lower = next;
              } else {
                upper = next;
              }
            }
          } else {
            out.writeln(
              'Edit both endpoints to valid values before adjustment.',
            );
          }
          show();
          continue;
        }
        if ((key == '\r' || key == '\n') && (focus == 2 || focus == 3)) {
          out.writeln('${names[focus]}: Enter finishes editing.');
          final edit = await _edit(keys, focus == 2 ? lower : upper, out);
          if (edit.action == 'cancel') {
            out.writeln('Edit dismissed.');
            show();
            continue;
          }
          if (edit.action == 'interrupt') return Interrupted();
          if (edit.action != 'submit') return InputEnded();
          if (focus == 2) {
            lower = edit.value;
          } else {
            upper = edit.value;
          }
          final error = _pairError(lower, upper);
          if (error != null) out.writeln(error);
          show();
          continue;
        }
        if ((key == '\r' || key == '\n') && focus == 4) {
          final error = _pairError(lower, upper);
          if (error == null) return Accepted((lower, upper));
          out.writeln(error);
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

/// A node in a TreeSelect hierarchy. Branches are not selectable by default.
final class TreeNode<T> {
  TreeNode(
    this.value,
    this.label, {
    List<TreeNode<T>> children = const [],
    this.selectable,
    this.disabledReason,
    this.childrenUnavailableReason,
  }) : children = List.unmodifiable(children) {
    Choice(value, label, disabledReason: disabledReason);
    if (childrenUnavailableReason != null) {
      Choice(value, label, disabledReason: childrenUnavailableReason);
      if (children.isNotEmpty) {
        throw ArgumentError('Unavailable children cannot be supplied.');
      }
    }
  }
  final T value;
  final String label;
  final List<TreeNode<T>> children;
  final bool? selectable;
  final String? disabledReason;

  /// Explains why this branch's children are not currently available.
  final String? childrenUnavailableReason;
  bool get canSelect =>
      selectable ?? (children.isEmpty && childrenUnavailableReason == null);
}

/// Selects one node independently of expanding or traversing branches.
final class TreeSelect<T> {
  TreeSelect(
    this.label,
    List<TreeNode<T>> nodes, {
    this.isCurrent,
    this.defaultValue,
  }) : nodes = List.unmodifiable(nodes) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    final identities = <T>{};
    void validate(List<TreeNode<T>> nodes) {
      for (final node in nodes) {
        if (!identities.add(node.value)) {
          throw ArgumentError('Node identities must be unique.');
        }
        validate(node.children);
      }
    }

    validate(this.nodes);
    if (defaultValue != null && !identities.contains(defaultValue)) {
      throw ArgumentError('Default identity is not a node.');
    }
  }
  final String label;
  final List<TreeNode<T>> nodes;
  final T? defaultValue;

  /// Optional currentness check for nodes that can disappear during a prompt.
  final bool Function(T value)? isCurrent;
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
      if (source != null) return await _run(source, selected);
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
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<T>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    final all = <(TreeNode<T>, List<TreeNode<T>>)>[];
    void collect(List<TreeNode<T>> level, List<TreeNode<T>> path) {
      for (final node in level) {
        final current = [...path, node];
        all.add((node, current));
        collect(node.children, current);
      }
    }

    collect(nodes, []);
    bool currentPath(List<TreeNode<T>> path) =>
        isCurrent == null || path.every((node) => isCurrent!(node.value));
    if (source is SuppliedAnswer) {
      final n = int.tryParse(source.value);
      if (n == null ||
          n < 1 ||
          n > all.length ||
          !all[n - 1].$1.canSelect ||
          all[n - 1].$1.disabledReason != null ||
          !currentPath(all[n - 1].$2)) {
        return Unavailable('Supply an enabled selectable node reference.');
      }
      return Accepted(all[n - 1].$1.value);
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
    final expanded = <T>{};
    final enabledRoot = nodes.indexWhere((node) => node.disabledReason == null);
    var focus = nodes.isEmpty ? null : nodes[enabledRoot < 0 ? 0 : enabledRoot];
    if (defaultValue != null) {
      final row = all.firstWhere((r) => r.$1.value == defaultValue);
      focus = row.$1;
      expanded.addAll(row.$2.take(row.$2.length - 1).map((node) => node.value));
    }
    var current = <TreeNode<T>>[];
    List<(TreeNode<T>, List<TreeNode<T>>)> visible() => all
        .where(
          (row) => row.$2
              .take(row.$2.length - 1)
              .every((n) => expanded.contains(n.value)),
        )
        .toList();
    String path(List<TreeNode<T>> nodes) =>
        nodes.map((n) => n.label).join(' / ');
    void show() {
      out.writeln('$label TreeSelect:');
      if (all.isEmpty) out.writeln('No nodes available.');
      if (mode == PromptMode.linear) {
        out.writeln('Path: ${current.isEmpty ? 'root' : path(current)}');
        if (defaultValue != null) {
          final row = all.firstWhere((r) => r.$1.value == defaultValue);
          out.writeln(
            'Default: ${path(row.$2)} (reference ${all.indexOf(row) + 1})${row.$1.canSelect ? '' : ' [not selectable]'}${row.$1.disabledReason == null ? '' : ' [unavailable: ${row.$1.disabledReason}]'}${currentPath(row.$2) ? '' : ' [unavailable: no longer available]'}',
          );
        }
      }
      final rows = mode == PromptMode.linear
          ? all.where(
              (r) =>
                  (current.isNotEmpty && identical(r.$1, current.last)) ||
                  (r.$2.length == current.length + 1 &&
                      (current.isEmpty ||
                          identical(r.$2[current.length - 1], current.last))),
            )
          : visible();
      for (final row in rows) {
        final node = row.$1;
        out.writeln(
          '${all.indexOf(row) + 1}. ${path(row.$2)}${mode == PromptMode.rich && identical(node, focus) ? ' [focused]' : ''}${defaultValue != null && node.value == defaultValue ? ' [default]' : ''} ${node.childrenUnavailableReason != null
              ? '[children unavailable: ${node.childrenUnavailableReason}]'
              : node.children.isEmpty
              ? '[leaf]'
              : expanded.contains(node.value)
              ? '[expanded]'
              : '[collapsed]'} ${node.canSelect ? '[selectable]' : '[not selectable]'}${node.disabledReason == null ? '' : ' [unavailable: ${node.disabledReason}]'}${currentPath(row.$2) ? '' : ' [unavailable: no longer available]'}',
        );
      }
    }

    out.writeln(
      mode == PromptMode.linear
          ? r'/open, /up and /choose are exact commands. /open and /choose ask for a stable node reference. /help and /cancel are exact commands; quote commands with a backslash; double a leading backslash. Identified paste is literal.'
          : 'Up/Down navigate; Right expands or enters; Left collapses or goes to parent; Enter chooses. Ctrl+T help; Escape cancels; Ctrl+C interrupts.',
    );
    show();
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    try {
      if (mode == PromptMode.linear) {
        while (true) {
          final action = await _edit(
            keys,
            '',
            out,
            linear: true,
            sequential: true,
            extraCommands: const {'/open', '/up', '/choose'},
          );
          if (action.action == 'cancel') return Cancelled();
          if (action.action == 'interrupt') return Interrupted();
          if (action.action != 'command' && action.action != 'submit') {
            return InputEnded();
          }
          if (action.action != 'command') {
            out.writeln('Use /open, /up or /choose.');
            continue;
          }
          if (action.value == '/up') {
            if (current.isNotEmpty) {
              current = current.sublist(0, current.length - 1);
            } else {
              out.writeln('Already at root.');
            }
            show();
            continue;
          }
          out.writeln('Enter node reference:');
          final reference = await _edit(
            keys,
            '',
            out,
            linear: true,
            sequential: true,
            extraCommands: const {'/open', '/up', '/choose'},
          );
          if (reference.action == 'cancel') return Cancelled();
          if (reference.action == 'interrupt') return Interrupted();
          if (reference.action == 'command') {
            out.writeln('Enter a node reference.');
            continue;
          }
          if (reference.action != 'submit') return InputEnded();
          final n = int.tryParse(reference.value);
          if (n == null || n < 1 || n > all.length) {
            out.writeln('Enter a valid node reference.');
            continue;
          }
          final row = all[n - 1];
          final node = row.$1;
          if (!currentPath(row.$2)) {
            out.writeln('Node is no longer available.');
            continue;
          }
          if (action.value == '/open') {
            if (row.$2.length != current.length + 1 ||
                (current.isNotEmpty &&
                    !identical(row.$2[current.length - 1], current.last))) {
              out.writeln('Open a node in the current path.');
              continue;
            }
            if (node.childrenUnavailableReason != null) {
              out.writeln(
                'Children unavailable: ${node.childrenUnavailableReason}.',
              );
              continue;
            }
            if (node.children.isEmpty) {
              out.writeln('Node has no children.');
              continue;
            }
            expanded.add(node.value);
            current = row.$2;
            show();
            continue;
          }
          if (!node.canSelect) {
            out.writeln('Node is not selectable.');
            continue;
          }
          if (node.disabledReason != null) {
            out.writeln('Unavailable: ${node.disabledReason}.');
            continue;
          }
          out.writeln('Accepted: ${path(row.$2)}.');
          return Accepted(node.value);
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
            'Help: Up/Down navigate; Right expands or enters; Left collapses or goes to parent; Enter chooses; Escape dismisses help.',
          );
          continue;
        }
        if (help) continue;
        final rows = visible();
        final index = rows.indexWhere((r) => identical(r.$1, focus));
        if (key == '\x1b[A' && index > 0) focus = rows[index - 1].$1;
        if (key == '\x1b[B' && index >= 0 && index + 1 < rows.length) {
          focus = rows[index + 1].$1;
        }
        if (key == '\x1b[C' && index >= 0 && !currentPath(rows[index].$2)) {
          out.writeln('Node is no longer available.');
          continue;
        }
        if (key == '\x1b[C' && focus?.childrenUnavailableReason != null) {
          out.writeln(
            'Children unavailable: ${focus!.childrenUnavailableReason}.',
          );
        }
        if (key == '\x1b[C' && focus != null && focus.children.isNotEmpty) {
          if (!expanded.add(focus.value)) focus = focus.children.first;
        }
        if (key == '\x1b[D' && focus != null) {
          if (!expanded.remove(focus.value) &&
              index >= 0 &&
              rows[index].$2.length > 1) {
            focus = rows[index].$2[rows[index].$2.length - 2];
          }
        }
        if (key == '\r' || key == '\n') {
          if (focus == null) {
            out.writeln('No node available.');
            continue;
          }
          if (index < 0 || !currentPath(rows[index].$2)) {
            out.writeln('Node is no longer available.');
            continue;
          }
          if (!focus.canSelect) {
            out.writeln('Node is not selectable.');
            continue;
          }
          if (focus.disabledReason != null) {
            out.writeln('Unavailable: ${focus.disabledReason}.');
            continue;
          }
          out.writeln(
            'Accepted: ${path(all.firstWhere((r) => identical(r.$1, focus)).$2)}.',
          );
          return Accepted(focus.value);
        }
        show();
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

/// A time of day without a date or timezone.
final class TimeInput {
  TimeInput(this.label);
  final String label;

  Future<PromptResult<({int hour, int minute, int? second})>> prompt({
    PromptSource? source,
    PromptMode? mode,
  }) async {
    final result = await TextInput(label, required: true, validate: (value) {
      final match = RegExp(r'^([0-9]{2}):([0-9]{2})$').firstMatch(value);
      if (match == null || int.parse(match[1]!) > 23 || int.parse(match[2]!) > 59) {
        return 'Enter HH:mm (00:00 to 23:59).';
      }
      return null;
    }).prompt(source: source, mode: mode);
    if (result is Accepted<String>) {
      final parts = result.value.split(':');
      return Accepted((hour: int.parse(parts[0]), minute: int.parse(parts[1]), second: null));
    }
    if (result is Cancelled<String>) return Cancelled();
    if (result is Interrupted<String>) return Interrupted();
    if (result is InputEnded<String>) return InputEnded();
    return Unavailable((result as Unavailable<String>).reason);
  }
}

