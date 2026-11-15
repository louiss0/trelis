# Issue tracker: Git-backed Markdown

Issues and specs for this repository are versioned with the code under
`docs/issues/`. Tracker changes follow the same branch, review, and merge flow
as implementation changes; do not keep a second local-only tracker copy.

## Conventions

- One feature per directory: `docs/issues/<feature-slug>/`
- The spec is `docs/issues/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `docs/issues/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file (see `triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading
- Claim, resolution, and gate updates must be committed on the branch that performs the work
- Every tracker file needed to understand a committed spec or decision must be tracked by Git
- The former local-only tracker directory is forbidden; run `dart run tool/check_issue_tracker.dart` to verify the boundary

## When a skill says "publish to the issue tracker"

Create and Git-track a new file under `docs/issues/<feature-slug>/` (creating
the directory if needed). Include it in the same logical commit as the tracker
publication or in a dedicated documentation commit.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `docs/issues/<effort>/map.md` (the Notes / Decisions-so-far / Fog body).
- **Child ticket**: `docs/issues/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `docs/issues/<effort>/issues/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and commit the claim before implementation work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`, and commit those tracker updates with the completed work.
