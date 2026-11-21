import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test(
    'linear time entry accepts a time of day without date or zone',
    () async {
      final result = await TimeInput('Time')
          .prompt(source: SuppliedAnswer('23:59'), mode: PromptMode.linear);
      expect(
        (result as Accepted<({int hour, int minute, int? second})>).value,
        (hour: 23, minute: 59, second: null),
      );
    },
  );
  test('12-hour seconds preserve time-of-day meaning', () async {
    final input = TimeInput('Time', twelveHour: true, seconds: true);
    final result = await input.prompt(source: SuppliedAnswer('12:05:09 AM'));
    expect((result as Accepted<({int hour, int minute, int? second})>).value, (
      hour: 0,
      minute: 5,
      second: 9,
    ));
  });
  test(
    'rich segment adjustment stops at boundaries with portable keys',
    () async {
      final out = StringBuffer();
      final result = await TimeInput('Time', initialValue: '23:59').prompt(
        source: ScriptedInput(
          Stream.value('+\t+\t\t\r'),
          out,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect(
        (result as Accepted<({int hour, int minute, int? second})>).value,
        (hour: 23, minute: 59, second: null),
      );
      expect(out.toString(), contains('Focus: Minute'));
      expect(out.toString(), contains('without wrapping'));
    },
  );

  test('invalid exact formats are rejected without normalization', () async {
    for (final value in ['24:00', '23:60', '1:00', '12:00 PM', ' 01:00']) {
      expect(
        await TimeInput('Time').prompt(source: SuppliedAnswer(value)),
        isA<Unavailable>(),
      );
    }
    final twelve = TimeInput('Time', twelveHour: true, seconds: true);
    for (final value in [
      '00:00:00 AM',
      '13:00:00 PM',
      '12:60:00 AM',
      '12:00:60 AM',
      '12:00:00',
      '12:00:00 am',
    ]) {
      expect(
        await twelve.prompt(source: SuppliedAnswer(value)),
        isA<Unavailable>(),
      );
    }
    expect(
      (await twelve.prompt(
        source: SuppliedAnswer('12:00:00 PM'),
      ) as Accepted).value,
      (hour: 12, minute: 0, second: 0),
    );
  });
  test('linear invalid draft remains editable', () async {
    final out = StringBuffer();
    final result = await TimeInput('Time').prompt(
      source: ScriptedInput(
        Stream.value('24:00\r\x7f\x7f\x7f\x7f\x7f23:00\r'),
        out,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<({int hour, int minute, int? second})>).value, (
      hour: 23,
      minute: 0,
      second: null,
    ));
    expect(out.toString(), contains('Enter HH:mm'));
  });
  test('rich adjustment changes only focused segment and period', () async {
    final out = StringBuffer();
    final result =
        await TimeInput(
          'Time',
          twelveHour: true,
          seconds: true,
          initialValue: '12:59:59 AM',
        ).prompt(
          source: ScriptedInput(
            Stream.value('+\t+\t+\t+\t\t\r'),
            out,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<({int hour, int minute, int? second})>).value, (
      hour: 12,
      minute: 59,
      second: 59,
    ));
    expect(out.toString(), contains('Focus: Period'));
  });
  test('cancellation interruption EOF and capability are distinct', () async {
    final input = TimeInput('Time');
    for (final mode in [PromptMode.rich, PromptMode.linear]) {
      expect(
        await input.prompt(
          source: ScriptedInput(
            Stream.value('\x03'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: mode,
        ),
        isA<Interrupted>(),
      );
      expect(
        await input.prompt(
          source: ScriptedInput(
            const Stream.empty(),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: mode,
        ),
        isA<InputEnded>(),
      );
      expect(
        await input.prompt(
          source: ScriptedInput(
            mode == PromptMode.linear
                ? Stream.value('/cancel\r')
                : (() async* {
                    yield '\x1b';
                    await Future<void>.delayed(
                      const Duration(milliseconds: 200),
                    );
                  })(),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: mode,
        ),
        isA<Cancelled>(),
      );
    }
    expect(
      await input.prompt(
        source: ScriptedInput(
          const Stream.empty(),
          StringBuffer(),
          supportsRich: false,
        ),
        mode: PromptMode.rich,
      ),
      isA<Unavailable>(),
    );
  });
  test(
    'rich direct entry keeps invalid draft available for correction',
    () async {
      final output = StringBuffer();
      final result = await TimeInput('Time').prompt(
        mode: PromptMode.rich,
        source: ScriptedInput(
          Stream.value('\t\t\r24:00\r\r\x7f\x7f\x7f\x7f\x7f23:00\r\t\r'),
          output,
          outputProfile: _richProfile,
        ),
      );
      expect(
        (result as Accepted<({int hour, int minute, int? second})>).value,
        (hour: 23, minute: 0, second: null),
      );
      expect(output.toString(), contains('Draft: 24:00'));
      expect(output.toString(), contains('Enter HH:mm'));
    },
  );
  test(
    'default is editable and constructor rejects invalid defaults',
    () async {
      expect(() => TimeInput('T', initialValue: '24:00'), throwsArgumentError);
      final result = await TimeInput('T', initialValue: '12:34').prompt(
        source: ScriptedInput(
          Stream.value('\x7f\x7f56\r'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.linear,
      );
      expect(
        (result as Accepted<({int hour, int minute, int? second})>).value,
        (hour: 12, minute: 56, second: null),
      );
    },
  );
  test('rejects concurrent sessions and permits reuse', () async {
    final input = TimeInput('T');
    final controller = StreamController<String>();
    final pending = input.prompt(
      source: ScriptedInput(
        controller.stream,
        StringBuffer(),
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(
      () => input.prompt(source: SuppliedAnswer('12:00')),
      throwsStateError,
    );
    controller.add('\x03');
    expect(await pending, isA<Interrupted>());
    await controller.close();
    expect(
      await input.prompt(source: SuppliedAnswer('12:00')),
      isA<Accepted>(),
    );
  });
  test('arrow adjustment stops at lower bounds without carry', () async {
    final result = await TimeInput('T', seconds: true, initialValue: '00:00:00')
        .prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B\t\x1b[B\t\x1b[B\t\t\r'),
            StringBuffer(),
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<({int hour, int minute, int? second})>).value, (
      hour: 0,
      minute: 0,
      second: 0,
    ));
  });
  test(
    'identified pasted controls do not adjust or submit rich time',
    () async {
      final result = await TimeInput('T', initialValue: '12:34').prompt(
        source: ScriptedInput(
          Stream.value('\x1b[200~+\t\t\t\r\x1b[201~'),
          StringBuffer(),
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect(result, isA<InputEnded>());
    },
  );
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);
