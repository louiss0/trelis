import 'dart:io';

/// Verifies that the repository uses one Git-backed Markdown issue tracker.
///
/// The tracker lives under `docs/issues/`. The former hidden tracker directory
/// must not exist, no tracked file may still reference it, and every tracker
/// file present in the working tree must be known to Git.
Future<void> main() async {
  final root = File.fromUri(Platform.script).parent.parent;
  final tracker = Directory.fromUri(root.uri.resolve('docs/issues/'));
  final legacyName = '.${'scratch'}';
  final failures = <String>[];

  if (!tracker.existsSync()) {
    failures.add('Missing Git-backed tracker directory: docs/issues/');
  }

  final legacy = Directory.fromUri(root.uri.resolve('$legacyName/'));
  if (legacy.existsSync()) {
    failures.add('Legacy local tracker directory still exists: $legacyName/');
  }

  final trackedLegacy = await _git(root, ['ls-files', '--', legacyName]);
  if (trackedLegacy.isNotEmpty) {
    failures.add('Legacy tracker files are still tracked:\n$trackedLegacy');
  }

  final untrackedTracker = await _git(root, [
    'ls-files',
    '--others',
    '--exclude-standard',
    '--',
    'docs/issues',
  ]);
  if (untrackedTracker.isNotEmpty) {
    failures.add('Tracker files are not tracked by Git:\n$untrackedTracker');
  }

  final legacyReferences = await _git(
    root,
    [
      'grep',
      '-n',
      '-F',
      legacyName,
      '--',
      '.',
      ':(exclude).gitignore',
      ':(exclude)tool/check_issue_tracker.dart',
    ],
    allowedExitCodes: const {0, 1},
  );
  if (legacyReferences.isNotEmpty) {
    failures.add(
      'Tracked files still reference $legacyName:\n$legacyReferences',
    );
  }

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln('TRACKER ERROR: $failure');
    }
    exitCode = 1;
    return;
  }

  final tracked = await _git(root, ['ls-files', '--', 'docs/issues']);
  final count = tracked.isEmpty ? 0 : tracked.split('\n').length;
  stdout.writeln(
    'Checked $count Git-backed tracker files; no legacy local tracker remains.',
  );
}

Future<String> _git(
  Directory root,
  List<String> arguments, {
  Set<int> allowedExitCodes = const {0},
}) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: root.path,
    runInShell: Platform.isWindows,
  );
  if (!allowedExitCodes.contains(result.exitCode)) {
    throw ProcessException(
      'git',
      arguments,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
  return (result.stdout as String).trim();
}
