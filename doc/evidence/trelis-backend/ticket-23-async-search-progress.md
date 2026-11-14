# Ticket 23: async search migration — progress, not acceptance

> Superseded by [23-async-search-migration.md](23-async-search-migration.md),
> which records the completed migration and its executed verification. This note
> is kept as the pre-merge progress record.

Environment: Windows x64, Dart SDK 3.13.2, 2026-11-13. Base revision: `74c5171bdd794b69262558130aa64195b68ec57b` (contains `10de1bc`). The evidence applies to the code committed with this report, before any later merge or edits. Synthetic scripted input and output profiles were used; this is not native terminal, cross-platform CI, or accessibility evidence.

- `dart analyze`: `No issues found!`.
- `dart test -r expanded`: `+837: All tests passed!`. An earlier run had one failure in the invalid-identity retry message; that regression was fixed and the full suite rerun.
- Targeted red/green public-interface tests cover session input reuse, wrapper forwarding, help and concurrent feedback, late suggestions/search results while help is open, invalid identities, display-safe bidi text, no-geometry rich rejection, and same-instance overlap. Some asynchronous tests use timed delays rather than fully controlled scheduling.

This is **not ticket acceptance**. The implementation still needs a complete audit and migration to the specified typed query/results projection and meaningful event contract, complete component/stage help and instruction-policy coverage, deterministic async/lifecycle and selected-output fault fixtures, and native/selected-output safety verification. No acceptance criteria or backend evidence gate are marked passed by this report.
