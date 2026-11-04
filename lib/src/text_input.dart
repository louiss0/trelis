import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:characters/characters.dart';

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
  int? maxLength,
}) async {
  var chars = initial.characters.toList();
  var pos = chars.length;
  var provenance = List<bool>.filled(chars.length, false, growable: true);
  var synthetic = -1;
  if (linear &&
      (initial == '/cancel' ||
          initial == '/help' ||
          initial.startsWith('\\'))) {
    chars.insert(0, '\\');
    provenance.insert(0, false);
    pos++;
    synthetic = 0;
  }
  void insert(String data, bool isPaste) {
    final candidate = chars.take(pos).join() + data + chars.skip(pos).join();
    final count = candidate.characters.length - (synthetic >= 0 ? 1 : 0);
    if (maxLength != null && count > maxLength) {
      output.writeln(
        'Insertion rejected: character limit is $maxLength graphemes.',
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
    if (secret) return;
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
  var help = false;
  while (true) {
    final key = await keys.next();
    if (key == null || key == '\x1a') return (action: 'eof', value: '');
    if (key == '\x03') return (action: 'interrupt', value: '');
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
          output.writeln(
            r'Edit text; /cancel cancels. Use \/cancel or \/help for literal commands; double a leading backslash.',
          );
          display();
          continue;
        }
        if (text == '/cancel') return (action: 'cancel', value: '');
        if (text == r'\/cancel' ||
            text == r'\/help' ||
            text.startsWith(r'\\')) {
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
      final data = key.substring(6, key.length - 6);
      if (data.runes.any((r) => r < 32 || r == 127)) {
        output.writeln('Paste rejected: single-line printable text only.');
        display();
        continue;
      }
      insert(data, true);
    } else if (!key.startsWith('\x1b') && key.codeUnitAt(0) >= 32) {
      insert(key, false);
    }
    display();
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
              0x27 => '\x1b[C',
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
