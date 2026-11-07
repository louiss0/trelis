import 'dart:io';

/// Checks that every relative Markdown link in the repository resolves.
///
/// Run with `dart run tool/check_doc_links.dart`. Absolute URLs, empty
/// fragments and mail links are ignored. Exits 1 and lists the broken links when
/// any target is missing.
void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final documents = <File>[];
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.md')) continue;
    final relative = _relative(root, entity);
    final segments = relative.split(Platform.pathSeparator);
    if (segments.any((segment) => segment.startsWith('.'))) continue;
    documents.add(entity);
  }
  documents.sort((a, b) => a.path.compareTo(b.path));

  final link = RegExp(r'\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)');
  final broken = <String>[];
  var checked = 0;
  for (final document in documents) {
    for (final match in link.allMatches(document.readAsStringSync())) {
      final target = match.group(1)!;
      if (target.startsWith('http://') ||
          target.startsWith('https://') ||
          target.startsWith('#') ||
          target.startsWith('mailto:')) {
        continue;
      }
      final relative = target.split('#').first;
      if (relative.isEmpty) continue;
      checked++;
      final path = File(
        '${document.parent.path}${Platform.pathSeparator}'
        '${relative.replaceAll('/', Platform.pathSeparator)}',
      ).path;
      if (!File(path).existsSync() && !Directory(path).existsSync()) {
        broken.add('${_relative(root, document)} -> $target');
      }
    }
  }

  stdout.writeln(
    'Checked $checked relative links in ${documents.length} Markdown files.',
  );
  for (final item in broken) {
    stdout.writeln('BROKEN $item');
  }
  if (broken.isNotEmpty) exitCode = 1;
}

String _relative(Directory root, File file) {
  final prefix = root.path.endsWith(Platform.pathSeparator)
      ? root.path
      : '${root.path}${Platform.pathSeparator}';
  return file.path.startsWith(prefix)
      ? file.path.substring(prefix.length)
      : file.path;
}
