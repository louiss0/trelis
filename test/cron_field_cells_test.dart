import 'package:trelis/src/cron_field_cells.dart';
import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  group('field-cell schema', () {
    test('unix exposes five ordered required cells', () {
      final cells = cronFieldCells(CronProfile.unix);
      expect(cells.map((cell) => cell.name), [
        'minute',
        'hour',
        'day-of-month',
        'month',
        'day-of-week',
      ]);
      expect(cells.map((cell) => cell.position), [1, 2, 3, 4, 5]);
      expect(cells.map((cell) => cell.total), [5, 5, 5, 5, 5]);
      expect(cells.map((cell) => cell.index), [0, 1, 2, 3, 4]);
      expect(cells.every((cell) => !cell.optional), isTrue);
      expect(cells[0].rangeCue, '0-59');
      expect(cells[1].rangeCue, '0-23');
      expect(cells[4].rangeCue, contains('SUN'));
    });

    test('quartz exposes six required cells plus optional year', () {
      final cells = cronFieldCells(CronProfile.quartz);
      expect(cells.map((cell) => cell.name), [
        'second',
        'minute',
        'hour',
        'day-of-month',
        'month',
        'day-of-week',
        'year',
      ]);
      expect(cells.map((cell) => cell.position), [1, 2, 3, 4, 5, 6, 7]);
      expect(cells.map((cell) => cell.total), [7, 7, 7, 7, 7, 7, 7]);
      expect(cells.take(6).every((cell) => !cell.optional), isTrue);
      expect(cells[6].optional, isTrue);
      expect(cells[6].rangeCue, '1970-2199');
      expect(cells[3].rangeCue, contains('?'));
      expect(cells[5].rangeCue, contains('?'));
    });
  });

  group('per-cell validation', () {
    test('unix cells accept their grammar and reject out-of-range tokens', () {
      expect(cronFieldCellError(CronProfile.unix, 0, '*/15'), isNull);
      expect(cronFieldCellError(CronProfile.unix, 0, '0-30/5'), isNull);
      expect(cronFieldCellError(CronProfile.unix, 1, '23'), isNull);
      expect(cronFieldCellError(CronProfile.unix, 3, 'JAN-MAR'), isNull);
      expect(cronFieldCellError(CronProfile.unix, 3, 'feb'), isNull);
      expect(cronFieldCellError(CronProfile.unix, 4, 'MON-FRI'), isNull);
      expect(cronFieldCellError(CronProfile.unix, 4, '7'), isNull);

      expect(cronFieldCellError(CronProfile.unix, 0, '60'), contains('minute'));
      expect(cronFieldCellError(CronProfile.unix, 1, '24'), contains('hour'));
      expect(
        cronFieldCellError(CronProfile.unix, 2, '0'),
        contains('day-of-month'),
      );
      expect(cronFieldCellError(CronProfile.unix, 3, '13'), contains('month'));
      expect(
        cronFieldCellError(CronProfile.unix, 4, '8'),
        contains('day-of-week'),
      );
      expect(
        cronFieldCellError(CronProfile.unix, 0, 'MON'),
        contains('minute'),
      );
    });

    test(
      'empty drafts carry no cell error; mandatory emptiness is separate',
      () {
        for (var i = 0; i < 5; i++) {
          expect(cronFieldCellError(CronProfile.unix, i, ''), isNull);
        }
        for (var i = 0; i < 7; i++) {
          expect(cronFieldCellError(CronProfile.quartz, i, ''), isNull);
        }
      },
    );

    test('quartz numeric cells mirror the unix grammar per field', () {
      expect(cronFieldCellError(CronProfile.quartz, 0, '59'), isNull);
      expect(cronFieldCellError(CronProfile.quartz, 0, '60'), isNotNull);
      expect(cronFieldCellError(CronProfile.quartz, 2, '23'), isNull);
      expect(cronFieldCellError(CronProfile.quartz, 2, '24'), isNotNull);
      expect(cronFieldCellError(CronProfile.quartz, 4, 'DEC'), isNull);
      expect(
        cronFieldCellError(CronProfile.quartz, 4, 'JANUARY'),
        contains('month'),
      );
    });

    test('quartz day-of-month accepts ?, L, LW, L-n, L-nW and nW', () {
      for (final token in ['?', 'L', 'LW', 'L-2', 'L-15W', '15W', '1-31']) {
        expect(
          cronFieldCellError(CronProfile.quartz, 3, token),
          isNull,
          reason: token,
        );
      }
      for (final token in ['L-0', 'L-31', '0W', '32W', 'L-X', 'LW-2']) {
        expect(
          cronFieldCellError(CronProfile.quartz, 3, token),
          isNotNull,
          reason: token,
        );
      }
    });

    test('quartz day-of-week accepts ?, L, dL and d#n', () {
      for (final token in ['?', 'L', 'MONL', '5L', 'MON#2', '3#5', 'SUN-SAT']) {
        expect(
          cronFieldCellError(CronProfile.quartz, 5, token),
          isNull,
          reason: token,
        );
      }
      for (final token in ['MON#6', 'MON#0', '#2', 'L#2', '8']) {
        expect(
          cronFieldCellError(CronProfile.quartz, 5, token),
          isNotNull,
          reason: token,
        );
      }
    });

    test('quartz year cell is optional but bounded to 1970-2199', () {
      expect(cronFieldCellError(CronProfile.quartz, 6, ''), isNull);
      expect(cronFieldCellError(CronProfile.quartz, 6, '2025'), isNull);
      expect(cronFieldCellError(CronProfile.quartz, 6, '1970'), isNull);
      expect(cronFieldCellError(CronProfile.quartz, 6, '2199'), isNull);
      expect(cronFieldCellError(CronProfile.quartz, 6, '1969'), isNotNull);
      expect(cronFieldCellError(CronProfile.quartz, 6, '2200'), isNotNull);
    });
  });

  group('whole-draft cell validation', () {
    List<String> unixCells([List<String?>? overrides]) =>
        ['0', '0', '*', '*', '*'].indexed.map((pair) {
          final (index, value) = pair;
          return overrides != null &&
                  index < overrides.length &&
                  overrides[index] != null
              ? overrides[index]!
              : value;
        }).toList();

    List<String> quartzCells([Map<int, String>? overrides]) =>
        ['0', '0', '0', '?', '*', 'MON', ''].indexed.map((pair) {
          final (index, value) = pair;
          final override = overrides?[index];
          return override ?? value;
        }).toList();

    test('accepts a complete valid unix draft', () {
      expect(cronFieldCellsError(CronProfile.unix, unixCells()), isNull);
    });

    test('reports the first empty mandatory cell by name', () {
      final cells = unixCells();
      cells[2] = '';
      final error = cronFieldCellsError(CronProfile.unix, cells);
      expect(error, isNotNull);
      expect(error!.index, 2);
      expect(error.message, contains('day-of-month'));
    });

    test('empty cells win over later invalid cells', () {
      final cells = unixCells([null, '25', '']);
      cells[4] = 'bogus';
      final error = cronFieldCellsError(CronProfile.unix, cells);
      expect(error!.index, 2);
      expect(error.message, contains('day-of-month'));
    });

    test('reports the first invalid populated cell', () {
      final cells = unixCells([null, '25']);
      final error = cronFieldCellsError(CronProfile.unix, cells);
      expect(error!.index, 1);
      expect(error.message, contains('hour'));
    });

    test('quartz accepts six populated cells with an empty year cell', () {
      expect(cronFieldCellsError(CronProfile.quartz, quartzCells()), isNull);
    });

    test('quartz accepts a populated year cell', () {
      final cells = quartzCells({6: '2030'});
      expect(cronFieldCellsError(CronProfile.quartz, cells), isNull);
    });

    test('quartz rejects both day cells set to ?', () {
      final cells = quartzCells({3: '?', 5: '?'});
      final error = cronFieldCellsError(CronProfile.quartz, cells);
      expect(error, isNotNull);
      expect(error!.index, 3);
      expect(error.message, contains('?'));
    });

    test('quartz rejects neither day cell set to ?', () {
      final cells = quartzCells({3: '*', 5: 'MON'});
      final error = cronFieldCellsError(CronProfile.quartz, cells);
      expect(error, isNotNull);
      expect(error!.index, 3);
    });

    test('quartz accepts ? in exactly one day cell', () {
      expect(
        cronFieldCellsError(CronProfile.quartz, quartzCells({3: '?', 5: '*'})),
        isNull,
      );
      expect(
        cronFieldCellsError(CronProfile.quartz, quartzCells({3: '15', 5: '?'})),
        isNull,
      );
    });

    test('quartz day exclusivity runs after per-field syntax', () {
      // Both day cells are syntactically fine but neither is '?'.
      final cells = quartzCells({3: 'L', 5: 'MON'});
      final error = cronFieldCellsError(CronProfile.quartz, cells);
      expect(error!.index, 3);
      expect(error.message, contains('?'));
    });

    test('rejects a wrong cell count', () {
      final error = cronFieldCellsError(CronProfile.unix, ['0', '0']);
      expect(error, isNotNull);
    });
  });

  group('expression assembly', () {
    test('unix joins five cells with single ASCII spaces verbatim', () {
      expect(
        cronAssembleExpression(CronProfile.unix, [
          '05',
          '0',
          '1-5',
          'mon-fri',
          'SUN',
        ]),
        '05 0 1-5 mon-fri SUN',
      );
    });

    test('quartz emits six fields when the year cell is empty', () {
      final expression = cronAssembleExpression(CronProfile.quartz, [
        '0',
        '30',
        '9',
        '?',
        '*',
        'MON-FRI',
        '',
      ]);
      expect(expression, '0 30 9 ? * MON-FRI');
      expect(expression.endsWith(' '), isFalse);
      expect(expression.split(' '), hasLength(6));
    });

    test('quartz emits seven fields when the year cell is populated', () {
      final expression = cronAssembleExpression(CronProfile.quartz, [
        '0',
        '30',
        '9',
        '?',
        '*',
        'MON-FRI',
        '2025-2030',
      ]);
      expect(expression.split(' '), hasLength(7));
      expect(expression, endsWith('2025-2030'));
    });

    test('rejects a wrong cell count', () {
      expect(
        () => cronAssembleExpression(CronProfile.unix, ['0', '0', '*', '*']),
        throwsArgumentError,
      );
      expect(
        () => cronAssembleExpression(CronProfile.quartz, List.filled(6, '0')),
        throwsArgumentError,
      );
    });

    test('enforces the 4096 UTF-16 code-unit bound including separators', () {
      final cells = List.filled(5, '0');
      cells[0] = '1' * cronMaxExpressionLength;
      expect(
        () => cronAssembleExpression(CronProfile.unix, cells),
        throwsArgumentError,
      );
      // Exactly at the bound still assembles: four single-char cells plus
      // four separators account for the remaining 8 code units.
      cells[0] = '1' * (cronMaxExpressionLength - 8);
      expect(
        cronAssembleExpression(CronProfile.unix, cells).length,
        cronMaxExpressionLength,
      );
    });
  });

  group('initialValue', () {
    test('empty initialValue leaves every cell empty', () {
      expect(cronInitialFieldCells(CronProfile.unix, ''), ['', '', '', '', '']);
      expect(cronInitialFieldCells(CronProfile.quartz, ''), [
        '',
        '',
        '',
        '',
        '',
        '',
        '',
      ]);
    });

    test('valid values split into ordered cells', () {
      expect(cronInitialFieldCells(CronProfile.unix, '30 9 15 6 MON'), [
        '30',
        '9',
        '15',
        '6',
        'MON',
      ]);
      expect(cronInitialFieldCells(CronProfile.quartz, '0 30 9 ? * MON'), [
        '0',
        '30',
        '9',
        '?',
        '*',
        'MON',
        '',
      ]);
      expect(cronInitialFieldCells(CronProfile.quartz, '0 30 9 L * ? 2030'), [
        '0',
        '30',
        '9',
        'L',
        '*',
        '?',
        '2030',
      ]);
    });

    test('ASCII space runs split cleanly', () {
      expect(cronInitialFieldCells(CronProfile.unix, '0  9   15 * *'), [
        '0',
        '9',
        '15',
        '*',
        '*',
      ]);
    });

    test('constructor rejects malformed, out-of-range, padded and wrong-count values', () {
      CronInput bad(String value, CronProfile profile) =>
          CronInput('Schedule', profile: profile, initialValue: value);
      expect(() => bad('not a cron', CronProfile.unix), throwsArgumentError);
      expect(() => bad('0 0 32 * *', CronProfile.unix), throwsArgumentError);
      expect(() => bad('0 0 * *', CronProfile.unix), throwsArgumentError);
      expect(() => bad('0 0 * * * *', CronProfile.unix), throwsArgumentError);
      expect(() => bad(' 0 0 * * *', CronProfile.unix), throwsArgumentError);
      expect(() => bad('0 0 * * * ', CronProfile.unix), throwsArgumentError);
      expect(() => bad('0 0 0 * * *', CronProfile.quartz), throwsArgumentError);
      expect(
        () => bad('0 0 0 * * * * *', CronProfile.quartz),
        throwsArgumentError,
      );
      expect(
        () => bad('0 0 0 ? * ? 1800', CronProfile.quartz),
        throwsArgumentError,
      );
    });

    test(
      'constructor accepts valid unix, six-field and seven-field values',
      () {
        expect(
          () => CronInput(
            'Schedule',
            profile: CronProfile.unix,
            initialValue: '*/15 9-17 * JAN,MAR MON-FRI',
          ),
          returnsNormally,
        );
        expect(
          () => CronInput(
            'Schedule',
            profile: CronProfile.quartz,
            initialValue: '0 0 12 ? * MON-FRI',
          ),
          returnsNormally,
        );
        expect(
          () => CronInput(
            'Schedule',
            profile: CronProfile.quartz,
            initialValue: '0 0 12 L * ? 2025-2030',
          ),
          returnsNormally,
        );
        expect(
          () => CronInput('Schedule', profile: CronProfile.unix),
          returnsNormally,
        );
      },
    );

    test('reusable prompts reset to the initial cells on every run', () async {
      final input = CronInput(
        'Schedule',
        profile: CronProfile.unix,
        initialValue: '30 9 * * MON',
      );
      for (var run = 0; run < 2; run++) {
        final result = await input.prompt(
          source: ScriptedInput(
            Stream.value('\r'),
            StringBuffer(),
            outputProfile: OutputProfile(
              cursor: CapabilitySupport.supported,
              geometry: OutputGeometry.fixed(columns: 80, rows: 24),
            ),
          ),
          mode: PromptMode.linear,
        );
        expect(
          (result as Accepted<CronExpression>).value.expression,
          '30 9 * * MON',
        );
      }
    });
  });
}
