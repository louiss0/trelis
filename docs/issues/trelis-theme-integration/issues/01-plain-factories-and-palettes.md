# 01: Deliver PlainTheme factories and independent colour themes

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Create every existing component through PlainTheme with independent named or custom colours, using the accepted backend rather than introducing a second behavior implementation.

**Blocked by:**
- [33: Accept or block the backend evidence gate](../../trelis-backend-tracer-bullets/issues/33-backend-evidence-gate.md)

**Status:** ready-for-agent

- [ ] Expose all 38 typed static factories with preserved arguments/defaults/generics/concrete returns and applicable presentation configuration.
- [ ] Provide the 45 existing named palettes, complete immutable custom palettes/copyWith, whole-palette per-component replacement and terminal-native defaults.
- [ ] Exercise every applicable Plain component task/lifecycle in rich and linear output, not only supplied-answer validation.
- [ ] Verify palette mapping, warning fallback, page-colour exclusion, no global mutation and no forced surface/unsupported ANSI.
- [ ] Keep construction output-free and session/profile configuration on invocation; document usable public examples.
- [ ] Begin only after both the new backend verdict and retained compatibility gate actually report accepted evidence.

- [ ] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.
