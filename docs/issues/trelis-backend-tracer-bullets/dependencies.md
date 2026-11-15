# Approved backend tracer-bullet execution order

This is the active **33-ticket** backend backlog. It supersedes the unstarted layered plan; it does not amend or close the [parent specification](../trelis-theming/spec.md). The earlier acceptance requirements remain binding through the [backend requirements specification](../trelis-backend-implementation/spec.md).

Each ticket contains a complete observable slice and its actual blockers. Status ready-for-agent is triage readiness, not permission to ignore blockers. Work only an unclaimed ticket whose blockers are resolved with evidence.

| Ticket | Blocked by |
|---|---|
| [01: Capture the regression baseline and deterministic harness](issues/01-baseline-and-harness.md) | None |
| [02: Expand the shared terminal I/O seam without changing behavior](issues/02-expand-terminal-io-seam.md) | [Capture the regression baseline and deterministic harness](issues/01-baseline-and-harness.md) |
| [03: Support explicit output profiles in scripted TextInput](issues/03-scripted-text-input-profiles.md) | [Expand the shared terminal I/O seam without changing behavior](issues/02-expand-terminal-io-seam.md) |
| [04: Resolve native TextInput capabilities and restore terminal state](issues/04-native-text-input-capabilities.md) | [Support explicit output profiles in scripted TextInput](issues/03-scripted-text-input-profiles.md) |
| [05: Render TextInput from safe typed presentation content](issues/05-safe-typed-text-input.md) | [Support explicit output profiles in scripted TextInput](issues/03-scripted-text-input-profiles.md) |
| [06: Map Unicode TextInput drafts to display cells and caret positions](issues/06-unicode-text-input-mapping.md) | [Render TextInput from safe typed presentation content](issues/05-safe-typed-text-input.md) |
| [07: Keep the TextInput caret usable in narrow viewports](issues/07-narrow-text-input-viewport.md) | [Map Unicode TextInput drafts to display cells and caret positions](issues/06-unicode-text-input-mapping.md) |
| [08: Reflow an idle TextInput without losing state](issues/08-idle-text-input-resize.md) | [Keep the TextInput caret usable in narrow viewports](issues/07-narrow-text-input-viewport.md); [Resolve native TextInput capabilities and restore terminal state](issues/04-native-text-input-capabilities.md) |
| [09: Apply capability-aware colours to TextInput](issues/09-text-input-colour-rendering.md) | [Render TextInput from safe typed presentation content](issues/05-safe-typed-text-input.md); [Resolve native TextInput capabilities and restore terminal state](issues/04-native-text-input-capabilities.md) |
| [10: Emit meaningful linear TextInput history](issues/10-linear-text-input-events.md) | [Render TextInput from safe typed presentation content](issues/05-safe-typed-text-input.md) |
| [11: Provide compact and full TextInput help safely](issues/11-text-input-help.md) | [Keep the TextInput caret usable in narrow viewports](issues/07-narrow-text-input-viewport.md) |
| [12: Run sequential TextInput prompts in an explicit scoped session](issues/12-scoped-sequential-text-input.md) | [Emit meaningful linear TextInput history](issues/10-linear-text-input-events.md); [Resolve native TextInput capabilities and restore terminal state](issues/04-native-text-input-capabilities.md) |
| [13: Run a prompt alongside one Spinner and coordinated Text messages](issues/13-prompt-live-status.md) | [Run sequential TextInput prompts in an explicit scoped session](issues/12-scoped-sequential-text-input.md); [Reflow an idle TextInput without losing state](issues/08-idle-text-input-resize.md); [Provide compact and full TextInput help safely](issues/11-text-input-help.md); [Apply capability-aware colours to TextInput](issues/09-text-input-colour-rendering.md) |
| [14: Support multiple feedback regions with correct lifecycles](issues/14-multiple-feedback-lifecycles.md) | [Run a prompt alongside one Spinner and coordinated Text messages](issues/13-prompt-live-status.md) |
| [15: Make help modal while background work keeps updating](issues/15-modal-help-live-jobs.md) | [Support multiple feedback regions with correct lifecycles](issues/14-multiple-feedback-lifecycles.md) |
| [16: Preserve the prompt and important notices on short screens](issues/16-short-screen-overflow.md) | [Support multiple feedback regions with correct lifecycles](issues/14-multiple-feedback-lifecycles.md) |
| [17: Isolate region faults and recover safely from session failures](issues/17-session-failure-recovery.md) | [Make help modal while background work keeps updating](issues/15-modal-help-live-jobs.md); [Preserve the prompt and important notices on short screens](issues/16-short-screen-overflow.md) |
| [18: Migrate Password and URLInput without private-state leakage](issues/18-private-entry-migration.md) | [Run a prompt alongside one Spinner and coordinated Text messages](issues/13-prompt-live-status.md) |
| [19: Migrate Confirm, Checkbox and Toggle](issues/19-boolean-migration.md) | [Run a prompt alongside one Spinner and coordinated Text messages](issues/13-prompt-live-status.md) |
| [20: Migrate Multiline and TagInput](issues/20-multiline-tag-migration.md) | [Run a prompt alongside one Spinner and coordinated Text messages](issues/13-prompt-live-status.md) |
| [21: Migrate Select, Radio and MultiSelect](issues/21-selection-migration.md) | [Run a prompt alongside one Spinner and coordinated Text messages](issues/13-prompt-live-status.md) |
| [22: Migrate TreeSelect and SortableSelect](issues/22-tree-order-migration.md) | [Migrate Select, Radio and MultiSelect](issues/21-selection-migration.md) |
| [23: Migrate asynchronous suggestions and search](issues/23-async-search-migration.md) | [Migrate Select, Radio and MultiSelect](issues/21-selection-migration.md) |
| [24: Migrate formatted-value inputs](issues/24-formatted-values-migration.md) | [Run a prompt alongside one Spinner and coordinated Text messages](issues/13-prompt-live-status.md) |
| [25: Migrate DateInput and TimeInput](issues/25-date-time-migration.md) | [Run a prompt alongside one Spinner and coordinated Text messages](issues/13-prompt-live-status.md) |
| [26: Migrate sliders, ranges and MaskedInput](issues/26-range-mask-migration.md) | [Run a prompt alongside one Spinner and coordinated Text messages](issues/13-prompt-live-status.md) |
| [27: Migrate path entry and filesystem browsing](issues/27-filesystem-migration.md) | [Migrate Select, Radio and MultiSelect](issues/21-selection-migration.md) |
| [28: Migrate CronInput entry, preview and review](issues/28-cron-workflow-migration.md) | [Run a prompt alongside one Spinner and coordinated Text messages](issues/13-prompt-live-status.md) |
| [29: Migrate Keypress and KeyChordInput](issues/29-key-capture-migration.md) | [Run a prompt alongside one Spinner and coordinated Text messages](issues/13-prompt-live-status.md) |
| [30: Complete compatibility checks and retire migrated legacy paths](issues/30-compatibility-and-contract.md) | [Isolate region faults and recover safely from session failures](issues/17-session-failure-recovery.md); [Migrate Password and URLInput without private-state leakage](issues/18-private-entry-migration.md); [Migrate Confirm, Checkbox and Toggle](issues/19-boolean-migration.md); [Migrate Multiline and TagInput](issues/20-multiline-tag-migration.md); [Migrate TreeSelect and SortableSelect](issues/22-tree-order-migration.md); [Migrate asynchronous suggestions and search](issues/23-async-search-migration.md); [Migrate formatted-value inputs](issues/24-formatted-values-migration.md); [Migrate DateInput and TimeInput](issues/25-date-time-migration.md); [Migrate sliders, ranges and MaskedInput](issues/26-range-mask-migration.md); [Migrate path entry and filesystem browsing](issues/27-filesystem-migration.md); [Migrate CronInput entry, preview and review](issues/28-cron-workflow-migration.md); [Migrate Keypress and KeyChordInput](issues/29-key-capture-migration.md) |
| [31: Execute the cross-platform automated and native matrix](issues/31-platform-ci-native-evidence.md) | [Complete compatibility checks and retire migrated legacy paths](issues/30-compatibility-and-contract.md) |
| [32: Exercise the backend through agent-operated Windows computer use](issues/32-agent-windows-gui-evidence.md) | [Complete compatibility checks and retire migrated legacy paths](issues/30-compatibility-and-contract.md) |
| [33: Accept or block the backend evidence gate](issues/33-backend-evidence-gate.md) | [Execute the cross-platform automated and native matrix](issues/31-platform-ci-native-evidence.md); [Exercise the backend through agent-operated Windows computer use](issues/32-agent-windows-gui-evidence.md) |

## Frontier and gates

Only [01: Capture the regression baseline and deterministic harness](issues/01-baseline-and-harness.md) can start initially. Claim the chosen ticket before implementation. Expand beside the legacy form, migrate in independently verifiable slices, then retire old paths only after all callers move. Coordinate shared-file edits even where dependencies permit parallel work.

[33: Accept or block the backend evidence gate](issues/33-backend-evidence-gate.md) requires platform and agent-GUI evidence before any theme ticket can start. It must mirror an actually accepted verdict to the [retained compatibility gate](../trelis-backend-implementation/issues/16-backend-evidence-gate.md) before resolution, preserving existing parent links without falsely passing the gate during re-ticketing.

Linux/macOS checks are CI-only; Windows also has an agent-operated visible-terminal probe. No human checkpoint is added. The [theme ticket index](../trelis-theme-integration/dependencies.md) lists the gated next phase.
