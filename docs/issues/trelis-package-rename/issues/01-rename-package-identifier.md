# 01: Rename package identifier, entry point and imports

**Parent:** [Trelis package rename and release migration](../spec.md)

**What to build:** Change the package identity from `prompty` to `trelis` and
every `package:prompty/...` import to `package:trelis/...`, keeping the entire
library compiling and the full test suite green.

**Blocked by:** —

**Status:** resolved

- [x] `pubspec.yaml`: `name: trelis`.
- [x] `lib/prompty.dart` renamed to `lib/trelis.dart`.
- [x] Every `package:prompty/...` import (in `lib/`, `test/`, `example/`,
      `tool/`, `bin/`) rewritten to `package:trelis/...`.
- [x] No `package:prompty` import remains anywhere in the repository.
- [x] `dart pub get` succeeds against the new package name and the analysis/test
      run uses the renamed entry point.

- [x] Record actual verification: source revision, commands run and results; do
      not treat the edit itself as a pass.

## Comments

**Claim.** Claimed on `integration/trelis-package-rename` from base
`c947a37`. The rename is atomic at the package level, so this ticket changes
the pubspec name, the entry point and every `package:prompty` import together.

**Verification.** `dart pub get` → Got dependencies. `dart analyze` → No issues
found. `dart test` → +4795, all passed. `dart run tool/check_issue_tracker.dart`
→ clean. `dart run tool/check_doc_links.dart` → 0 broken links. No
`package:prompty` import remains in any `.dart` file.

**Answer.** Commit `be273af` (`refactor(rename)!: rename package from prompty
to trelis`) renames the pubspec name, the entry point (`lib/prompty.dart` →
`lib/trelis.dart`) and 171 import sites, and fixes the barrel-inventory test to
read the renamed entry point. The full suite passes. Ticket 02 now owns the
remaining textual `prompty` references in documentation, examples and archived
prototypes, which are not live imports.
