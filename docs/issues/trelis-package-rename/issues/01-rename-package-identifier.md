# 01: Rename package identifier, entry point and imports

**Parent:** [Trelis package rename and release migration](../spec.md)

**What to build:** Change the package identity from `prompty` to `trelis` and
every `package:prompty/...` import to `package:trelis/...`, keeping the entire
library compiling and the full test suite green.

**Blocked by:** —

**Status:** ready-for-agent

- [ ] `pubspec.yaml`: `name: trelis`.
- [ ] `lib/prompty.dart` renamed to `lib/trelis.dart`.
- [ ] Every `package:prompty/...` import (in `lib/`, `test/`, `example/`,
      `tool/`, `bin/`) rewritten to `package:trelis/...`.
- [ ] No `package:prompty` import remains anywhere in the repository.
- [ ] `dart pub get` succeeds against the new package name and the analysis/test
      run uses the renamed entry point.

- [ ] Record actual verification: source revision, commands run and results; do
      not treat the edit itself as a pass.

## Comments
