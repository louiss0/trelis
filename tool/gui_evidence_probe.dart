import 'dart:async';
import 'dart:io';

import 'package:prompty/prompty.dart';

/// Explicit ASCII/no-colour profile for the visible fallback scenario.
final asciiOutputProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  alternateScreen: CapabilitySupport.unsupported,
  styles: CapabilitySupport.unsupported,
  colorDepth: ColorDepth.none,
  glyphs: GlyphSet.ascii,
  geometry: OutputGeometry.fixed(columns: 40, rows: 8),
);

/// The visible terminal's own geometry with styling, still without an
/// alternate screen so the transcript fallback path is what gets exercised.
OutputProfile visibleTerminalProfile() => OutputProfile(
  cursor: CapabilitySupport.supported,
  alternateScreen: CapabilitySupport.unsupported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.none,
  glyphs: GlyphSet.ascii,
  geometry: OutputGeometry.fixed(
    columns: stderr.terminalColumns,
    rows: stderr.terminalLines,
  ),
);

/// The completed progress count the probe reports before it finishes.
const guiProbeProgressTotal = 3;

/// Concurrent feedback a visible probe keeps live while the editor owns input.
///
/// The session owns the regions; the caller decides when a pulse happens. A
/// scripted harness therefore drives the same interleaving the visible probe
/// shows without racing a wall clock, and every run produces the same
/// transcript.
final class GuiEvidenceProbe {
  GuiEvidenceProbe._(this._session, this._progress, this._spinner);

  final TerminalSession _session;
  final Progress _progress;
  final Spinner _spinner;
  int _pulses = 0;

  /// How many pulses have been emitted.
  int get pulses => _pulses;

  /// Reports one round of concurrent feedback.
  ///
  /// An informational [Text] block, a [Spinner] update, and a [Progress]
  /// advance arrive as separate regions, so the editor has to keep the draft
  /// and caret truthful while three writers repaint around it.
  void pulse() {
    _pulses++;
    Text(
      'Concurrent informational write #$_pulses',
      kind: TextKind.ordinary,
    ).present(session: _session);
    _spinner.update('background update $_pulses');
    _progress.update(_pulses.clamp(1, guiProbeProgressTotal));
  }

  /// Retires both live regions with a completed outcome.
  void finish() {
    _progress.finish(FeedbackOutcome.completed);
    _spinner.finish(FeedbackOutcome.completed);
  }
}

/// Exercises the public session seam used by the visible Windows GUI probe.
///
/// Concurrent feedback arrives from [pulses] when a harness supplies one, and
/// from a [pulseInterval] timer otherwise, so the visible probe keeps reporting
/// while an agent drives synthetic keys.
///
/// [repeats] opens that many sequential prompts inside one session, which is
/// the repeated-prompt checkpoint. [requireValue] opens the draft empty and
/// declares the value required, so an immediate submit is rejected once and the
/// prompt returns for a successful second submission; that is a genuine
/// validation error rather than an optional empty answer.
///
/// The probe deliberately returns only outcome metadata: its synthetic password
/// canary is never included in output, transcript text, or diagnostics.
Future<String> runGuiEvidenceProbe({
  ScriptedInput? source,
  OutputProfile? outputProfile,
  bool includeSecret = true,
  int repeats = 1,
  bool requireValue = false,
  Stream<void>? pulses,
  Duration pulseInterval = const Duration(milliseconds: 350),
}) async {
  if (repeats < 1) {
    throw ArgumentError.value(repeats, 'repeats', 'must be positive');
  }
  return TerminalSession.run(
    (session) async {
      Text(
        'Agent GUI probe: informational write while the editor is active.',
        kind: TextKind.warning,
      ).present(session: session);
      final progress = Progress(
        'Indexing visible GUI evidence',
        total: guiProbeProgressTotal,
      )..start(session: session);
      final spinner = Spinner('Background activity')
        ..start(session: session)
        ..update('waiting while help is open');
      final probe = GuiEvidenceProbe._(session, progress, spinner);
      StreamSubscription<void>? subscription;
      Timer? timer;
      if (pulses == null) {
        timer = Timer.periodic(pulseInterval, (_) => probe.pulse());
      } else {
        subscription = pulses.listen((_) => probe.pulse());
      }
      try {
        final accepted = <String>[];
        for (var attempt = 0; attempt != repeats; attempt++) {
          final text = await TextInput(
            'Project',
            initialValue: requireValue ? '' : 'alpha',
            required: requireValue,
            supplementaryHelp: const [
              'This is an agent-operated synthetic-input probe,',
              'not a human usability or accessibility claim.',
            ],
          ).prompt(session: session);
          if (text is! Accepted<String>) return _outcome(text);
          accepted.add(text.value);
        }
        progress.update(guiProbeProgressTotal);
        if (!includeSecret) return 'accepted:${accepted.join(',')}';

        final secret = await Password('Synthetic canary')
            .prompt(session: session);
        return switch (secret) {
          Accepted<String>() =>
            'accepted:${accepted.join(',')};secret:accepted',
          _ => _outcome(secret),
        };
      } finally {
        await subscription?.cancel();
        timer?.cancel();
        probe.finish();
      }
    },
    source: source,
    outputProfile: outputProfile,
  );
}

String _outcome(PromptResult<String> result) => switch (result) {
  Cancelled<String>() => 'cancel',
  Interrupted<String>() => 'interrupt',
  InputEnded<String>() => 'eof',
  Unavailable<String>() => 'unavailable',
  Accepted<String>(:final value) => 'accepted:$value',
};

/// Reads `--name=value` as a positive integer, or null when absent.
int? _intArgument(List<String> args, String name) {
  final prefix = '$name=';
  for (final arg in args) {
    if (!arg.startsWith(prefix)) continue;
    final value = int.tryParse(arg.substring(prefix.length));
    if (value == null || value < 1) {
      throw ArgumentError.value(arg, name, 'must be a positive integer');
    }
    return value;
  }
  return null;
}

/// Runs the probe in the current terminal.
///
/// `--ascii` selects the fixed 40x8 no-colour ASCII profile, `--no-secret`
/// stops after the text prompts, `--repeats=N` opens N sequential prompts, and
/// `--require-value` opens an empty draft whose required value is rejected
/// until a real one is submitted.
Future<void> main(List<String> args) async {
  final result = await runGuiEvidenceProbe(
    includeSecret: !args.contains('--no-secret'),
    repeats: _intArgument(args, '--repeats') ?? 1,
    requireValue: args.contains('--require-value'),
    outputProfile: args.contains('--ascii')
        ? asciiOutputProfile
        : visibleTerminalProfile(),
  );
  // Do not print the accepted password: only the outcome is evidence.
  print('GUI-PROBE:$result');
}
