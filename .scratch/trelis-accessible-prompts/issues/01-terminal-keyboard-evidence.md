# Terminal keyboard capabilities and cross-platform conflicts

Type: research
Labels: wayfinder:research
Status: resolved
Assignee: research-keyboard
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Research context

- Worker: 57fc8aa4-3088-449
- Research branch: research/trelis-keyboard
- Worktree: C:/Users/bvlou/projects/trelis-research-keyboard
- Completed report: [Terminal keyboard capabilities and cross-platform conflicts](../../../doc/research/trelis-keyboard.md).
- Exact report commit: 7e9259aad31af82740f7f7b9b29b0ff585c04bfb on research/trelis-keyboard. Parent saved the complete report and committed only that file; the research worktree is clean.

## Answer

Primary-source research is complete; the linked report contains details and citations. Legacy terminal byte streams cannot reliably distinguish Tab/Ctrl+I, Enter/Ctrl+M or Escape/Ctrl+[. Escape also prefixes sequences, so parsing and latency policy matter. Common navigation keys have variant encodings and may be intercepted or transformed by terminal profiles, OS/assistive technology, terminal modes, SSH or multiplexers. Ctrl+C can arrive through process control rather than ordinary key input.

Text input must not be reduced to physical shortcuts: layouts, AltGr/Option, dead keys and IMEs affect committed text. Grapheme segmentation and display width are distinct problems. Bracketed paste can separate paste from commands when supported, but without delimiters identical typed/pasted bytes may be indistinguishable. Enhanced protocols can reduce ambiguity only with end-to-end support.

Candidate line-oriented, conventional-interactive and negotiated-enhancement tiers are recommendations, not adopted requirements or accessibility guarantees. Existing shared/component tickets cover resulting decisions on cancellation, traversal/completion, multiline submission, paste, editing and protocol policy. Actual clipboard, IME, delayed/split sequences, remote chains, Unicode rendering and assistive-technology tests remain unperformed. External source retrieval included partial excerpts and version-sensitive documentation; exact release checks are needed before support claims. Historical Windows evidence was read from repository documentation, not rerun or independently verified by this researcher.

## Question

What keyboard events and editing conventions can terminal prompts reliably use across Windows, macOS, and Linux, including modern and legacy terminals? Investigate Enter/Escape/Ctrl+C, Tab/Shift+Tab, arrows, Home/End, Delete/Backspace, word movement/deletion, Alt/Option/Meta, control-key ambiguity, function keys, key chords, keyboard layouts, IME/composition, Unicode/graphemes, clipboard and bracketed paste, SSH/tmux, terminal/shell/OS interception, and optional enhanced keyboard protocols. Distinguish documented facts, tested evidence, and unknowns. Recommend candidate capability tiers and research-backed alternatives, not final requirements.
