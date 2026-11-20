import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/background_query.dart';
import 'package:trelis/src/shared_terminal.dart';

void main() {
  test(
    'a valid OSC response is consumed while keyboard bytes retain order',
    () async {
      final input = StreamController<String>();
      final coordinator = SharedReaderCoordinator();
      final reader = await coordinator.readerFor(input.stream);
      final requests = <String>[];

      final pending = reader.queryBackground(
        writeRequest: () => requests.add(osc11BackgroundRequest),
      );
      input.add('A');
      input.add('\x1b]11;rgb:ffff/ffff/ffff\x07');
      input.add('B\r');
      await input.close();

      expect(await pending, BackgroundQueryResult.light);
      expect(requests, [osc11BackgroundRequest]);

      final keys = <String>[];
      String? key;
      while ((key = await reader.next()) != null) {
        keys.add(key!);
      }
      expect(keys.join(), 'AB\r');
      await coordinator.close();
    },
  );
}
