part of 'text_input.dart';

/// Absolute URLs using explicitly permitted web schemes.
final class URLInput {
  URLInput(this.label, {required Set<String> allowedSchemes})
    : allowedSchemes = Set.unmodifiable(allowedSchemes) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
    if (allowedSchemes.isEmpty ||
        allowedSchemes.any((s) => s != 'http' && s != 'https')) {
      throw ArgumentError.value(allowedSchemes, 'allowedSchemes');
    }
  }
  final String label;
  final Set<String> allowedSchemes;
  bool _active = false;

  String? _validate(String value) {
    const error =
        'Enter a valid absolute URL with an allowed scheme and no user information.';
    final match = RegExp(
      r'^([A-Za-z][A-Za-z0-9+.-]*):\/\/([^\/?#]*)(.*)$',
      dotAll: true,
    ).firstMatch(value);
    if (match == null || !allowedSchemes.contains(match[1]!.toLowerCase())) {
      return error;
    }
    final authority = match[2]!;
    final tail = match[3]!;
    if (tail.indexOf('#') != tail.lastIndexOf('#') ||
        tail.runes.any(
          (r) =>
              r < 128 &&
              !RegExp(r"^[A-Za-z0-9\-._~!$&'()*+,;=:@/?#%]$")
                  .hasMatch(String.fromCharCode(r)),
        )) {
      return error;
    }
    if (authority.isEmpty ||
        authority.contains('@') ||
        value.runes.any((r) => r <= 32 || (r >= 127 && r <= 159) || r == 92) ||
        RegExp(r'%(?![0-9A-Fa-f]{2})').hasMatch(value)) {
      return error;
    }
    String host;
    String rest;
    if (authority.startsWith('[')) {
      final end = authority.indexOf(']');
      if (end < 0) return error;
      host = authority.substring(1, end);
      rest = authority.substring(end + 1);
      final address = InternetAddress.tryParse(host);
      if (address == null ||
          address.type != InternetAddressType.IPv6 ||
          host.contains('%')) {
        return error;
      }
    } else {
      final colon = authority.indexOf(':');
      host = colon < 0 ? authority : authority.substring(0, colon);
      rest = colon < 0 ? '' : authority.substring(colon);
      if (host.isEmpty || host.contains('%')) return error;
      if (RegExp(r'^[0-9.]+$').hasMatch(host) && !_strictIpv4(host)) {
        return error;
      }
      try {
        const Uts46().toAscii(host);
      } on FormatException {
        return error;
      }
    }
    if (rest.isNotEmpty) {
      if (!RegExp(r'^:[0-9]+$').hasMatch(rest)) return error;
      final port = int.tryParse(rest.substring(1));
      if (port == null || port > 65535) return error;
    }
    return null;
  }

  Future<PromptResult<String>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          return await _terminal<String>(
            selected,
            output ?? stderr,
            (source, mode, restore) => _run(source, mode, beforeClose: restore),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<String>> _run(
    PromptSource source,
    PromptMode mode, {
    void Function()? beforeClose,
  }) async {
    if (source is SuppliedAnswer) {
      final error = _validate(source.value);
      return error == null ? Accepted(source.value) : Unavailable(error);
    }
    final scripted = source as ScriptedInput;
    if (mode == PromptMode.rich && !scripted.supportsRich) {
      return Unavailable(
        'Rich interaction unavailable; use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = scripted.supportsRich ? PromptMode.rich : PromptMode.linear;
    }
    final out = scripted.output;
    out.writeln(
      '$label. Enter an absolute URL. Draft is hidden to avoid disclosing embedded credentials. No network check is performed.',
    );
    final keys = _Keys(scripted.input.transform(utf8.encoder));
    var value = '';
    try {
      while (true) {
        final edit = await _edit(
          keys,
          value,
          out,
          secret: true,
          linear: mode == PromptMode.linear,
          sequential: mode == PromptMode.linear,
        );
        if (edit.action == 'cancel') return Cancelled();
        if (edit.action == 'interrupt') return Interrupted();
        if (edit.action != 'submit') return InputEnded();
        value = edit.value;
        final error = _validate(value);
        if (error == null) {
          final authority = value
              .substring(value.indexOf('//') + 2)
              .split(RegExp(r'[/\?#]'))
              .first;
          if (!authority.startsWith('[')) {
            final host = authority.split(':').first;
            const idna = Uts46();
            out.writeln(
              'Host interpretation -- Unicode: ${idna.toUnicode(host)}; ASCII: ${idna.toAscii(host)}.',
            );
          }
          out.writeln('Accepted URL: $value');
          return Accepted(value);
        }
        out.writeln(error);
      }
    } finally {
      try {
        beforeClose?.call();
      } finally {
        await keys.close();
      }
    }
  }
}

bool _strictIpv4(String value) {
  final parts = value.split('.');
  return parts.length == 4 &&
      parts.every(
        (p) =>
            RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(p) && int.parse(p) <= 255,
      );
}

/// One bare SMTP transport mailbox; validity does not imply deliverability.
final class EmailInput {
  EmailInput(String label, {this.smtpUtf8 = false, String initialValue = ''}) {
    if (initialValue.isNotEmpty && _validate(initialValue) != null) {
      throw ArgumentError('Invalid initial email address.');
    }
    _input = TextInput(
      '$label (bare SMTP address${smtpUtf8 ? '; SMTPUTF8 support required for Unicode local parts' : '; ASCII local part'}, no deliverability check)',
      initialValue: initialValue,
      required: true,
      validate: _validate,
    );
  }
  final bool smtpUtf8;
  late final TextInput _input;

  String? _validate(String value) {
    const error = 'Enter one valid bare SMTP address.';
    final at = value.lastIndexOf('@');
    if (at <= 0 || at == value.length - 1) return error;
    final local = value.substring(0, at);
    final domain = value.substring(at + 1);
    if (utf8.encode(local).length > 64) return error;
    if (!smtpUtf8 && local.runes.any((r) => r > 127)) return error;
    if (local.startsWith('"')) {
      if (local.length < 2 || !local.endsWith('"')) return error;
      var escape = false;
      for (final r in local.substring(1, local.length - 1).runes) {
        if (r < 32 || r == 127) return error;
        if (escape) {
          escape = false;
          continue;
        }
        if (r == 92) {
          escape = true;
          continue;
        }
        if (r == 34) return error;
      }
      if (escape) return error;
    } else {
      if (local.startsWith('.') ||
          local.endsWith('.') ||
          local.contains('..')) {
        return error;
      }
      for (final r in local.runes) {
        if (r > 127 && smtpUtf8) continue;
        if (!RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]$")
            .hasMatch(String.fromCharCode(r))) {
          return error;
        }
      }
    }
    if (domain.startsWith('[') && domain.endsWith(']')) {
      final raw = domain.substring(1, domain.length - 1);
      final ipv6 =
          raw.length >= 5 && raw.substring(0, 5).toLowerCase() == 'ipv6:';
      final address = InternetAddress.tryParse(ipv6 ? raw.substring(5) : raw);
      if (address == null ||
          address.type !=
              (ipv6 ? InternetAddressType.IPv6 : InternetAddressType.IPv4) ||
          (!ipv6 && !_strictIpv4(raw)) ||
          raw.contains('%') ||
          utf8.encode(value).length > 254) {
        return error;
      }
    } else {
      try {
        final ascii = const Uts46().toAscii(domain);
        if (ascii.endsWith('.') ||
            utf8.encode(local).length + 1 + ascii.length > 254) {
          return error;
        }
      } on FormatException {
        return error;
      }
    }
    return null;
  }

  Future<PromptResult<String>> prompt({
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
    if (result is Accepted<String> && source is! SuppliedAnswer) {
      final domain = result.value.substring(result.value.lastIndexOf('@') + 1);
      final sink = source is ScriptedInput ? source.output : output ?? stderr;
      if (domain.startsWith('[')) {
        sink.writeln('Transport address literal: $domain.');
      } else {
        const idna = Uts46();
        sink.writeln(
          'Domain interpretation -- Unicode: ${idna.toUnicode(domain)}; ASCII: ${idna.toAscii(domain)}.',
        );
      }
    }
    return result;
  }
}
