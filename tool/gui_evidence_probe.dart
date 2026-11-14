import 'dart:async';

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

/// Exercises the public session seam used by the visible Windows GUI probe.
///
/// The probe deliberately returns only outcome metadata: its synthetic password
/// canary is never included in output, transcript text, or diagnostics.
Future<String> runGuiEvidenceProbe({
  ScriptedInput? source,
  OutputProfile? outputProfile,
  bool includeSecret = true,
}) async {
  return TerminalSession.run(
    (session) async {
      Text(
        'Agent GUI probe: informational write while the editor is active.',
        kind: TextKind.warning,
      ).present(session: session);
      final progress = Progress('Indexing visible GUI evidence', total: 2)
        ..start(session: session)
        ..update(1);
      final spinner = Spinner('Background activity')
        ..start(session: session)
        ..update('waiting while help is open');
      var tick = 0;
      final updates = Timer.periodic(const Duration(milliseconds: 350), (_) {
        spinner.update('background update ${++tick}');
      });
      try {
        final text = await TextInput(
          'Project',
          initialValue: 'alpha',
          supplementaryHelp: const [
            'This is an agent-operated synthetic-input probe, not a human usability claim.',
          ],
        ).prompt(session: session);
        if (text is! Accepted<String>) return _outcome(text);
        progress.update(2);
        if (!includeSecret) return 'accepted:${text.value}';

        final secret = await Password('Synthetic canary')
            .prompt(session: session);
        return switch (secret) {
          Accepted<String>() => 'accepted:${text.value};secret:accepted',
          _ => _outcome(secret),
        };
      } finally {
        updates.cancel();
        progress.finish(FeedbackOutcome.completed);
        spinner.finish(FeedbackOutcome.completed);
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

Future<void> main(List<String> args) async {
  final result = await runGuiEvidenceProbe(
    includeSecret: !args.contains('--no-secret'),
    outputProfile: args.contains('--ascii') ? asciiOutputProfile : null,
  );
  // Do not print the accepted password: only the outcome is evidence.
  print('GUI-PROBE:$result');
}
