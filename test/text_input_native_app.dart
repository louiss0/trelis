import 'dart:async';
import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';

import 'support/text_input_native_fixture.dart';

import 'text_input_public_native_app.dart';

Future<void> main(List<String> args) async {
  try {
    final scenario = args.isEmpty ? 'repeat' : args.first;
    // Optional harness release file: a native scenario that injects its own
    // failure waits for it so the harness can observe the acquired state first.
    final trigger = args.length > 1 ? args[1] : null;
    if (scenario.startsWith('public-')) {
      await runPublicTextInputScenario(
        scenario.substring('public-'.length),
        triggerPath: trigger,
      );
      return;
    }
    final prompt = TextInput(
      'Name',
      initialValue: switch (scenario) {
        'paste' || 'unicode' => '',
        'linear-long' => '0123456789' * 30,
        // Long enough to be windowed at a narrow width and fully visible at a
        // wide one, so an idle resize is visible as a changed draft row.
        'resize' => '0123456789' * 6,
        _ => 'alpha',
      },
    );
    if (scenario.startsWith('help-')) {
      final mode = scenario.endsWith('rich')
          ? PromptMode.rich
          : PromptMode.linear;
      final result = scenario.contains('password')
          ? await Password('Synthetic password')
                .prompt(mode: mode, output: stderr)
          : await prompt.prompt(mode: mode, output: stderr);
      // Never print the hidden answer, even for a synthetic native test.
      print(switch (result) {
        Accepted<String>(:final value) =>
          scenario.contains('password')
              ? (value == 'TrelisCanary7Q9' ? 'accepted' : 'wrong')
              : value,
        Interrupted<String>() => 'interrupt',
        Cancelled<String>() => 'cancel',
        InputEnded<String>() => 'eof',
        _ => 'failed',
      });
      return;
    }
    if (scenario == 'error') {
      final failing = TextInput(
        'Failure',
        validate: (_) => throw StateError('validation'),
      );
      try {
        await failing.prompt(mode: PromptMode.linear, output: stderr);
      } on StateError {
        // A subsequent session must still be usable after validation throws.
      }
      final result = await prompt.prompt(
        mode: PromptMode.linear,
        output: stderr,
      );
      print(result is Accepted<String> ? result.value : 'failed');
      return;
    }
    if (scenario == 'concurrent') {
      final pending = prompt.prompt(mode: PromptMode.linear, output: stderr);
      var outcome = 'overlap';
      try {
        await TextInput('Other')
            .prompt(mode: PromptMode.linear, output: stderr)
            .timeout(const Duration(seconds: 1));
      } on StateError {
        outcome = 'busy';
      } on TimeoutException {
        outcome = 'timeout';
      }
      final result = await pending;
      print('$outcome,${result is Accepted<String> ? result.value : 'failed'}');
      return;
    }
    if (scenario == 'session-retire') {
      // A scoped session over the real console whose shared writer fails while
      // its prompt is parked on the native read. The failure is injected
      // through the selected sink; console input, raw mode and restoration are
      // real. The caller catches the write failure, which is legitimate, so
      // retirement itself has to end the idle prompt.
      final output = NativeFixtureFailingStdout();
      final failure = StateError('synthetic shared writer failure');
      var outcome = 'scope-returned';
      await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Index')..start(session: session);
          final pending = TextInput(
            'Name',
            initialValue: 'alpha',
          ).prompt(session: session);
          // Wait until the prompt has painted and is parked on the console.
          if (!await paintedTextWithin(
            output,
            'Name',
            const Duration(seconds: 5),
          )) {
            final result = await pending.timeout(
              const Duration(seconds: 1),
              onTimeout: () => Unavailable<String>('prompt did not start'),
            );
            outcome =
                'no-console:${result is Unavailable<String> ? result.reason : result.runtimeType}';
            return;
          }
          // The harness captures the acquired console state while the prompt is
          // parked, so it releases the failure through a trigger file.
          if (trigger != null &&
              !await fileAppearedWithin(File(trigger), nativeTriggerLimit)) {
            outcome = 'no-trigger';
            return;
          }
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
        },
        output: output,
        mode: PromptMode.linear,
      );
      print(outcome);
      return;
    }
    final results = <String>[];
    for (var i = 0; i < (scenario == 'repeat' ? 2 : 1); i++) {
      final result = await prompt.prompt(
        mode: switch (scenario) {
          'rich' || 'dumb-rich' || 'resize' => PromptMode.rich,
          'dumb-auto' => PromptMode.automatic,
          _ => PromptMode.linear,
        },
        output: scenario == 'stdout' ? stdout : stderr,
      );
      results.add(switch (result) {
        Accepted<String>(:final value) => value,
        Cancelled<String>() => 'cancel',
        Interrupted<String>() => 'interrupt',
        InputEnded<String>() => 'eof',
        Unavailable<String>(:final reason) => 'unavailable:$reason',
      });
    }
    print(
      scenario == 'unicode'
          ? results.single.runes.map((r) => r.toRadixString(16)).join(',')
          : results.join(','),
    );
  } catch (error) {
    print('ERROR:$error');
  }
}
