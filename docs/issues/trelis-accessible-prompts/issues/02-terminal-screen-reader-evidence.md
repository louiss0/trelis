# Screen-reader access and nonvisual terminal interaction

Type: research
Labels: wayfinder:research
Status: resolved
Assignee: research-screen-readers
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Research context

- Worker: ec184a0a-fecb-40b
- Research branch: research/trelis-screen-readers
- Worktree: C:/Users/bvlou/projects/trelis-research-screen-readers
- Completed report: [Screen-reader access and nonvisual terminal interaction](../../../../doc/research/trelis-screen-readers.md).
- Exact report commit: 23530e5affa2c4022d9f764bd9ea56cfd9d14833 on research/trelis-screen-readers. Parent saved the complete worker report and committed only that report; research worktree is clean.

## Answer

Primary-source research is complete; see the linked report at the exact revision above. Terminal accessibility depends on the application, terminal, OS, assistive technology and configuration together. ANSI support alone is not an accessibility check. NVDA 2025.3 documents terminal-specific reporting settings and password-related caveats; Apple documents VoiceOver use in Terminal; GNOME documents Orca review and VTE accessibility interfaces. These capabilities do not establish Trelis support.

The report recommends investigating an explicitly selectable linear interaction path, stable textual state/errors, bounded progress updates, secret-safe output and separate input/output TTY handling. These are proposals for the shared-contract decision, not approved requirements. It provides coverage of all 39 specimens, candidate environments and a manual verification protocol. No actual screen-reader, terminal, password or restoration tests were performed; some external evidence was retrieved through search excerpts and rolling documentation, so exact-version confirmation remains necessary before support claims.

No new interaction decision was made. Follow-up questions about fallback mode, state vocabulary, progress policy and non-TTY operation belong to the existing shared-contract and component tickets. Hands-on announcement/password validation remains in the map's fog until a precise experiment and environment are selected. The subsequent slash-separated DateInput clarification is a required input to the specialized-input ticket; this report does not finalize date syntax.

## Question

What terminal interaction and output strategies make standalone prompts usable with screen readers on Windows, macOS, and Linux? Investigate primary documentation for NVDA, Narrator, VoiceOver, Orca and representative terminals; distinguish actual documented support from assumptions. Examine redraw/cursor movement/alternate screen, labels/instructions/current choice, errors, passwords, dynamic feedback, progress, color dependence, reduced motion, plain or linear fallback interactions, redirected/non-TTY input/output, and manual verification. Explain which web accessibility patterns are useful analogies but not terminal conformance guarantees. Propose candidate environments and unresolved validation tasks without claiming unperformed tests.
