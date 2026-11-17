# 01: Rename package identifier, entry point and imports

**Parent:** [Trelis package rename and release migration](../spec.md)

**What to build:** Change the package identity from `prompty` to `trelis` and
every `package:prompty/...` import to `package:trelis/...`, keeping the entire
library compiling and the full test suite green.

**Blocked by:** —

**Status:** claimed

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

**Claim.** Claimed on `integration/trelis-package-rename` from base
`c947a37`. The rename is atomic at the package level, so this ticket changes
the pubspec name, the entry point and every `package:prompty` import together.
