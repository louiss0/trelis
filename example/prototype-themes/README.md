# Prompty — terminal theme and structure reference

**Question:** What should a CLI prompting library's components look like?

**Deliverable:** 45 terminal design languages × 40 components = **1,800 visual specimens**. Each theme is an editable SVG sheet and a matching **1800 × 4300 PNG** snapshot. These are image-based design proposals, not working widgets or implementations.

**Status:** Prototyping is complete. This complete visual atlas is retained on `main` as a design reference so `structures.html`, its gallery links and all supporting assets remain usable. The original 15 themes are liked and retained; the 30 additional themes remain exploratory visual directions. These static specimens are not production prompt implementations.

**Revision decisions:** Focus the collection on individual input, specialized values, flows, and task feedback. Keep the earlier list/table/status-badge/divider specimens removed. Use a blank row between selection titles and choices, retaining rails where they fit. Add subtle rules between sheet section titles and their specimens.

**Archived experiments:** `prototype/cli-theme-atlas`, commit `8483a5a343bb595fdbeb3b3b5881e5233c285e90`, preserves the runnable terminal trials, tests and local Dart TUI patch. Only the visual-reference folder and decision documentation were brought onto `main`; no experimental Dart dependencies or vendored code were carried over. No originating implementation issue was supplied, so this document is the context pointer.

**Backend direction:** use Dart TUI instead of building terminal interaction around `dart_console`. The successful trial used **locally patched Dart TUI 3.0.0**, not the unmodified upstream release. See [backend relationship and patch details](../../docs/terminal-backend.md), followed by the [exact 40-component inventory](../../docs/theme-components.md).

## Open it

From the project root:

```sh
python example/prototype-themes/serve.py
```

Open **http://127.0.0.1:8765/**. Stop with Ctrl+C. The server binds only to localhost. Python 3's standard library is the only runtime dependency; nothing is installed into this Dart project.

Alternatively, double-click **[index.html](index.html)** to open the gallery directly, or open any PNG/SVG in **[sheets/](sheets/)**. No network, external fonts, account, or backend is needed.

### Compare directions

- **All directions** shows all 45 previews.
- Click a theme to see its complete component sheet.
- Use the floating bottom selector or **← / →** to switch themes (wraps at both ends).
- Arrow keys aren't intercepted inside editable controls or the theme selector.
- **View at 100%** lets you inspect the full-resolution image; **Fit to width** restores the overview.
- **Open SVG**, **PNG**, and **SVG** expose individual image files.
- Share a URL such as `http://127.0.0.1:8765/?variant=blueprint` or `?variant=porcelain`.
- Theme selection is encoded in the URL, not local storage. Reload and browser back/forward work.
- The selected grammar and all nine colour tokens appear below the sheet.
- **Explore 15 structures** in the header opens the separate structural anatomy page.

## Structural anatomy page

Open **[structures.html](structures.html)** or **http://127.0.0.1:8765/structures.html**.

This page separates **prompt structure** from **colour theme**. It shows the 15 actual rendering modes shared by the 45 themes: continuous rail, conversational inline, ASCII console, square enclosure, bracketed question, rounded enclosure, fixed-label form, forward chevron, plain text, double enclosure, branching rail, underlined question, reverse-video label, numbered ledger, and key:value diagnostic.

- Compare the same **Select** prompt across all 15 structures.
- Switch the selected anatomy between **Select, TextInput, StepperForm, and MultiSpinner**.
- Each specimen is generated from the same `prompt()` and `specimen()` functions as the SVG sheets—not retyped approximations.
- Each card borrows its first matching theme's colours and links to every theme using that grammar.
- Structure and specimen are shareable, e.g. `structures.html?variant=box&component=StepperForm`.
- Use **← / →**, the bottom selector, or a card to switch structures. Selection is URL-only; no state is saved.

## The original 15 themes, expanded

| # | Theme | Direction | Images |
|---|---|---|---|
| 01 | **Signal** | Violet continuous rails; filled focus rows; quiet guidance | [SVG](sheets/01-signal.svg) · [PNG](sheets/01-signal.png) |
| 02 | **Paper** | Light, conversational, unframed prompts | [SVG](sheets/02-paper.svg) · [PNG](sheets/02-paper.png) |
| 03 | **Mainframe** | Green operator console; ASCII-only terminal samples | [SVG](sheets/03-mainframe.svg) · [PNG](sheets/03-mainframe.png) |
| 04 | **Blueprint** | Cyan square enclosures and aligned values | [SVG](sheets/04-blueprint.svg) · [PNG](sheets/04-blueprint.png) |
| 05 | **Ember** | Warm amber; bracketed questions and compact answers | [SVG](sheets/05-ember.svg) · [PNG](sheets/05-ember.png) |
| 06 | **Orchid** | Rounded Unicode enclosures and soft magenta | [SVG](sheets/06-orchid.svg) · [PNG](sheets/06-orchid.png) |
| 07 | **Workbench** | Light instrument panel; fixed form labels and clear input groups | [SVG](sheets/07-workbench.svg) · [PNG](sheets/07-workbench.png) |
| 08 | **Tide** | Mint chevrons; flowing prompts with minimal framing | [SVG](sheets/08-tide.svg) · [PNG](sheets/08-tide.png) |
| 09 | **Ink** | Monochrome, explicit symbol states, ASCII-only terminal samples | [SVG](sheets/09-ink.svg) · [PNG](sheets/09-ink.png) |
| 10 | **Arcade** | Double rules, diamond markers, electric lime focus | [SVG](sheets/10-arcade.svg) · [PNG](sheets/10-arcade.png) |
| 11 | **Fieldnotes** | Warm daylight greens and branching context | [SVG](sheets/11-fieldnotes.svg) · [PNG](sheets/11-fieldnotes.png) |
| 12 | **Nordic** | Open, underlined questions on a calm blue-grey field | [SVG](sheets/12-nordic.svg) · [PNG](sheets/12-nordic.png) |
| 13 | **Punch** | Uppercase reverse-video labels and heavy focus markers | [SVG](sheets/13-punch.svg) · [PNG](sheets/13-punch.png) |
| 14 | **Ledger** | Sepia numbered steps, dotted rules, signed selections | [SVG](sheets/14-ledger.svg) · [PNG](sheets/14-ledger.png) |
| 15 | **Infrared** | Diagnostic key:value prompts and explicit status codes | [SVG](sheets/15-infrared.svg) · [PNG](sheets/15-infrared.png) |

## 30 new themes

| # | Theme | Direction | Images |
|---|---|---|---|
| 16 | **Porcelain** | Fine rules; light cyan engineering console | [SVG](sheets/16-porcelain.svg) · [PNG](sheets/16-porcelain.png) |
| 17 | **Basalt** | Volcanic dark; elemental white and orange | [SVG](sheets/17-basalt.svg) · [PNG](sheets/17-basalt.png) |
| 18 | **Citrus** | Optimistic daylight; decisive block labels | [SVG](sheets/18-citrus.svg) · [PNG](sheets/18-citrus.png) |
| 19 | **Lavender** | Soft daylight lavender and rounded enclosures | [SVG](sheets/19-lavender.svg) · [PNG](sheets/19-lavender.png) |
| 20 | **Glacier** | Cold light and uninterrupted thin horizons | [SVG](sheets/20-glacier.svg) · [PNG](sheets/20-glacier.png) |
| 21 | **Vinyl** | Analog warmth, bold grooves, double rules | [SVG](sheets/21-vinyl.svg) · [PNG](sheets/21-vinyl.png) |
| 22 | **Botanical** | A daylight greenhouse of branching inputs | [SVG](sheets/22-botanical.svg) · [PNG](sheets/22-botanical.png) |
| 23 | **Terminal Amber** | Dedicated amber phosphor; ASCII samples | [SVG](sheets/23-terminal-amber.svg) · [PNG](sheets/23-terminal-amber.png) |
| 24 | **Slate** | Businesslike dark fields and cyan focus | [SVG](sheets/24-slate.svg) · [PNG](sheets/24-slate.png) |
| 25 | **Solar** | Sunlit prompts with forward-moving chevrons | [SVG](sheets/25-solar.svg) · [PNG](sheets/25-solar.png) |
| 26 | **Deep Space** | Dark indigo with one luminous focus thread | [SVG](sheets/26-deep-space.svg) · [PNG](sheets/26-deep-space.png) |
| 27 | **Moss** | Restrained green minimalism | [SVG](sheets/27-moss.svg) · [PNG](sheets/27-moss.png) |
| 28 | **Copper** | Patinated copper; warm bracketed labels | [SVG](sheets/28-copper.svg) · [PNG](sheets/28-copper.png) |
| 29 | **Midnight Mint** | Diagnostic fields with a cool mint signal | [SVG](sheets/29-midnight-mint.svg) · [PNG](sheets/29-midnight-mint.png) |
| 30 | **Typewriter** | Carbon copy questions and numbered audit trail | [SVG](sheets/30-typewriter.svg) · [PNG](sheets/30-typewriter.png) |
| 31 | **Neon Grid** | Electric structure and double-line enclosures | [SVG](sheets/31-neon-grid.svg) · [PNG](sheets/31-neon-grid.png) |
| 32 | **Sandstone** | Warm stone, crisp corners, grounded decisions | [SVG](sheets/32-sandstone.svg) · [PNG](sheets/32-sandstone.png) |
| 33 | **Blue Hour** | Calm indigo, underlined titles, open spacing | [SVG](sheets/33-blue-hour.svg) · [PNG](sheets/33-blue-hour.png) |
| 34 | **Matcha** | Powdered green and rounded prompts | [SVG](sheets/34-matcha.svg) · [PNG](sheets/34-matcha.png) |
| 35 | **Obsidian** | Near-black minimalism with a mineral glint | [SVG](sheets/35-obsidian.svg) · [PNG](sheets/35-obsidian.png) |
| 36 | **Clay** | Terracotta daylight and bracketed field labels | [SVG](sheets/36-clay.svg) · [PNG](sheets/36-clay.png) |
| 37 | **Polar** | Arctic clarity for dense configuration flows | [SVG](sheets/37-polar.svg) · [PNG](sheets/37-polar.png) |
| 38 | **Forest Floor** | Fern, bark, and naturally nested paths | [SVG](sheets/38-forest-floor.svg) · [PNG](sheets/38-forest-floor.png) |
| 39 | **Ultraviolet** | Electric violet focus and connected prompts | [SVG](sheets/39-ultraviolet.svg) · [PNG](sheets/39-ultraviolet.png) |
| 40 | **Sea Glass** | Weathered aqua and effortless forward motion | [SVG](sheets/40-sea-glass.svg) · [PNG](sheets/40-sea-glass.png) |
| 41 | **Carbon** | Industrial monochrome with safety-yellow guidance | [SVG](sheets/41-carbon.svg) · [PNG](sheets/41-carbon.png) |
| 42 | **Sakura** | Petal pink, generous gaps, gentle confirmations | [SVG](sheets/42-sakura.svg) · [PNG](sheets/42-sakura.png) |
| 43 | **Terminal Green** | Second-generation green phosphor; ASCII samples | [SVG](sheets/43-terminal-green.svg) · [PNG](sheets/43-terminal-green.png) |
| 44 | **Desert Dusk** | Dusky rose, sand, and bracketed questions | [SVG](sheets/44-desert-dusk.svg) · [PNG](sheets/44-desert-dusk.png) |
| 45 | **Ion** | Charged fields and structured diagnostic states | [SVG](sheets/45-ion.svg) · [PNG](sheets/45-ion.png) |

## Every theme includes all 40 components

**Inputs:** TextInput, Password, NumberInput, Multiline, Autocomplete, Confirm.

**Choices:** Select, MultiSelect, SearchSelect, Checkbox, Radio, TreeSelect.

**Individual inputs:** Toggle, Slider, DateInput, TimeInput, PathInput, Keypress.

**Feedback:** Text, Progress, Spinner, MultiSpinner.

**Specialized values:** TagInput, MaskedInput, RegexInput, URLInput, EmailInput, ColorInput, PortInput, IPAddressInput, DurationInput, CronInput, TimezoneSelect.

**Flows and navigation:** FilePicker, DirectoryPicker, RangeSlider, SortableSelect, KeyChordInput, StepperForm, CommandPalette.

Examples include formatted license-key entry, a valid regular expression with match counts, URL/email guidance, a truecolour swatch, file/directory navigation, invalid port and valid numeric errors, IPv6, human-readable duration parsing, cron schedule preview, filtered timezones, a two-ended range, reorderable priorities, a multi-key chord, a four-step form, and fuzzy commands.

**MultiSpinner** shows five concurrent tasks: one completed, two running, one failed, and one waiting. It is one static snapshot, not a live task runner.

**Selection spacing:** Autocomplete, Confirm, Select, MultiSelect, SearchSelect, Checkbox, Radio, TreeSelect, FilePicker, DirectoryPicker, TimezoneSelect, SortableSelect, and CommandPalette have one blank row between their title and choices. Framed themes retain a connecting vertical rail; unframed themes use whitespace.

## Read these as terminal designs

- The three-column specimen board, numbered captions, section rules, and editorial titles are **presentation scaffolding**, not a proposed full-screen terminal layout.
- Component samples use monospace text, character borders, symbols, and solid foreground/background colour. No web shadows, gradients, or mouse-dependent widgets appear inside the terminal samples.
- Selection state and focus have markers as well as colour. Errors have explicit explanatory copy.
- Spinners and MultiSpinner are **static snapshots**, not animation. Passwords and credentials are invented; no files, network locations, or user input are read.
- Mainframe, Ink, Terminal Amber, and Terminal Green intentionally restrict their **terminal samples** to ASCII. Surrounding editorial headings aren't ASCII-only.
- Other directions assume Unicode and truecolour support. Real implementation still needs capability detection, display-width handling, keyboard behaviour, narrow-terminal layouts, and accessibility review. This prototype doesn't settle those API decisions.
- SVG text uses local monospace font fallbacks. PNG snapshots freeze the captured rendering.

## Edit a proposal

Edit the palettes, grammars, or sample content in **[generate.py](generate.py)**, then run:

```sh
python example/prototype-themes/generate.py
```

This regenerates the **45 SVGs**, `themes.js`, and `structures.js`; the latter powers the structural anatomy page. Checked-in PNGs are browser-rendered snapshots and must be re-exported after SVG changes. Existing images need no build step.

## Verification

Rendered all 45 SVGs in headless Microsoft Edge: 40 named component groups each, **1,800 total**, with no non-empty text overflowing its specimen card. Confirmed every former display component remains absent and every new component is present. Checked ASCII-only sample output for all four phosphor/monochrome themes. Checked gallery navigation, wraparound across themes 01/45, selector changes, shareable URLs, reload, browser back, full-resolution viewing, and a 390px mobile viewport without page overflow. No runtime JavaScript errors were observed. The structural page was separately checked in Edge: all 15 cards and four specimen views, all 45 theme links, keyboard wraparound, browser back, deep links, and a 390px viewport without page overflow. No production code or package dependencies were changed; no test suite was added to this throwaway prototype.

## From reference to implementation

Keep this visual reference on `main` and use the archived prototype commit for experimental implementation evidence. Future library work should implement selected component grammars and tokens properly in Dart, not promote the throwaway terminal demos directly. Record implementation scope separately from this forty-component design inventory, and carry forward the documented Dart TUI patch requirement until an upstream replacement passes the same Windows lifecycle tests.
