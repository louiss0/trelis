# Publish dry-run evidence — trelis 1.0.0-dev.1

**Status:** evidence only — not authorization to publish
**Command:** `dart pub publish --dry-run`
**Date:** 2026-11-25 (UTC)
**Commit:** `b26eddb` on `release-readiness/08-prerelease-docs`
**Full captured output:** [publish-dry-run-output.txt](publish-dry-run-output.txt)

## Result

`dart pub publish --dry-run` resolves dependencies, archives the package as
`trelis 1.0.0-dev.1` (total compressed archive size 2 MB) and completes
validation with **2 warnings and no errors**. The process exit code is 65:
`dart pub publish` treats validation warnings as a non-zero validation
result even in dry-run mode. Both warnings are accepted project tradeoffs,
documented below; neither is a defect in the package contents.

## Accepted warning 1: exact `termunicode` constraint

```text
* Your dependency on "termunicode" should allow more than one version. For example:

  dependencies:
    termunicode: ^0.2.0

  Constraints that are too tight will make it difficult for people to use your package
  along with other packages that also depend on "termunicode".
```

This warning is an **accepted tradeoff of the Unicode-data policy**.
`pubspec.yaml` pins `termunicode` exactly at `0.2.0` (Unicode 16 table basis)
behind a Trelis-owned measurement adapter, a decision recorded in the
theming/backend tracker history (`docs/issues/trelis-theming/spec.md`).
Grapheme, width and property measurement must not shift silently beneath an
application because a transitive constraint allowed a newer Unicode table;
the dry run itself observes `termunicode 0.2.0 (0.3.0 available)`. The pin is
intentional and must not be loosened without a new Unicode-data policy
decision. The interoperability cost the warning describes is real and is the
price of that policy.

## Accepted warning 2: `docs` directory name

```text
* Rename the top-level "docs" directory to "doc".
  The Pub layout convention is to use singular directory names.
  Plural names won't be correctly identified by Pub and other tools.
  See https://dart.dev/tools/pub/package-layout.
```

This warning is an **accepted project-structure tradeoff**. The repository
uses a single-context domain documentation layout with a Git-backed issue
tracker under `docs/` (`docs/agents/domain.md`,
`docs/agents/issue-tracker.md`, `docs/issues/`). That layout is intentional
project structure; the release-readiness spec explicitly forbids reorganizing
the documentation or the tracker to silence the packaging-convention warning.

## Scope of the evidence

This dry run is evidence that the package archives and validates with only
the two accepted warnings. It is **not** authorization to publish, and no
stable release is implied: the independent interaction and colour release
gates remain open `ready-for-human` work, so no stable API, accessibility
qualification, screen-reader usability or real-terminal colour-quality claim
is attached to this evidence. A first dry run during the documentation work
additionally reported a transient "checked-in files are modified in git"
warning because the documentation edits were not yet committed; the recorded
final run above was taken from a clean committed tree and does not show it.
