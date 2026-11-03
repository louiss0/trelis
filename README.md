# Prompty

A Dart prompting-library project, currently at the design-to-implementation
stage. The visual studies and terminal-backend trials are complete; the public
prompt API is not implemented yet.

## Visual reference

Open [the 15 prompt structures](example/prototype-themes/structures.html) to
compare layout grammars, or browse [the 45-theme atlas](example/prototype-themes/index.html).
The complete folder is retained so the structure page's data, gallery links and
images work together. These are static visual references, not working prompts.

Open the HTML directly, or serve it locally:

```powershell
python example/prototype-themes/serve.py
```

Then visit <http://127.0.0.1:8765/structures.html>.

## Terminal backend and patch

The validated implementation direction is **Dart TUI (`dart_tui`)**, rather
than combining it with or extending the `dart_console` prototype backend.

**Important: the successful Windows trials used a local patch to Dart TUI
3.0.0.** Unmodified 3.0.0 failed exact echo/line-input restoration. Main records
the decision but does not install either backend or carry the patched package.

Read [the backend relationship, patch details and archived evidence](docs/terminal-backend.md).

## Components used to make the themes

The atlas depicts **40 named components** across 45 themes. See the
[complete component-name inventory](docs/theme-components.md), sourced directly
from the atlas generator. The structures page compares four of those components
across fifteen structures; neither inventory is a claim of implemented APIs.

## Archived prototypes

- Branch: `prototype/cli-theme-atlas`
- Commit: `8483a5a343bb595fdbeb3b3b5881e5233c285e90`

That commit preserves both backend trials, their real Windows-console tests,
and the locally patched Dart TUI snapshot. Main retains only the visual
references and the conclusions needed for implementation.

## Check the Dart package

```powershell
dart pub get
dart analyze
dart test
```

The current package/test are still the initial scaffold; the archived console
interaction tests are not present or runnable on main.
