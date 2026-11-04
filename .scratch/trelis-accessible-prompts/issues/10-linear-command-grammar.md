# Define the shared linear command and literal-input grammar

Type: grilling
Labels: wayfinder:grilling
Status: resolved
Blocked by: 04
Assignee: primary-agent
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Answer

Confirmed by the human after live discussion. This specifies command-aware linear interaction, not implementation or verified terminal support.

### Command recognition

- Shared commands are exactly `/help` and `/cancel`. On ordinary command-aware submitted lines, no identified-paste literal-data provenance is present; pasted-literal lines follow the separate identified-paste rules. A slash prefix alone has no special meaning.
- Recognize an active command only as an exact, case-sensitive, complete line after removing its line terminator, before trimming, normalization or component parsing. Do not use aliases, abbreviations, prefix matching or whitespace-tolerant matching.
- Unknown command-like strings, different case and whitespace variants are ordinary data subject to component validation.
- Components may extend the command set only through explicit component contracts and advertised commands. Help lists the full active set; no hidden registration.
- `/help` explains available actions and quoting without mutating/submitting the pending answer or revealing secrets.
- `/cancel` cancels the whole standalone prompt without accepting an answer; it is not the layered rich-mode Escape action.
- EOF neither executes an unterminated command nor submits a partial answer. Preserve the shared distinct input-ended outcome.

### Backslash quoting

Apply these rules before command matching on command-aware, non-paste lines:

On an ordinary submitted command-aware line, apply these rules at submission:

1. If the line begins with one backslash immediately followed by an exact active command, remove that backslash and treat the resulting whole line as data.
2. Otherwise, if it begins with two backslashes, remove exactly one and treat the resulting whole line as data.
3. Otherwise preserve the line unchanged and perform ordinary exact command matching.
4. Never reparse the unquoted result as a command or repeat the quoting pass.

Examples (literal characters, not programming-language string escapes):

| Input | Meaning |
|---|---|
| `/cancel` | Cancel the prompt |
| `\/cancel` | Literal `/cancel` |
| `/help` | Show help without changing the answer |
| `/home/me` | Literal path |
| `2026/11/03` | Ordinary date input |
| `\temp` | Literal rooted path, unchanged |
| `\\server\share` | Data beginning with one backslash, not a literal UNC pair |
| `\\\server\share` | Literal UNC path beginning with two backslashes |
| `/Cancel` or `/cancel ` | Ordinary data, not cancellation |

For n >= 2 leading backslashes in command-aware entry, n-1 reach the component. Explain this prominently wherever Windows paths can be entered. Backslashes elsewhere are unchanged by this shared grammar; component-specific path or text parsing is a separate matter.

### Literal-input boundaries

- Caller-supplied answer values bypass the command/quoting grammar. A supplied `/cancel` is a value, not an action.
- An explicitly opted-in command-aware line-input source uses this grammar. Do not automatically consume redirected input or infer that a data stream is a command source.
- Explicitly identified paste is literal data and bypasses command recognition and quoting. Do not replay pasted newlines as submission or navigation commands; require explicit submission.
- A line containing identified pasted content remains data, including when Enter later submits it. Do not reclassify it as a command at submission. Component contracts decide whether its multiline content is valid.
- Without explicit framing/provenance, typed and pasted identical bytes may be indistinguishable. Such input follows the documented line grammar; do not promise paste detection or silently infer provenance.
- Hidden secret-value entry is entirely literal: no command recognition and no backslash rewriting, regardless of provenance. Visible help/cancel/submit/re-enter actions occur outside that stage and never echo secret text. The Password contract must specify the flow and apply the shared echo/verification gates.

### Editor-state clarification (readiness addendum)

A capable command-aware editor maintains literal answer data separately from any reversible display representation. Backslash escapes displayed for initial/reopened values are not stored as literal answer characters merely because someone edits nearby or inserts identified paste.

Retain literal-data provenance for identified pasted ranges, including after later edits. Command recognition and representation decoding occur once when the logical answer line is submitted and its provenance permits, not as intermediate editing reinterprets answer characters. If pasted literal provenance applies, no command recognition/quoting strips data from that logical line. Rich literal-only editors and secret editors remain literal without representation encoding.

This preserves the grammar's arbitrary-literal guarantee while preventing representation escapes from leaking into answers. Exact editor buffer/API design and actual terminal paste provenance remain implementation/verification concerns.

### Component follow-through

- [Specify text and structured-input interactions](05-editing-prompt-contracts.md) defines multiline completion, tags and password action stages without contradicting this grammar.
- [Specify choice and hierarchical-navigation interactions](06-choice-and-navigation-contracts.md) defines its explicit linear actions and any advertised command extensions.
- [Specify specialized value and key-capture interactions](07-specialized-prompt-contracts.md) preserves slash-separated DateInput and specifies filesystem/key-capture flows.
- Arbitrary literal answers remain representable; command recognition is not component validation, and quoting is not general shell escaping.
- Actual input framing, character preservation and accessible instruction delivery still require verification in the selected environments.

## Question

How can users cancel, request help and enter arbitrary literal values consistently in linear mode, including values identical to command tokens, slash-separated dates, slash-prefixed paths, multiline text and secrets? Choose discoverable commands and collision-safe literal entry/escaping, define what an entered line means versus EOF, and ensure rich/linear task equivalence without silently reserving otherwise valid answers.
