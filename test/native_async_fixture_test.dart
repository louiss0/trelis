import 'dart:async';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

import 'autocomplete_native_app.dart' as autocomplete;
import 'search_select_native_app.dart' as search_select;

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

void main() {
  test('autocomplete keeps current suggestions after stale response', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final result =
        Autocomplete(
          'Name',
          suggestions: autocomplete.controlledSuggestions('stale'),
        ).prompt(
          source: ScriptedInput(
            input.stream,
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    input.add('a');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    input.add('b');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    input.add('\x1b[B\r\r');
    expect(
      (await result.timeout(
        const Duration(seconds: 2),
      ) as Accepted<String>).value,
      'Current',
    );
    await input.close();
  });

  test('search recovers after a failed query', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final result =
        SearchSelect('Pick', [
          Choice('a', 'A'),
          Choice('b', 'B'),
        ], search: search_select.controlledSearch('failure')).prompt(
          source: ScriptedInput(
            input.stream,
            output,
            outputProfile: _richProfile,
          ),
          mode: PromptMode.rich,
        );
    input.add('fail');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(output.toString(), contains('Search unavailable'));
    input.add('\x7f\x7f\x7f\x7fok');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    input.add('\r\r');
    expect(
      (await result.timeout(
        const Duration(seconds: 2),
      ) as Accepted<String>).value,
      'b',
    );
    await input.close();
  });
}
