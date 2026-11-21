import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

void main() {
  test('port accepts a numeric service port', () async {
    final result = await PortInput('Port')
        .prompt(source: SuppliedAnswer('443'));
    expect((result as Accepted<int>).value, 443);
  });
  test('address with prefix preserves host bits and spelling', () async {
    final result = await IPAddressInput(
      'Address',
      cidr: true,
    ).prompt(source: SuppliedAnswer('192.0.2.7/24'));
    final address = (result as Accepted<IPAddressValue>).value;
    expect(address.spelling, '192.0.2.7/24');
    expect(address.address.address, '192.0.2.7');
    expect(address.prefixLength, 24);
  });
  test('strict port grammar and zero opt in', () async {
    for (final value in ['0', '-1', '+1', '1,000', '1.0', '65536', '']) {
      expect(
        await PortInput('Port').prompt(source: SuppliedAnswer(value)),
        isA<Unavailable<int>>(),
        reason: value,
      );
    }
    expect(
      (await PortInput(
        'Port',
        allowZero: true,
      ).prompt(source: SuppliedAnswer('0')) as Accepted<int>).value,
      0,
    );
  });
  test('strict addresses and explicit modes', () async {
    for (final value in [
      '127.1',
      '01.2.3.4',
      '256.1.1.1',
      'example.com',
      '[::1]',
      '::1/128',
      'fe80::1%eth0',
      '::ffff:192.168.01.1',
    ]) {
      expect(
        await IPAddressInput('Address').prompt(source: SuppliedAnswer(value)),
        isA<Unavailable<IPAddressValue>>(),
        reason: value,
      );
    }
    for (final value in ['::', '2001:db8::1', '::ffff:192.0.2.1']) {
      expect(
        await IPAddressInput('Address').prompt(source: SuppliedAnswer(value)),
        isA<Accepted<IPAddressValue>>(),
        reason: value,
      );
    }
    for (final value in ['192.0.2.1/33', '::1/129', '::1', '::1/-1']) {
      expect(
        await IPAddressInput(
          'Address',
          cidr: true,
        ).prompt(source: SuppliedAnswer(value)),
        isA<Unavailable<IPAddressValue>>(),
        reason: value,
      );
    }
    final result =
        await IPAddressInput('Address', cidr: true, scoped: true).prompt(
          source: SuppliedAnswer('fe80::1%eth0/64'),
        ) as Accepted<IPAddressValue>;
    expect(result.value.zone, 'eth0');
    expect(result.value.spelling, 'fe80::1%eth0/64');
    expect(result.value.prefixLength, 64);
  });
  test(
    'invalid drafts can be corrected in linear and rich interaction',
    () async {
      for (final mode in [PromptMode.linear, PromptMode.rich]) {
        final output = StringBuffer();
        final result = await PortInput('Port').prompt(
          mode: mode,
          source: ScriptedInput(
            Stream.fromIterable(['99999\n', '\x7f\x7f\x7f\x7f\x7f443\n']),
            output,
            outputProfile: mode == PromptMode.rich
                ? _richProfile
                : const OutputProfile(),
          ),
        );
        expect((result as Accepted<int>).value, 443);
        expect(output.toString(), contains('Enter an ASCII decimal port'));
      }
    },
  );
}
