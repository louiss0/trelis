import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:characters/characters.dart';

Future<void> main(List<String> args) async {
  final linear = args.contains('--linear');
  final testStream = args.contains('--test-stream');
  if (!testStream &&
      (!Platform.isWindows || !stdin.hasTerminal || !stderr.hasTerminal)) {
    stderr.writeln(
      'interaction unavailable: Windows console stdin and stderr required',
    );
    exitCode = 2;
    return;
  }
  var initial = 'alpha';
  for (final arg in args) {
    if (arg.startsWith('--default=')) initial = arg.substring(10);
  }
  final api = Platform.isWindows && !testStream ? Console() : null;
  final mode = calloc<Uint32>();
  final outputMode = calloc<Uint32>();
  final input = api?.getHandle(-10) ?? 0;
  final output = api?.getHandle(-12) ?? 0;

  try {
    if (api != null &&
        (api.getMode(input, mode) == 0 ||
            api.setMode(input, (mode.value | 0x200) & ~7) == 0)) {
      stderr.writeln('interaction unavailable: cannot acquire console');
      exitCode = 2;
      return;
    }
    if (api != null &&
        (api.getMode(output, outputMode) == 0 ||
            api.setMode(output, outputMode.value | 4) == 0)) {
      api.setMode(input, mode.value);
      stderr.writeln('interaction unavailable: cannot enable VT output');
      exitCode = 2;
      return;
    }
    stderr.write('\x1b[?2004h');
    final keys = Keys(stdin);
    late final String outcome;
    try {
      outcome = await runProbe(keys, linear, initial);
    } finally {
      stderr.write('\x1b[?2004l\n');
      if (api != null) {
        final restoredInput = api.setMode(input, mode.value);
        final restoredOutput = api.setMode(output, outputMode.value);
        if (restoredInput == 0 || restoredOutput == 0) {
          throw StateError('failed to restore console mode');
        }
      }
      await keys.close();
    }
    stdout.writeln(outcome);
  } finally {
    calloc.free(mode);
    calloc.free(outputMode);
  }
}

Future<String> runProbe(Keys keys, bool linear, String initial) async {
  stderr.writeln(
    'Editable probe (${linear ? 'linear' : 'plain-rich'}). Required text; edit the actual initial value. Left/Right, Home/End, Backspace/Delete; Enter submits. F1 opens help; Escape dismisses help or cancels; Ctrl+C interrupts.',
  );
  if (linear) {
    stderr.writeln(
      r'Exact /help and /cancel are commands. Quote commands with \; double an initial \ to enter one. Identified paste is literal.',
    );
  }
  var value = initial;
  while (true) {
    final result = await edit(keys, value, linear: linear, sequential: linear);
    if (result.action != 'submit') return result.action;
    if (result.value.isEmpty) {
      stderr.writeln('Required: enter a non-empty value and submit again.');
      value = result.value;
      continue;
    }
    value = result.value;
    stderr.writeln('Validation 1/2: text accepted.');
    break;
  }
  stderr.writeln(
    'Text accepted. Hidden secret entry: no echo. Enter opens actions; F1 opens help; Escape dismisses help or cancels; Ctrl+C interrupts.',
  );
  var secret = '';
  while (true) {
    final entry = await edit(keys, secret, secret: true);
    if (entry.action != 'submit') return entry.action;
    secret = entry.value;
    stderr.writeln('Secret actions: submit, edit, clear, help, cancel.');
    while (true) {
      final action = await edit(keys, '', sequential: linear);
      if (action.action != 'submit') return action.action;
      switch (action.value) {
        case 'submit':
          if (secret.isEmpty) {
            stderr.writeln('Secret required; choose edit or clear.');
            continue;
          }
          stderr.writeln('Validation 2/2: secret accepted.');
          stderr.writeln('Validation complete.');
          return 'text:$value;secret:accepted';
        case 'edit':
          break;
        case 'clear':
          secret = '';
          break;
        case 'cancel':
          return 'cancel';
        default:
          stderr.writeln('Choose submit, edit, clear, help, or cancel.');
          continue;
      }
      break;
    }
  }
}

Future<({String action, String value})> edit(
  Keys keys,
  String initial, {
  bool linear = false,
  bool sequential = false,
  bool secret = false,
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
      stderr.writeln('Current text: ${chars.join()}');
      stderr.writeln('Cursor position: $pos of ${chars.length} graphemes.');
      return;
    }
    stderr.write(
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
      stderr.writeln('Help dismissed.');
      display();
      continue;
    }
    if (key == '\x1bOP' || key == '\x1b[11~') {
      help = true;
      stderr.writeln(
        'Help: arrows move, Backspace/Delete erase, Enter submits. Escape dismisses help; Ctrl+C interrupts.',
      );
      continue;
    }
    if (help) continue;
    if (key == '\r' || key == '\n') {
      stderr.writeln();
      var text = chars.join();
      if (synthetic >= 0) {
        final answer = chars.toList();
        answer[synthetic] = answer[synthetic].substring(1);
        text = answer.join();
      } else if (linear && !provenance.contains(true)) {
        if (text == '/help') {
          stderr.writeln(
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
      stderr.writeln('Paste rejected: exceeds 4096 UTF-16 code units.');
    } else if (key.startsWith('\x1b[200~')) {
      final data = key.substring(6, key.length - 6);
      if (data.runes.any((r) => r < 32 || r == 127)) {
        stderr.writeln('Paste rejected: single-line printable text only.');
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

class Keys {
  final _controller = StreamController<String>();
  late final StreamSubscription<String> _subscription;
  late final StreamIterator<String> _iterator;
  String _buffer = '';
  bool _discardPaste = false;
  Timer? _timer;
  Keys(Stream<List<int>> source) {
    _iterator = StreamIterator(_controller.stream);
    _subscription = source
        .transform(utf8.decoder)
        .listen(
          (data) {
            _buffer += data;
            _parse();
          },
          onDone: () {
            if (!_discardPaste &&
                !_buffer.startsWith('\x1b[200~') &&
                _buffer.isNotEmpty) {
              _controller.add(_buffer);
            }
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
        final match = RegExp(
          r'^\x1b(?:\[[0-9;]*[A-Za-z~]|O[A-Za-z])',
        ).firstMatch(_buffer);
        if (match != null) {
          final s = match.group(0)!;
          _controller.add(
            s.startsWith('\x1bO') && 'ABCDHF'.contains(s[2])
                ? '\x1b[${s[2]}'
                : s,
          );
          _buffer = _buffer.substring(s.length);
          continue;
        }
        if (_buffer == '\x1b' ||
            _buffer == '\x1bO' ||
            _buffer.startsWith('\x1b[')) {
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

  Future<String?> next() async =>
      await _iterator.moveNext() ? _iterator.current : null;
  Future<void> close() async {
    _timer?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_iterator.cancel());
  }
}

class Console {
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
  late final int Function(int, int) setMode = _dll
      .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'SetConsoleMode',
      );
}
