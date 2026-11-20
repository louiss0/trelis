import 'dart:async';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'distinct environments route rendering and identity to their outputs',
    () async {
      final richOutput = StringBuffer();
      final linearOutput = StringBuffer();
      final rich = TerminalEnvironment.scripted(
        input: Stream.value('Ada\r'),
        output: richOutput,
        profile: OutputProfile(
          cursor: CapabilitySupport.supported,
          geometry: OutputGeometry.fixed(columns: 80, rows: 24),
          glyphs: GlyphSet.unicode,
        ),
        ownershipIdentity: 'rich-output',
      );
      final linear = TerminalEnvironment.scripted(
        input: Stream.value('Grace\r'),
        output: linearOutput,
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ownershipIdentity: 'linear-output',
      );

      final richResult = await TextInput('Name')
          .prompt(terminal: rich, mode: PromptMode.rich);
      final linearResult = await TextInput('Name')
          .prompt(terminal: linear, mode: PromptMode.linear);

      expect((richResult as Accepted<String>).value, 'Ada');
      expect((linearResult as Accepted<String>).value, 'Grace');
      expect(richOutput.toString(), contains('\x1b[2K'));
      expect(linearOutput.toString(), isNot(contains('\x1b[2K')));
      expect(rich.ownershipIdentity, 'rich-output');
      expect(linear.ownershipIdentity, 'linear-output');
      expect(rich.output, same(richOutput));
      expect(linear.output, same(linearOutput));
    },
  );

  test(
    'caller stream stays open by default and reports cancellation',
    () async {
      var cancellations = 0;
      final input = StreamController<String>(onCancel: () => cancellations++);
      final output = StringBuffer();
      input.add('Ada\r');
      final environment = TerminalEnvironment.scripted(
        input: input.stream,
        output: output,
      );

      final result = await TextInput('Name')
          .prompt(terminal: environment, mode: PromptMode.linear);

      expect((result as Accepted<String>).value, 'Ada');
      expect(input.isClosed, isFalse, reason: 'the caller owns the stream');
      expect(
        cancellations,
        1,
        reason: 'reader cancellation still reaches the caller stream',
      );
      await input.close();
    },
  );

  test('explicit ownership transfer closes the caller stream once', () async {
    var cancellations = 0;
    final input = StreamController<String>(onCancel: () => cancellations++);
    final environment = TerminalEnvironment.scripted(
      input: input.stream,
      output: StringBuffer(),
      closeInput: input.close,
    );
    input.add('Ada\r');

    final result = await TextInput('Name')
        .prompt(terminal: environment, mode: PromptMode.linear);

    expect((result as Accepted<String>).value, 'Ada');
    expect(input.isClosed, isTrue);
    expect(cancellations, 1);
  });

  test(
    'failed acquisition closes transferred input and reports the error',
    () async {
      final input = StreamController<String>();
      final acquisitionFailure = StateError('cannot acquire');
      final adapter = FailingTerminalIo(
        input: input.stream,
        output: StringBuffer(),
        acquireError: acquisitionFailure,
      );
      final environment = TerminalEnvironment.custom(
        adapter: adapter,
        closeInput: input.close,
      );

      await expectLater(
        TextInput('Name')
            .prompt(terminal: environment, mode: PromptMode.linear),
        throwsA(same(acquisitionFailure)),
      );

      expect(adapter.events, ['acquire']);
      expect(input.isClosed, isTrue);
    },
  );

  test(
    'failed restoration closes transferred input and reports the error',
    () async {
      final input = StreamController<String>();
      final restorationFailure = StateError('cannot restore');
      final adapter = FailingTerminalIo(
        input: input.stream,
        output: StringBuffer(),
        restoreError: restorationFailure,
      );
      final environment = TerminalEnvironment.custom(
        adapter: adapter,
        closeInput: input.close,
      );
      input.add('Grace\r');

      await expectLater(
        TextInput('Name')
            .prompt(terminal: environment, mode: PromptMode.linear),
        throwsA(same(restorationFailure)),
      );

      expect(adapter.events, ['acquire', 'restore']);
      expect(input.isClosed, isTrue);
    },
  );

  test('redirected native output declares no unsuitable capabilities', () {
    final profile = TerminalEnvironment.nativeProfile(
      hasTerminal: false,
      supportsRich: true,
      term: 'xterm-256color',
      columns: 120,
      rows: 40,
    );

    expect(profile.cursor, CapabilitySupport.unsupported);
    expect(profile.alternateScreen, CapabilitySupport.unsupported);
    expect(profile.geometry.isAutomatic, isTrue);
    expect(profile.colorDepth, ColorDepth.none);
  });

  test('feedback does not invent a colour profile for unprofiled output', () {
    final colors = ColorTheme(
      foreground: TerminalColor.rgb(220, 20, 40),
      background: const TerminalColor.terminalDefault(),
      muted: const TerminalColor.terminalDefault(),
      accent: const TerminalColor.terminalDefault(),
      selectionForeground: const TerminalColor.terminalDefault(),
      selectionBackground: const TerminalColor.terminalDefault(),
      success: const TerminalColor.terminalDefault(),
      warning: const TerminalColor.terminalDefault(),
      error: const TerminalColor.terminalDefault(),
      border: const TerminalColor.terminalDefault(),
    );
    final declaredOutput = StringBuffer();
    final undeclaredOutput = StringBuffer();

    Text('Ready', colors: colors).present(
      terminal: TerminalEnvironment.scripted(
        input: const Stream<String>.empty(),
        output: declaredOutput,
        profile: const OutputProfile(colorDepth: ColorDepth.rgb),
      ),
    );
    Text('Ready', colors: colors).present(
      terminal: FailingTerminalIo(
        input: const Stream<String>.empty(),
        output: undeclaredOutput,
      ),
    );

    expect(declaredOutput.toString(), contains('\x1b['));
    expect(undeclaredOutput.toString(), 'Ready\n');
  });
}

final class FailingTerminalIo implements TerminalIo {
  FailingTerminalIo({
    required this.input,
    required this.output,
    this.acquireError,
    this.restoreError,
  });

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const {};

  final Object? acquireError;
  final Object? restoreError;
  final List<String> events = [];

  @override
  TerminalLease acquire() {
    events.add('acquire');
    if (acquireError != null) throw acquireError!;
    return TerminalLease(() {
      events.add('restore');
      if (restoreError != null) throw restoreError!;
    });
  }
}
