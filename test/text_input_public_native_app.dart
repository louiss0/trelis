import 'dart:async';
import 'dart:io';

import 'package:trelis/trelis.dart';

/// Public-theme native fixture routes.
///
/// This library deliberately imports only the public barrel. Every route
/// constructs exported theme instances over [TerminalEnvironment.nativeThemeDefault]
/// and invokes parameterless prompt or feedback methods; native input, console
/// acquisition and restoration stay behind that public seam.
Future<void> runPublicTextInputScenario(
  String scenario, {
  String? triggerPath,
}) async {
  final mode = switch (scenario) {
    'rich' || 'dumb-rich' || 'resize' => PromptMode.rich,
    'dumb-auto' => PromptMode.automatic,
    _ when scenario.startsWith('help-') && scenario.endsWith('-rich') =>
      PromptMode.rich,
    _ => PromptMode.linear,
  };
  final initialValue = switch (scenario) {
    'paste' || 'unicode' => '',
    'linear-long' => '0123456789' * 30,
    // Long enough to be windowed at a narrow width and fully visible at a
    // wide one, so an idle resize is visible as a changed draft row.
    'resize' => '0123456789' * 6,
    _ => 'alpha',
  };

  PlainTheme theme({Stdout? output}) => PlainTheme(
    io: TerminalEnvironment.nativeThemeDefault(output: output ?? stderr),
    interaction: InteractionPreferences(mode: mode),
  );

  ThemePrompt<String> namePrompt(PlainTheme owner) =>
      owner.textInput('Name', initialValue: initialValue);

  String describe(PromptResult<String> result) => switch (result) {
    Accepted<String>(:final value) => value,
    Cancelled<String>() => 'cancel',
    Interrupted<String>() => 'interrupt',
    InputEnded<String>() => 'eof',
    Unavailable<String>(:final reason) => 'unavailable:$reason',
  };

  if (scenario.startsWith('help-')) {
    final result = scenario.contains('password')
        ? await theme().password('Synthetic password').prompt()
        : await namePrompt(theme()).prompt();
    print(
      scenario.contains('password')
          ? (result is Accepted<String> && result.value == 'TrelisCanary7Q9'
                ? 'accepted'
                : 'wrong')
          : describe(result),
    );
    return;
  }

  if (scenario == 'error') {
    final owner = theme();
    final failing = owner.textInput(
      'Failure',
      validate: (_) => throw StateError('validation'),
    );
    try {
      await failing.prompt();
    } on StateError {
      // A subsequent prompt on the same reusable theme must still be usable
      // after validation throws.
    }
    final result = await namePrompt(owner).prompt();
    print(result is Accepted<String> ? result.value : 'failed');
    return;
  }

  if (scenario == 'repeat') {
    final owner = theme();
    final reusable = namePrompt(owner);
    final first = describe(await reusable.prompt());
    final second = describe(await reusable.prompt());
    // Reacquisition through a second exported theme over the same selected
    // output must still prompt after the first theme has retired its period.
    final third = describe(await namePrompt(theme()).prompt());
    print(third == initialValue ? '$first,$second' : 'third:$third');
    return;
  }

  if (scenario == 'session-retire') {
    // Theme-owned live feedback and a prompt intentionally share one native
    // session. The selected writer fails while the prompt is parked on the
    // native read; feedback is the failing participant, so this also proves
    // feedback/prompt coexistence rather than a writer failure in isolation.
    final output = _FailingStdout();
    final failure = StateError('synthetic shared writer failure');
    final owner = theme(output: output);
    var outcome = 'scope-returned';
    final spinner = await owner.spinner('Index').start();
    final pending = namePrompt(owner).prompt();

    // Wait until the prompt has painted and is parked on the console.
    if (!await _paintedWithin(output, 'Name', const Duration(seconds: 5))) {
      final result = await pending.timeout(
        const Duration(seconds: 1),
        onTimeout: () => Unavailable<String>('prompt did not start'),
      );
      outcome =
          'no-console:${result is Unavailable<String> ? result.reason : result.runtimeType}';
    } else {
      // The harness captures the acquired console state while the prompt is
      // parked, so it releases the failure through a trigger file.
      if (triggerPath != null &&
          !await _appearedWithin(File(triggerPath), _triggerLimit)) {
        outcome = 'no-trigger';
      } else {
        output.failure = failure;
        try {
          spinner.update('tick');
          outcome = 'writer-accepted-update';
        } catch (error) {
          if (!identical(error, failure)) outcome = 'other-writer-error';
        }
        try {
          final result = await pending.timeout(
            const Duration(seconds: 5),
            onTimeout: () => Unavailable<String>('parked'),
          );
          outcome = result is Unavailable<String>
              ? 'parked'
              : 'ended-without-failure';
        } catch (error) {
          if (identical(error, failure)) outcome = 'retired';
        }
      }
    }
    print(outcome);
    return;
  }

  final selectedOutput = scenario == 'stdout' ? stdout : stderr;
  final result = await namePrompt(theme(output: selectedOutput)).prompt();
  print(
    scenario == 'unicode'
        ? switch (result) {
            Accepted<String>(:final value) =>
              value.runes.map((rune) => rune.toRadixString(16)).join(','),
            _ => describe(result),
          }
        : describe(result),
  );
}

const _triggerLimit = Duration(seconds: 60);

Future<bool> _appearedWithin(File trigger, Duration limit) async {
  final deadline = DateTime.now().add(limit);
  while (!trigger.existsSync()) {
    if (DateTime.now().isAfter(deadline)) return false;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return true;
}

Future<bool> _paintedWithin(
  _FailingStdout output,
  String text,
  Duration limit,
) async {
  final deadline = DateTime.now().add(limit);
  while (!output.text.contains(text)) {
    if (DateTime.now().isAfter(deadline)) return false;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return true;
}

/// A selected output that can be armed to fail like a broken shared writer.
///
/// Only the members the native session path actually observes are real; the
/// rest of the standard output contract is unused here.
final class _FailingStdout implements Stdout {
  Object? failure;
  final StringBuffer _recording = StringBuffer();

  String get text => _recording.toString();

  @override
  bool get hasTerminal => false;

  @override
  bool get supportsAnsiEscapes => false;

  void _write(Object? value) {
    final armed = failure;
    if (armed != null) throw armed;
    _recording.write(value);
  }

  @override
  void write(Object? object) => _write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _write(objects.join(separator));

  @override
  void writeCharCode(int charCode) => _write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => _write('$object\n');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
