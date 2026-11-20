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
