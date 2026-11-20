// Manual macOS fixture for the ticket 36 VoiceOver binding.
//
// On a Mac, run with VoiceOver off and on and record both observations. The
// fixture-only `enabled` override does not enable the production rollout gate.
// It prints a VoiceOver-specific observation, not proof of screen-reader use.
import 'dart:io';

import 'package:trelis/src/hint_observations.dart';
import 'package:trelis/src/macos_voiceover_hint.dart';

Future<void> main() async {
  if (!Platform.isMacOS) {
    stderr.writeln(
      'VoiceOver fixture requires macOS; found ${Platform.operatingSystem}',
    );
    exitCode = 2;
    return;
  }

  final observation = await macosVoiceOverReaderProbe(enabled: true)(
    HintPlatform.macos,
  );
  stdout.writeln('NSWorkspace.isVoiceOverEnabled observation: $observation');
}
