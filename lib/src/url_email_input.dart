part of 'text_input.dart';

/// Absolute URLs using explicitly permitted web schemes.
final class URLInput {
  URLInput(
    this.label, {
    required Set<String> allowedSchemes,
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) : allowedSchemes = Set.unmodifiable(allowedSchemes),
       supplementaryHelp = List.unmodifiable(supplementaryHelp) {
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
  final ColorTheme colors;
  final PromptStructure structure;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
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
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    if (session != null) {
      return session._promptRunner(
        _run,
        source: source,
        mode: mode,
        userPreference: userPreference,
        applicationPreference: applicationPreference,
        output: output,
        terminal: terminal,
        outputProfile: outputProfile,
      );
    }
    if (_active) throw StateError('A prompt session is already active.');
    _active = true;
    try {
      final selected =
          mode ??
          userPreference ??
          applicationPreference ??
          PromptMode.automatic;
      if (source != null && terminal != null) {
        throw ArgumentError('Specify either source or terminal, not both.');
      }
      if (output != null && terminal != null) {
        throw ArgumentError('Specify either output or terminal, not both.');
      }
      if (source == null) {
        if (_terminalActive) {
          throw StateError('A terminal session is already active.');
        }
        _terminalActive = true;
        try {
          if (terminal != null) {
            final lease = terminal.acquire();
            return await _restoreAfter(
              () => _run(
                ScriptedInput(
                  terminal.input,
                  terminal.output,
                  supportsRich: terminal.supportsRich,
                  outputProfile: _terminalOutputProfile(terminal),
                  hardColorDisabled:
                      terminal.environment['NO_COLOR']?.isNotEmpty == true,
                  resizeObserver: _terminalResizeObserver(terminal),
                ),
                selected,
                outputProfile: outputProfile,
              ),
              lease.restore,
            );
          }
          return await _terminal<String>(
            selected,
            output ?? stderr,
            (source, mode, _) =>
                _run(source, mode, outputProfile: outputProfile),
          );
        } finally {
          _terminalActive = false;
        }
      }
      return await _run(source, selected, outputProfile: outputProfile);
    } finally {
      _active = false;
    }
  }

  Future<PromptResult<String>> _run(
    PromptSource source,
    PromptMode mode, {
    OutputProfile? outputProfile,
    _Keys? keys,
    TerminalSession? session,
  }) async {
    if (source is SuppliedAnswer) {
      final error = _validate(source.value);
      return error == null ? Accepted(source.value) : Unavailable(error);
    }
    final scripted = source as ScriptedInput;
    final effectiveProfile = _effectiveOutputProfile(scripted, outputProfile);
    if (mode == PromptMode.rich && !effectiveProfile.supportsRichInteraction) {
      return Unavailable(
        'Rich interaction unavailable; declare cursor support and positive geometry, or use linear or automatic mode.',
      );
    }
    if (mode == PromptMode.automatic) {
      mode = effectiveProfile.supportsRichInteraction
          ? PromptMode.rich
          : PromptMode.linear;
    }
    final out = scripted.output;
    final width = _textInputWidth(effectiveProfile);
    final spine = _structureSpine(
      effectiveProfile,
      structure: structure,
      width: width,
      background: colors.background,
      border: colors.border,
    );
    void write(String text, TerminalColor foreground, {bool closes = false}) =>
        spine.write(out, text, foreground: foreground, closes: closes);
    spine.hint(
      out,
      '$label. Enter an absolute URL. Draft is hidden to avoid disclosing embedded credentials. Ctrl+T opens help. No network check is performed.',
      foreground: colors.foreground,
    );
    final inputKeys = keys ?? _Keys(scripted.input.transform(utf8.encoder));
    var value = '';
    try {
      while (true) {
        final edit = await _edit(
          inputKeys,
          value,
          out,
          sequential:
              mode != PromptMode.rich &&
              !effectiveProfile.supportsRichInteraction,
          secret: true,
          transientHelp:
              effectiveProfile.alternateScreen == CapabilitySupport.supported,
          transcript: scripted.transcript,
          outputProfile: effectiveProfile,
          structure: structure,
          resizeObserver: mode == PromptMode.rich
              ? scripted.resizeObserver
              : null,
          session: session,
          helpText: 'Help: Enter validates an absolute URL with an allowed scheme. Drafts are hidden; accepted output may describe the host interpretation but makes no availability or reachability claim.',
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
            write(
              'Host interpretation -- Unicode: ${idna.toUnicode(host)}; ASCII: ${idna.toAscii(host)}.',
              colors.success,
              closes: true,
            );
          }
          return Accepted(value);
        }
        write(error, colors.error, closes: true);
      }
    } finally {
      if (keys == null) await inputKeys.close();
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
  EmailInput(
    String label, {
    this.smtpUtf8 = false,
    String initialValue = '',
    this.instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    this.colors = ColorThemes.terminalDefault,
    this.structure = PromptStructure.plain,
  }) : supplementaryHelp = List.unmodifiable(supplementaryHelp) {
    if (initialValue.isNotEmpty && _validate(initialValue) != null) {
      throw ArgumentError('Invalid initial email address.');
    }
    _input = TextInput(
      '$label (bare SMTP address${smtpUtf8 ? '; SMTPUTF8 local part allowed' : '; ASCII local part'}).',
      initialValue: initialValue,
      required: true,
      validate: _validate,
      instructions: instructions,
      supplementaryHelp: [
        'Email format: one bare SMTP mailbox${smtpUtf8 ? '; SMTPUTF8 is required for Unicode local parts' : '; local parts must be ASCII'}. IDNA domains and address literals are accepted. Deliverability and transport availability are not checked.',
        ...supplementaryHelp,
      ],
      colors: colors,
      structure: structure,
    );
  }
  final bool smtpUtf8;
  final InstructionDisplay instructions;
  final List<String> supplementaryHelp;
  final ColorTheme colors;
  final PromptStructure structure;
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
    TerminalIo? terminal,
    OutputProfile? outputProfile,
    TerminalSession? session,
  }) async {
    final result = await _input.prompt(
      source: source,
      mode: mode,
      userPreference: userPreference,
      applicationPreference: applicationPreference,
      output: output,
      terminal: terminal,
      outputProfile: outputProfile,
      session: session,
    );
    if (result is Accepted<String> && source is! SuppliedAnswer) {
      final domain = result.value.substring(result.value.lastIndexOf('@') + 1);
      final sink = source is ScriptedInput
          ? source.output
          : session != null
          ? _SessionOutputSink(session)
          : output ?? terminal?.output ?? stderr;
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
