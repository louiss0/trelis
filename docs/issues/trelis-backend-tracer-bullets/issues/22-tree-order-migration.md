# 22: Migrate TreeSelect and SortableSelect

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Traverse selectable trees and reorder movable items using the shared choice presentation without altering identity or constraints.

**Blocked by:**
- [21: Migrate Select, Radio and MultiSelect](21-selection-migration.md)

**Status:** resolved

**Acceptance reference:** [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-EVENT](../../trelis-backend-implementation/spec.md#b-event).

- [x] Preserve expansion versus selectability, current path/context and stable-reference selection workflows.
- [x] Retain locked anchors, pick-up/drop/move, revert versus cancellation and final submission rules.
- [x] Use typed tree/order extensions while preserving focus and caret/viewport ownership.
- [x] Provide complete component help and relevant state/reasons in rich and linear interactions.
- [x] Exercise actual public tasks with background updates, incomplete actions and all outcome paths.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Comments

Implemented on `ticket/backend-22-tree-order-migration` in commits `d956cd7`
(behaviour-preserving move of both families into `lib/src/tree_order.dart`),
`07c4205` (shared output-profile, terminal and session migration), `fb2eeff`
(typed shared rows), `104fe9c` (stage-led help), `0b5697f` (background repaint),
`f4b943b` (idle resize), `4100722` (colour, outcome and failure coverage),
`99c6fa6` (README) and `b4c2676` (evidence). Branch based on integration
`74c5171`; `git merge integration/trelis-backend-tracer-bullets` reported `Already
up to date.` before the report, so the integration tip had not moved.

**Merge evidence:** merged `ticket/backend-22-tree-order-migration` (`b4c2676`)
into `integration/trelis-backend-tracer-bullets` (`091164f`) with
`git merge --no-ff` as `0c219fa`. Merge base was `74c5171`, so the integration
side already carried the newer filesystem (`8e54b8c`) and native prompt-reader
(`bda95ce`) work. Both sides touched `lib/src/text_input.dart` and `README.md`;
git's `ort` strategy auto-merged them with no textual conflicts. Resolved by
content: the integration-side `TerminalSession` reader ownership (`_keysInput`,
`_readerFor`, `_promptOnNativeConsole`, `_Keys._closed`) and the native
console/writer changes are all present, the ticket's `Choice`/`_ChoiceRow`
extensions and `part 'tree_order.dart';` are present, `part
'sortable_select.dart';` is gone with no remaining Dart reference to the deleted
file, and the `TreeSelect`/`TreeNode`/`SortableSelect` classes exist only in
`lib/src/tree_order.dart`. README keeps both the ticket's tree/order paragraphs
and the integration-side text. Validated in this worktree: `dart analyze` clean,
tree/order suites 42 tests passed, component acceptance matrix 144 passed,
session/feedback/failure/short-screen/idle-resize suites 32 passed, doc links
passed (153 links in 56 files), and changed-file formatting clean. The
filesystem/path batch ran 57 tests with 2 failures — `filesystem_migration`
`PathInput stage help` and `path_input_behavior` `rich entry preserves invalid
draft` — which are the same two path-length-dependent wrap assertions already
recorded as an open follow-up on ticket 27; they fail identically at the
integration parent `091164f` in this worktree, so the merge introduced no
regression. Full suite: 859 passed, the same 2 failed (parent baseline: 837
passed, the same 2 failed). The repository-wide format check still reports only
the three pre-existing unformatted test files, none of them touched here.

## Answer

`TreeSelect` and `SortableSelect` now compose their rows through one typed
presentation: the shared `_ChoiceRow` gained tree facts (path, expansion state,
selectability, children-unavailable reason, staleness) and order facts (position
of count, locked reason, pick-up), so expansion never implies selectability, a
locked anchor keeps its displayed reference and position, and every marker is an
atomic unit that a narrow declared width wraps around instead of splitting.
Combined with the shared `TerminalIo`/`OutputProfile`/`TerminalSession` seam,
both prompts accept `terminal`, `outputProfile`, `session` and an optional
`ColorTheme`, inherit session input/output/mode/profile (rejecting competing
invocation configuration), refuse an explicitly requested rich mode the effective
profile cannot support, fall back to linear for `automatic`, and honour
`NO_COLOR`. Rich mode paints transcript rows and notices only — no cursor,
erase-line or alternate-screen sequence — so the shared editor keeps caret and
viewport ownership; linear editing stays in the shared segmented editor.

Component help is complete for the current stage: `Help: Navigating the tree`,
`Help: Choosing a node`, `Help: Entering a node reference`,
`Help: Ordering the list`, `Help: Moving <label>`, `Help: Entering a
reference` and `Help: Entering a destination position` each keep the current
path, the displayed default, the preorder/stable-reference rule, the
revert-versus-cancel rule and every non-acceptable node or locked anchor with its
protected reason; linear `/help` keeps the component text and appends the exact
command spellings. A live `Spinner` inside one `TerminalSession.run` scope
repaints the retained focus, expansion and picked-up identity, an idle resize
repaints and re-wraps without editing or accepting (and is suppressed while help
owns the screen), the observer subscription and any terminal lease are released
on every supported exit, a failed shared writer surfaces the original failure and
retires the scope, and incomplete actions (`/choose`, `/move`, expansion or
pick-up without a completing Enter) end as `InputEnded` rather than an
acceptance. Supplied answers, generic results, defaults, limits, anchor rules and
every terminal outcome keep their previous rules.

On Windows (NT 10.0.26200.0) with Dart SDK 3.13.2, the tree/order suites passed
42 tests, the component matrix passed 144 tests, `dart analyze` reported no
issues, the changed files are formatting-clean and the documentation-link check
passed; the full suite passed 835 tests. Evidence and limitations are recorded in
`doc/evidence/trelis-backend/22-tree-order-migration.md`; native PTY, visible
GUI/NVDA, Linux/macOS CI, alternate-screen modal help, rich vertical viewport and
final-gate verification remain outstanding, and a state marker wider than the
declared width overflows rather than being split.
