part of 'text_input.dart';

/// Local ASCII decimal port entry. Zero requires an explicit bind-request opt-in.
final class PortInput {
  PortInput(String label, {this.allowZero = false, String initialValue = ''}) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    _input = TextInput(
      '$label (ASCII decimal ${allowZero ? '0-65535; zero requests automatic allocation' : '1-65535'}; availability is not checked)',
      initialValue: initialValue,
      required: true,
      validate: (value) => _parse(value) == null
          ? 'Enter an ASCII decimal port from ${allowZero ? 0 : 1} to 65535.'
          : null,
    );
    if (initialValue.isNotEmpty && _parse(initialValue) == null) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }
  final bool allowZero;
  late final TextInput _input;
  int? _parse(String value) {
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return null;
    final number = int.tryParse(value);
    return number != null && number >= (allowZero ? 0 : 1) && number <= 65535
        ? number
        : null;
  }

  Future<PromptResult<int>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    final result = await _input.prompt(
      source: source,
      mode: mode,
      userPreference: userPreference,
      applicationPreference: applicationPreference,
      output: output,
    );
    if (result is Accepted<String>) return Accepted(_parse(result.value)!);
    if (result is Cancelled<String>) return Cancelled();
    if (result is Interrupted<String>) return Interrupted();
    if (result is InputEnded<String>) return InputEnded();
    return Unavailable((result as Unavailable<String>).reason);
  }
}

/// An address, its original spelling, and separately labeled prefix and zone.
final class IPAddressValue {
  IPAddressValue._(this.spelling, this.address, this.prefixLength, this.zone);
  final String spelling;
  final InternetAddress address;
  final int? prefixLength;
  final String? zone;
}

/// Numeric address entry; parsing never resolves names or checks the network.
final class IPAddressInput {
  IPAddressInput(
    String label, {
    this.cidr = false,
    this.scoped = false,
    String initialValue = '',
  }) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    _input = TextInput(
      '$label (numeric IPv4 or IPv6${cidr ? ' with required /prefix, retaining host bits' : ''}${scoped ? '; IPv6 zone uses % followed by ASCII letters, digits, underscore, hyphen or dot; zone identity is environment-dependent' : ''}; reachability and interface existence are not checked)',
      required: true,
      initialValue: initialValue,
      validate: (value) => _parse(value) == null
          ? 'Enter a valid numeric IPv4 or IPv6 address${cidr ? ' with a family-specific prefix (0-32 or 0-128)' : ''}${scoped ? ' and optional IPv6 %zone' : ''}; brackets and hostnames are not accepted.'
          : null,
    );
    if (initialValue.isNotEmpty && _parse(initialValue) == null) {
      throw ArgumentError.value(initialValue, 'initialValue');
    }
  }
  final bool cidr;
  final bool scoped;
  late final TextInput _input;

  IPAddressValue? _parse(String value) {
    final parts = value.split('/');
    if (parts.length != (cidr ? 2 : 1)) return null;
    int? prefix;
    if (cidr) {
      if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(parts[1])) return null;
      prefix = int.tryParse(parts[1]);
      if (prefix == null) return null;
    }
    final zones = parts[0].split('%');
    if (zones.length > 2 ||
        (zones.length == 2 &&
            (!scoped || !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(zones[1])))) {
      return null;
    }
    final raw = zones[0];
    if (raw.contains('.')) {
      final ipv4 = raw.substring(raw.lastIndexOf(':') + 1).split('.');
      if (ipv4.length != 4 ||
          ipv4.any(
            (octet) =>
                !RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(octet) ||
                int.parse(octet) > 255,
          )) {
        return null;
      }
    }
    if (raw.contains('[') || raw.contains(']')) return null;
    final address = InternetAddress.tryParse(raw);
    if (address == null ||
        (zones.length == 2 && address.type != InternetAddressType.IPv6) ||
        (prefix != null &&
            prefix > (address.type == InternetAddressType.IPv4 ? 32 : 128))) {
      return null;
    }
    return IPAddressValue._(
      value,
      address,
      prefix,
      zones.length == 2 ? zones[1] : null,
    );
  }

  Future<PromptResult<IPAddressValue>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    final result = await _input.prompt(
      source: source,
      mode: mode,
      userPreference: userPreference,
      applicationPreference: applicationPreference,
      output: output,
    );
    if (result is Accepted<String>) return Accepted(_parse(result.value)!);
    if (result is Cancelled<String>) return Cancelled();
    if (result is Interrupted<String>) return Interrupted();
    if (result is InputEnded<String>) return InputEnded();
    return Unavailable((result as Unavailable<String>).reason);
  }
}
