# Gated structural-theme ticket order

These seven approved vertical slices implement the unchanged [theme handoff](spec.md) and [parent specification](../trelis-theming/spec.md). Triage readiness does not bypass backend acceptance.

| Ticket | Blocked by |
|---|---|
| [01: Deliver PlainTheme factories and independent colour themes](issues/01-plain-factories-and-palettes.md) | [Accept or block the backend evidence gate](../trelis-backend-tracer-bullets/issues/33-backend-evidence-gate.md) |
| [02: Deliver RailTheme and BranchTheme](issues/02-rail-and-branch.md) | [Deliver PlainTheme factories and independent colour themes](issues/01-plain-factories-and-palettes.md) |
| [03: Deliver BoxTheme, RoundTheme and DoubleTheme](issues/03-enclosure-themes.md) | [Deliver PlainTheme factories and independent colour themes](issues/01-plain-factories-and-palettes.md) |
| [04: Deliver MinimalTheme, AsciiTheme, ChevronTheme and BracketTheme](issues/04-lightweight-heading-themes.md) | [Deliver PlainTheme factories and independent colour themes](issues/01-plain-factories-and-palettes.md) |
| [05: Deliver FormTheme, LedgerTheme and ColonTheme](issues/05-form-ledger-colon.md) | [Deliver PlainTheme factories and independent colour themes](issues/01-plain-factories-and-palettes.md) |
| [06: Deliver LineTheme and BlockTheme](issues/06-line-and-block.md) | [Deliver PlainTheme factories and independent colour themes](issues/01-plain-factories-and-palettes.md) |
| [07: Verify the full theme matrix and publish migration guidance](issues/07-theme-matrix-and-migration.md) | [Deliver RailTheme and BranchTheme](issues/02-rail-and-branch.md); [Deliver BoxTheme, RoundTheme and DoubleTheme](issues/03-enclosure-themes.md); [Deliver MinimalTheme, AsciiTheme, ChevronTheme and BracketTheme](issues/04-lightweight-heading-themes.md); [Deliver FormTheme, LedgerTheme and ColonTheme](issues/05-form-ledger-colon.md); [Deliver LineTheme and BlockTheme](issues/06-line-and-block.md) |

Every theme slice includes typed factories, applicable public component tasks, rich/linear presentation, component help, protected-content behavior, responsive/capability fallback, tests and usage guidance. They are not isolated palette/layout/API layers. The final ticket verifies the full cross-product and migration evidence.

No theme ticket is initially takeable. The backend evidence gate must actually pass, with its accepted verdict mirrored to the retained compatibility gate referred to by the unchanged parent handoff. No test or acceptance pass is claimed by creating these files.
