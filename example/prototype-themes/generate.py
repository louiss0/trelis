"""THROWAWAY visual study: 45 terminal design languages, 40 components.
Run: python example/prototype-themes/generate.py
Only writes sibling assets; no dependencies, network, or production Dart code.
"""
from pathlib import Path
from html import escape
import json

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / 'sheets'
ASSETS.mkdir(exist_ok=True)

# name / slug / visual language / palette: page, terminal, text, muted,
# accent, selected foreground, success, error, rule. All colours are opaque.
SPECS = [
    ('Signal', 'signal', 'rail', 'Quiet guidance. One continuous thread.',
     ['#11121b', '#191b28', '#e6e8f4', '#a1a7bd', '#b6a2ff', '#191329', '#9bddb4', '#ff929e', '#3b3d55']),
    ('Paper', 'paper', 'minimal', 'Less chrome. More conversation.',
     ['#eeece6', '#faf9f5', '#282d32', '#666b70', '#205cc5', '#ffffff', '#277243', '#b53535', '#cbc9c1']),
    ('Mainframe', 'mainframe', 'ascii', 'An operator console. Nothing ornamental.',
     ['#09120c', '#0d1a10', '#b2e9b9', '#81a989', '#90f6a3', '#0d1a10', '#90f6a3', '#ffb184', '#365740']),
    ('Blueprint', 'blueprint', 'box', 'Every answer has a place.',
     ['#0d223b', '#102c4b', '#e0efff', '#95b6d6', '#74d7ff', '#102c4b', '#9de4d0', '#ffb5ae', '#386387']),
    ('Ember', 'ember', 'bracket', 'Warm tools for late-night builders.',
     ['#211a14', '#2a2119', '#f3e4cf', '#b6a38a', '#ffc16e', '#2a2119', '#bbd58f', '#ff9680', '#63503c']),
    ('Orchid', 'orchid', 'round', 'Soft edges. A friendly little dialogue.',
     ['#23182a', '#2c2035', '#f5e8fa', '#bfa5ca', '#eba7f7', '#2c2035', '#b5e5c4', '#ffaaa6', '#64466f']),
    ('Workbench', 'workbench', 'form', 'A compact instrument panel, in daylight.',
     ['#e4e9ee', '#f7f9fc', '#243448', '#5b6c80', '#155fbd', '#ffffff', '#24714c', '#bb3945', '#b7c4d3']),
    ('Tide', 'tide', 'chevron', 'Fast, flowing, and out of your way.',
     ['#0b2023', '#102d30', '#e1f5f2', '#93b8b5', '#70e4ce', '#102d30', '#a5e1a5', '#ffaaa1', '#345e61']),
    ('Ink', 'ink', 'plain', 'Pure ASCII. Pure contrast. No colour required.',
     ['#101010', '#191919', '#f5f5f5', '#b2b2b2', '#ffffff', '#101010', '#eeeeee', '#ffffff', '#5c5c5c']),
    ('Arcade', 'arcade', 'double', 'High energy. Hard edges. Big feedback.',
     ['#18132b', '#201a37', '#f0ebff', '#b3a4d2', '#c7f36b', '#201a37', '#71edc1', '#ff9acb', '#655589']),
    ('Fieldnotes', 'fieldnotes', 'branch', 'Prompts that grow into a working tree.',
     ['#e8e9dd', '#f5f4e9', '#303d30', '#64715c', '#3d7046', '#ffffff', '#3d7046', '#ad4331', '#bac4ab']),
    ('Nordic', 'nordic', 'line', 'A calm horizon for long sessions.',
     ['#252d3b', '#2e3848', '#e9eef5', '#a6b4c8', '#9bd5e0', '#2e3848', '#b4d69c', '#efa5af', '#52637c']),
    ('Punch', 'punch', 'block', 'Loud hierarchy. Decisive actions.',
     ['#f0e9df', '#fffaf2', '#27221f', '#74655c', '#a83e17', '#ffffff', '#2e6c42', '#b32d35', '#ccb8a7']),
    ('Ledger', 'ledger', 'ledger', 'Numbered steps. An orderly paper trail.',
     ['#e9e1d1', '#f7f0e2', '#42392f', '#776958', '#83562d', '#ffffff', '#416a44', '#ad3b37', '#c3b398']),
    ('Infrared', 'infrared', 'colon', 'A precise, diagnostic command language.',
     ['#21161a', '#2d1d23', '#f8e8ed', '#c09fa9', '#ff9a9f', '#2d1d23', '#b7d6ad', '#ffb16f', '#69434f']),

    # Thirty additional visual directions. Each uses one of the terminal grammars
    # above, but has an independent palette, typography hierarchy, and voice.
    ('Porcelain', 'porcelain', 'box', 'Fine rules and quietly engineered answers.',
     ['#e8eef0', '#f8fbfc', '#20303a', '#65757e', '#276979', '#ffffff', '#347451', '#b34e4e', '#b5c7ce']),
    ('Basalt', 'basalt', 'plain', 'Volcanic dark, elemental white, a spark of orange.',
     ['#121414', '#1c2020', '#eef0ec', '#9ba39e', '#ffb36b', '#1c2020', '#b7cfa5', '#ff978c', '#424b47']),
    ('Citrus', 'citrus', 'block', 'Sharp citrus accents with an optimistic rhythm.',
     ['#eeefda', '#fafbe9', '#29331e', '#687354', '#6c8128', '#ffffff', '#41702e', '#b34e33', '#bec69a']),
    ('Lavender', 'lavender', 'round', 'A soft lavender console for deliberate work.',
     ['#ebe7f1', '#f8f4fb', '#3c3449', '#756a84', '#786099', '#ffffff', '#437354', '#b44960', '#cdc0db']),
    ('Glacier', 'glacier', 'line', 'Cold light and long, uninterrupted horizons.',
     ['#e4f0f3', '#f2fafc', '#1d3a45', '#5d7b85', '#197c9b', '#ffffff', '#347768', '#b64b5c', '#b2cdd7']),
    ('Vinyl', 'vinyl', 'double', 'Analog warmth, bold grooves, decisive playback.',
     ['#231d1c', '#2e2624', '#f1e7d8', '#b5a69b', '#e2aa74', '#2e2624', '#b3ca9c', '#ed9890', '#62514a']),
    ('Botanical', 'botanical', 'branch', 'A greenhouse of inputs, growing one by one.',
     ['#e2eadd', '#f2f6ed', '#2a3b30', '#657767', '#48754e', '#ffffff', '#48754e', '#ad5545', '#b7c8b1']),
    ('Terminal Amber', 'terminal-amber', 'ascii', 'A dedicated amber phosphor instrument.',
     ['#191208', '#231a0b', '#f2d29b', '#b59a69', '#ffc35e', '#231a0b', '#dfc586', '#f19b73', '#5f4827']),
    ('Slate', 'slate', 'form', 'Businesslike fields with a precise cyan accent.',
     ['#29303a', '#343e4b', '#e5ebf0', '#a1afbc', '#7fc9dc', '#343e4b', '#add2ae', '#efa5a4', '#586878']),
    ('Solar', 'solar', 'chevron', 'Sunlit prompts that keep momentum moving forward.',
     ['#f4eacb', '#fff7df', '#3d392b', '#7d745b', '#a66515', '#ffffff', '#537843', '#b44732', '#d5c89f']),
    ('Deep Space', 'deep-space', 'rail', 'A starless field. One luminous point of focus.',
     ['#0e1424', '#151e31', '#e2e9fb', '#8f9fbd', '#91b9ff', '#151e31', '#95d5b6', '#f0a2b7', '#374968']),
    ('Moss', 'moss', 'minimal', 'Low-contrast foliage. High-clarity questions.',
     ['#1b241d', '#253127', '#e0e7d9', '#97a78f', '#b6c991', '#253127', '#b6d2a1', '#e7a391', '#4b5e48']),
    ('Copper', 'copper', 'bracket', 'Patinated copper and deliberate, warm guidance.',
     ['#e9e4da', '#f7f3ea', '#3f3830', '#7b7063', '#8c5e3c', '#ffffff', '#3f7357', '#a64841', '#c9bca9']),
    ('Midnight Mint', 'midnight-mint', 'colon', 'Diagnostic precision with a cool mint signal.',
     ['#101e20', '#172b2e', '#e1f0ec', '#8daaa6', '#8be5c5', '#172b2e', '#9edbb7', '#f1a396', '#38565a']),
    ('Typewriter', 'typewriter', 'ledger', 'Carbon copy questions and a numbered audit trail.',
     ['#e8e1d5', '#f6f0e5', '#363432', '#77716a', '#5e5a52', '#ffffff', '#416448', '#a14944', '#c0b6a7']),
    ('Neon Grid', 'neon-grid', 'double', 'Electric structure for high-signal interactions.',
     ['#121821', '#192331', '#e4f0f7', '#93a7b5', '#6bf1d1', '#192331', '#a6e899', '#ff93ab', '#3d5a69']),
    ('Sandstone', 'sandstone', 'box', 'Warm stone, crisp corners, grounded decisions.',
     ['#e8dfd1', '#f7f0e5', '#403a31', '#7d7261', '#826947', '#ffffff', '#4d7553', '#ad4d43', '#c8b9a3']),
    ('Blue Hour', 'blue-hour', 'line', 'Blue hour calm with the lightest possible footprint.',
     ['#1a2233', '#222e42', '#e4eaf5', '#97a7be', '#a5b8ee', '#222e42', '#acd3b2', '#eda6b3', '#455773']),
    ('Matcha', 'matcha', 'round', 'Powdered green, rounded prompts, patient progress.',
     ['#e5e9d8', '#f4f5e8', '#384133', '#718064', '#607c42', '#ffffff', '#607c42', '#ad5346', '#bdc8a7']),
    ('Obsidian', 'obsidian', 'minimal', 'Near-black minimalism with a mineral glint.',
     ['#101013', '#19191f', '#eeedf3', '#9795a3', '#c5bedc', '#19191f', '#adc9ad', '#e6a0a6', '#42404e']),
    ('Clay', 'clay', 'bracket', 'Earthy terracotta and hands-on field labels.',
     ['#f0dfd5', '#fbefe7', '#4b352d', '#876d5e', '#a14f34', '#ffffff', '#47704c', '#a53f3a', '#d3b3a2']),
    ('Polar', 'polar', 'form', 'Arctic clarity for dense configuration flows.',
     ['#e5ecf1', '#f6fafc', '#26343e', '#657985', '#246986', '#ffffff', '#397257', '#b24b50', '#b6c9d4']),
    ('Forest Floor', 'forest-floor', 'branch', 'Fern, bark, and a naturally nested path forward.',
     ['#171e18', '#212c22', '#e2e7d8', '#9aaa92', '#adc587', '#212c22', '#a4d1a3', '#e5a083', '#485a45']),
    ('Ultraviolet', 'ultraviolet', 'rail', 'Ultraviolet focus with an electric pulse.',
     ['#191127', '#24183a', '#eee5fc', '#ac97c6', '#ca9aff', '#24183a', '#9ed6b4', '#f5a0bd', '#543e73']),
    ('Sea Glass', 'sea-glass', 'chevron', 'Weathered aqua and effortless forward motion.',
     ['#dfede9', '#f2f9f5', '#29413e', '#6d8881', '#2d7970', '#ffffff', '#3b7c60', '#af514b', '#b0d0c6']),
    ('Carbon', 'carbon', 'plain', 'Industrial monochrome with safety-yellow guidance.',
     ['#181918', '#242625', '#efeee7', '#a6aaa0', '#e5d36b', '#242625', '#bfcd9a', '#f1a38a', '#50554c']),
    ('Sakura', 'sakura', 'round', 'Petal pink, generous gaps, and gentle confirmations.',
     ['#f3e5e8', '#fff5f6', '#49343d', '#886d78', '#a35678', '#ffffff', '#49775b', '#b14450', '#d9bac4']),
    ('Terminal Green', 'terminal-green', 'ascii', 'A second-generation green phosphor console.',
     ['#0c1713', '#12231b', '#c0e6c8', '#82a98e', '#81e69f', '#12231b', '#81e69f', '#efb37d', '#3d614a']),
    ('Desert Dusk', 'desert-dusk', 'bracket', 'Dusky rose and sand for unhurried command lines.',
     ['#2b2020', '#392929', '#f0dfd4', '#b9a095', '#e5ae8e', '#392929', '#bccca4', '#f09b8d', '#684e48']),
    ('Ion', 'ion', 'colon', 'Charged fields and explicit, structured input states.',
     ['#141d26', '#1b2936', '#e0edf5', '#8da5b5', '#88d1f4', '#1b2936', '#9fd9b4', '#f3a5a4', '#3f5b70']),
]

COMPONENTS = [
    ('TextInput', 'focused'), ('Password', 'masked'), ('NumberInput', 'invalid'),
    ('Multiline', 'editing'), ('Autocomplete', 'suggesting'), ('Confirm', 'pending'),
    ('Select', 'focused'), ('MultiSelect', '2 selected'), ('SearchSelect', 'filtered'),
    ('Checkbox', 'checked'), ('Radio', 'exclusive'), ('TreeSelect', 'expanded'),
    ('Toggle', 'on'), ('Slider', '6 of 10'), ('DateInput', 'month focused'),
    ('TimeInput', 'hour focused'), ('PathInput', 'valid directory'), ('Keypress', 'captured'),
    ('Text', 'semantic'), ('Progress', '64%'), ('Spinner', 'static frame'),
    ('MultiSpinner', 'concurrent tasks'),
    ('TagInput', '3 tags'), ('MaskedInput', 'formatted'), ('RegexInput', 'valid + matches'),
    ('URLInput', 'valid'), ('EmailInput', 'completing'), ('ColorInput', 'truecolor'),
    ('FilePicker', 'file selected'), ('DirectoryPicker', 'browsing'), ('PortInput', 'invalid port'),
    ('IPAddressInput', 'IPv6'), ('DurationInput', 'human readable'), ('CronInput', 'next run'),
    ('TimezoneSelect', 'filtered'), ('RangeSlider', '20 to 80'), ('SortableSelect', 'reordered'),
    ('KeyChordInput', '2-key chord'), ('StepperForm', 'step 2 of 4'), ('CommandPalette', 'fuzzy command'),
]

NOTES = {
    'rail': 'Unicode rails / filled focus row / short helper copy',
    'minimal': 'Inline questions / no framing / typographic focus',
    'ascii': 'ASCII-only / numbered choices / explicit status words',
    'box': 'Square enclosures / aligned values / cyan focus',
    'bracket': 'Bracketed labels / warm cursor / compact answers',
    'round': 'Rounded enclosures / dot choices / gentle guidance',
    'form': 'Fixed-width labels / form fields / clear input groups',
    'chevron': 'Forward prompts / arrow choices / flowing navigation',
    'plain': 'ASCII-only / symbol + word states / monochrome',
    'double': 'Double rules / diamond choices / reverse-video focus',
    'branch': 'Branching prompts / nested context / organic rhythm',
    'line': 'Underlined questions / open space / thin progress',
    'block': 'Uppercase labels / heavy markers / reverse-video focus',
    'ledger': 'Numbered steps / dotted leaders / signed selections',
    'colon': 'Key:value prompts / diagnostic codes / explicit states',
}

# A line consists of (text, semantic colour, optional reverse-video highlight).
def line(text='', role='text', selected=False):
    return (text, role, selected)


def vocabulary(mode):
    return {
        'rail':     ('◆', '✓', '□', '●', '○', '│', '█', '░', '⠹'),
        'minimal':  ('›', '✓', '·', '●', '○', ' ', '━', '─', '◒'),
        'ascii':    ('>', '[x]', '[ ]', '(*)', '( )', '|', '#', '-', '/'),
        'box':      ('▸', '■', '□', '◉', '○', '│', '■', '·', '⠹'),
        'bracket':  ('»', '[✓]', '[ ]', '(●)', '( )', ' ', '▰', '▱', '◐'),
        'round':    ('❯', '✓', '·', '●', '○', '│', '●', '·', '⠋'),
        'form':     ('>', '[x]', '[ ]', '(x)', '( )', '|', '■', '□', '/'),
        'chevron':  ('❯', '✓', '·', '◉', '○', ' ', '━', '─', '◓'),
        'plain':    ('>', '[x]', '[ ]', '(x)', '( )', '|', '#', '.', '*'),
        'double':   ('»', '◆', '◇', '◆', '◇', '║', '█', '░', '◈'),
        'branch':   ('↳', '[✓]', '[ ]', '(●)', '( )', '│', '▰', '▱', '◴'),
        'line':     ('›', '✓', '–', '●', '○', ' ', '━', '─', '◌'),
        'block':    ('▶', '[X]', '[ ]', '(X)', '( )', '┃', '█', '░', '◑'),
        'ledger':   ('>', '[+]', '[-]', '(+)', '(-)', ':', '=', '.', '/'),
        'colon':    ('::', '[+]', '[ ]', '(+)', '( )', ':', '━', '·', '⠸'),
    }[mode]


def prompt(mode, label, body, hint=None, selection_gap=False):
    """Deliberately different terminal grammars, not only different palettes."""
    rows = []
    if mode in ('box', 'round', 'double'):
        a,b,c,d,e,f = {'box':('┌','─','┐','│','└','┘'),
                       'round':('╭','─','╮','│','╰','╯'),
                       'double':('╔','═','╗','║','╚','╝')}[mode]
        width = 42
        title = ' ' + label + ' '
        rows = [line(a + title + b*(width-len(title)) + c, 'accent')]
        for value, role, active in body:
            rows.append(line(d + ' ' + value.ljust(width-1) + d, role, active))
        rows.append(line(e+b*width+f, 'rule'))
        if hint: rows.append(line('  '+hint, 'muted'))
    elif mode in ('rail', 'branch'):
        rows = [line(('┌  ' if mode == 'rail' else '╭─ ') + label, 'accent')]
        rows += [line('│  '+v, r, s) for v,r,s in body]
        if hint: rows.append(line('└  '+hint, 'muted'))
    elif mode == 'form':
        rows = [line(label.upper().ljust(17) + ' FIELD', 'accent'), line('-'*42, 'rule')]
        rows += [line('| '+v, r,s) for v,r,s in body]
        if hint: rows.append(line('  '+hint, 'muted'))
    elif mode == 'ledger':
        rows = [line('01 / '+label, 'accent'), line('.'*42, 'rule')]
        rows += [line('   '+v,r,s) for v,r,s in body]
        if hint: rows.append(line('   note: '+hint, 'muted'))
    elif mode == 'colon':
        rows = [line('ask:'+label.lower().replace(' ', '_'), 'accent')]
        rows += [line('  '+v,r,s) for v,r,s in body]
        if hint: rows.append(line('hint:'+hint, 'muted'))
    elif mode == 'block':
        rows = [line(' '+label.upper()+' ', 'accent', True)]
        rows += [line('  '+v,r,s) for v,r,s in body]
        if hint: rows.append(line('  '+hint.upper(), 'muted'))
    elif mode == 'line':
        rows = [line(label, 'accent'), line('─'*max(len(label), 22), 'rule')]
        rows += [line('  '+v,r,s) for v,r,s in body]
        if hint: rows.append(line('  '+hint, 'muted'))
    elif mode == 'bracket':
        rows = [line('[ '+label+' ]', 'accent')]
        rows += [line('  '+v,r,s) for v,r,s in body]
        if hint: rows.append(line('  '+hint, 'muted'))
    elif mode == 'ascii':
        rows = [line('? '+label.upper(), 'accent')]
        rows += [line('  '+v,r,s) for v,r,s in body]
        if hint: rows.append(line('  -- '+hint, 'muted'))
    elif mode == 'plain':
        rows = [line(label+'?', 'accent')]
        rows += [line('  '+v,r,s) for v,r,s in body]
        if hint: rows.append(line('  ('+hint+')', 'muted'))
    elif mode == 'chevron':
        rows = [line('❯ '+label, 'accent')]
        rows += [line('  '+v,r,s) for v,r,s in body]
        if hint: rows.append(line('  ↳ '+hint, 'muted'))
    else:  # Paper's inline text fields, otherwise unframed conversation.
        if len(body) == 1:
            rows = [line(label, 'muted'), line(body[0][0], body[0][1], body[0][2])]
        else:
            rows = [line(label, 'accent')] + body
        if hint: rows.append(line(hint, 'muted'))
    if selection_gap:
        # A breathing row between the question and choices; retain the theme's rail.
        if mode in ('box', 'round', 'double'):
            rows.insert(1, line(d + ' '*width + d, 'rule'))
        elif mode in ('rail', 'branch'):
            rows.insert(1, line('│', 'rule'))
        else:
            after_title = 2 if mode in ('form', 'ledger', 'line') else 1
            rows.insert(after_title, line('|' if mode == 'form' else '', 'rule'))
    return rows


def specimen(mode, component):
    arrow, yes, no, on, off, rail, fill, empty, spin = vocabulary(mode)
    ascii_mode = mode in ('ascii', 'plain', 'form', 'ledger')
    cursor = '_' if ascii_mode else '▏'
    move = 'up/down' if ascii_mode else '↑/↓'
    focused = mode in ('rail','box','double','block','form')
    def option(text, active=False, mark=None):
        prefix = arrow if active else ' ' * len(arrow)
        if mark is not None:
            prefix += ' ' + mark
        return line(prefix+' '+text, 'accent' if active else 'text', active and focused)
    def p(label, rows, hint=None):
        gap = component in ('Autocomplete', 'Confirm', 'Select', 'MultiSelect',
                            'SearchSelect', 'Checkbox', 'Radio', 'TreeSelect',
                            'FilePicker', 'DirectoryPicker', 'TimezoneSelect',
                            'SortableSelect', 'CommandPalette')
        return prompt(mode,label,rows,hint,selection_gap=gap)
    if component == 'TextInput':
        return p('Project name', [line(arrow+' orbit'+cursor,'accent')], 'enter to continue')
    if component == 'Password':
        return p('Access token', [line(arrow+' '+('*'*12 if ascii_mode else '•'*12)+cursor,'accent')], 'hidden / paste supported')
    if component == 'NumberInput':
        return p('Worker count', [line(arrow+' 0'+cursor,'error'), line('! Must be between 1 and 16','error')], 'default: 4')
    if component == 'Multiline':
        return p('Release notes', [line('1  Ship a smaller CLI.'),line('2  Keep the good defaults.'),line('3  '+cursor,'accent')], 'alt+enter to submit')
    if component == 'Autocomplete':
        return p('Package manager', [line('pn'+cursor,'accent'),option('pnpm', True),option('pnpx')], 'tab to complete')
    if component == 'Confirm':
        body = [line(arrow+' '+('[Y] yes / [n] no' if ascii_mode else 'Yes  /  No'), 'accent', focused)]
        return p('Create project?',body,'Y/n / default: yes')
    if component == 'Select':
        return p('Choose a template', [option('Starter',True),option('Library'),option('Workspace')],move+' move / enter select')
    if component == 'MultiSelect':
        return p('Add integrations', [option('Lint',True,yes),option('Tests',False,yes),option('Docs',False,no)],'space toggle / 2 selected')
    if component == 'SearchSelect':
        return p('Deployment region', [line('/ eu'+cursor, 'accent'),option('eu-west-1   Ireland',True),option('eu-north-1  Stockholm')], '2 of 12 matches')
    if component == 'Checkbox':
        return p('Telemetry', [line(yes+' Share anonymous usage', 'success'),line(no+' Include debug logs', 'muted')], 'space to toggle')
    if component == 'Radio':
        return p('Release channel', [option('Stable',True,on),option('Canary',False,off)], 'one choice only')
    if component == 'TreeSelect':
        if ascii_mode:
            rows = [line('[-] packages/'),option('  +-- cli/',True),line('  `-- core/'),line('[+] docs/','muted')]
        else:
            rows = [line('▾ packages/'),option('  ├─ cli/',True),line('  └─ core/'),line('▸ docs/','muted')]
        return p('Target workspace',rows, 'left/right expand' if ascii_mode else '←/→ expand / enter select')
    if component == 'Toggle':
        return p('Automatic updates', [line(arrow+' [ ON ]   off', 'accent', focused)], 'space to switch / enter accept')
    if component == 'Slider':
        thumb = 'O' if ascii_mode else '◆'
        return p('Compression level', [line('0  '+fill*6+thumb+empty*4+'  10', 'accent'),
                                        line('value: 6 / step: 1', 'text')],
                 'left/right adjust' if ascii_mode else '←/→ adjust / enter accept')
    if component == 'DateInput':
        return p('Launch date', [line(arrow+' 2026 / [11] / 18', 'accent'),
                                 line('  YYYY    MM    DD', 'muted')], 'tab segment / '+move+' adjust')
    if component == 'TimeInput':
        return p('Publish time', [line(arrow+' [09] : 30', 'accent'),
                                  line('   HH    MM    24h', 'muted')], 'tab segment / '+move+' adjust')
    if component == 'PathInput':
        return p('Output directory', [line(arrow+' ./dist/'+cursor, 'accent'),
                                      line('OK Directory is writable', 'success')], 'tab complete / enter accept')
    if component == 'Keypress':
        return p('Bind shortcut', [line(arrow+' [ Ctrl + K ]', 'accent'),
                                   line('Captured: Ctrl+K', 'muted')], 'press a key / esc cancel')
    if component == 'Text':
        return [line('Build something small.', 'text'),line('A quiet hint lives here.', 'muted'),line(('OK ' if ascii_mode else '✓  ')+'Configuration valid','success'),line('!  Token expires in 2 days','error')]
    if component == 'Progress':
        bar = fill*18+empty*10
        left,right = ('[',']') if ascii_mode or mode in ('bracket','form') else ('','')
        return [line('Installing dependencies','accent'),line(),line(left+bar+right+'  64%','accent'),line('128 / 200 packages','text'),line('elapsed 00:08 / eta 00:04','muted')]
    if component == 'Spinner':
        return [line(spin+' Resolving packages...','accent'),line('  registry.npmjs.org','muted'),line(),line('  ctrl+c to cancel','muted'),line('  indeterminate / static frame','muted')]
    if component == 'MultiSpinner':
        return [line('Preparing workspace', 'accent'), line(),
                line(yes+' Validate config    done', 'success'),
                line(spin+' Install packages   running', 'accent'),
                line(spin+' Compile assets     running', 'accent'),
                line('! Publish preview    failed', 'error'),
                line(no+' Upload artifacts   waiting', 'muted'),
                line('2 running / 1 failed / 1 waiting', 'muted')]
    if component == 'TagInput':
        if mode == 'block':
            tags = 'DART  /  CLI  /  TUI'
        elif mode in ('box', 'round', 'double'):
            tags = '( dart ) ( cli ) ( tui )'
        elif mode in ('ascii', 'form'):
            tags = '[dart] [cli] [tui]'
        else:
            tags = '<dart> <cli> <tui>'
        return p('Keywords', [line(arrow+' '+tags+' '+cursor, 'accent')],
                 'enter adds / backspace removes')
    if component == 'MaskedInput':
        return p('License key', [line(arrow+' PRMP-7A__-____-____', 'accent'),
                                 line('  XXXX-XXXX-XXXX-XXXX', 'muted')],
                 'format applied as you type')
    if component == 'RegexInput':
        return p('Version pattern', [line(arrow+' r"^v(\\d+)\\.\\d+"', 'accent'),
                                     line('OK 3 matches / 1 group', 'success')],
                 'sample: v2.1, v3.0, v4.2')
    if component == 'URLInput':
        return p('Documentation URL', [line(arrow+' https://dart.dev'+cursor, 'accent'),
                                        line('OK HTTPS / host: dart.dev', 'success')],
                 'enter to accept')
    if component == 'EmailInput':
        return p('Maintainer email', [line(arrow+' dev@'+cursor, 'accent'),
                                      line('  dev@dart.dev', 'muted')],
                 'tab complete domain')
    if component == 'ColorInput':
        value = '#8A6FBF' if ascii_mode else '#8A6FBF  ●'
        return p('Accent color', [line(arrow+' '+value, 'accent'),
                                  line('hex / RGB 138, 111, 191', 'muted')],
                 'named colors and hex accepted')
    if component == 'FilePicker':
        if ascii_mode:
            rows = [line('./ lib/'),option('  [>] main.dart',True),line('      theme.dart')]
        else:
            rows = [line('lib/'),option('  '+arrow+' main.dart',True),line('    theme.dart')]
        return p('Entry file',rows,'file filter: *.dart')
    if component == 'DirectoryPicker':
        if ascii_mode:
            rows = [line('..'),option('  [>] ./lib',True),line('      ./test'),line('      ./example')]
        else:
            rows = [line('..'),option('  '+arrow+' lib/',True),line('    test/'),line('    example/')]
        return p('Project folder',rows,'enter opens / ctrl+enter select')
    if component == 'PortInput':
        return p('Listen port', [line(arrow+' 70000'+cursor, 'error'),
                                 line('! Port must be 1-65535', 'error')],
                 'default: 8080')
    if component == 'IPAddressInput':
        return p('Bind address', [line(arrow+' ::1'+cursor, 'accent'),
                                  line('IPv6 / loopback interface', 'muted')],
                 'IPv4, IPv6, or CIDR')
    if component == 'DurationInput':
        return p('Request timeout', [line(arrow+' 1h 30m'+cursor, 'accent'),
                                     line('= 90 minutes / 5400 seconds', 'muted')],
                 'examples: 90s, 2m, 1h 30m')
    if component == 'CronInput':
        return p('Backup schedule', [line(arrow+' 0 2 * * 1', 'accent'),
                                     line('Every Monday at 02:00', 'success')],
                 'next: Mon 18 May, 02:00')
    if component == 'TimezoneSelect':
        return p('Schedule timezone', [line('/ new yo'+cursor, 'accent'),
                                       option('America/New_York',True),
                                       line('  UTC-04:00 / EDT', 'muted')],
                 'city, zone, or UTC offset')
    if component == 'RangeSlider':
        low = 'O' if ascii_mode else '◆'
        return p('Confidence range', [line('0  '+fill*4+low+empty*12+low+fill*4+'  100', 'accent'),
                                      line('minimum: 20    maximum: 80', 'text')],
                 'tab endpoint / '+move+' adjust')
    if component == 'SortableSelect':
        return p('Validation priority', [option('1. Required fields',True),
                                         line('  2. Schema'),
                                         line('  3. Custom rules')],
                 move+' move / ctrl+'+move+' reorder')
    if component == 'KeyChordInput':
        return p('Open command palette', [line(arrow+' [ Ctrl+K, Ctrl+C ]', 'accent'),
                                          line('2-key chord / no conflict', 'success')],
                 'esc clear / enter bind')
    if component == 'StepperForm':
        rows = [line('1  Project     orbit', 'success'),
                line(arrow+' 2  Runtime     [Dart]', 'accent', focused),
                line('3  Features'),
                line('4  Review')]
        return p('New workspace',rows,'enter next / alt+left back')
    if component == 'CommandPalette':
        return p('Run a command', [line('> new pr'+cursor, 'accent'),
                                   option('Project: New',True),
                                   line('  Profile: New'),
                                   line('  Preferences: Open', 'muted')],
                 'type to filter / enter run')


WIDTH, HEIGHT = 1800, 4300
MARGIN, GAP = 64, 24
CARD_W = (WIDTH - MARGIN*2 - GAP*2) / 3
CARD_H = 240
FONT = "'Cascadia Mono', 'Consolas', 'DejaVu Sans Mono', monospace"


def make_sheet(index, name, slug, mode, description, palette):
    page, surface, fg, muted, accent, selected, success, error, rule = palette
    colors = dict(text=fg, muted=muted, accent=accent, success=success, error=error, rule=rule)
    parts = [f'''<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}" role="img" aria-labelledby="title desc">
<title id="title">{escape(name)} — Prompty CLI component theme</title>
<desc id="desc">Throwaway visual prototype. {escape(description)} All {len(COMPONENTS)} terminal components, with representative static states and a breathing row between selection titles and choices. {escape(NOTES[mode])}.</desc>
<rect width="{WIDTH}" height="{HEIGHT}" fill="{page}"/>
<style>text{{font-family:{FONT};font-variant-ligatures:none;white-space:pre}} .editorial{{font-family:Inter,'Segoe UI',sans-serif}} text{{font-kerning:none}}</style>''']
    def text(x,y,value,color=fg,size=18,cls='',weight=400):
        cell_width = f' textLength="{len(value)*size*0.6:g}" lengthAdjust="spacingAndGlyphs"' if value and cls != 'editorial' else ''
        parts.append(f'<text x="{x:g}" y="{y:g}" fill="{color}" font-size="{size}" font-weight="{weight}" class="{cls}" xml:space="preserve"{cell_width}>{escape(value)}</text>')
    text(64,58,'PROMPTY  /  TERMINAL DESIGN STUDIES', muted,17)
    text(1640,58,f'{index:02} / {len(SPECS)}',accent,18)
    text(60,150,name,fg,80,'editorial',650)
    text(64,199,description,muted,24,'editorial')
    text(64,245,NOTES[mode],accent,17)
    # Palette swatches document actual terminal tokens, not decorative gradients.
    for n, color in enumerate([surface,fg,muted,accent,success,error]):
        parts.append(f'<rect x="{1450+n*46}" y="115" width="32" height="32" fill="{color}" stroke="{rule}"/>')
    text(1450,175,'TRUECOLOR',muted,14)
    text(1450,201,'STATIC SPECIMENS',muted,14)
    # Section navigation doubles as internal selection titles. Each has a quiet
    # line to its three specimen columns, distinct from the question/choice gap.
    section_tops = [325,875,1425,1975,2525,3075]
    for n,top in enumerate(section_tops):
        parts.append(f'<path d="M64 {top-18} H1736" stroke="{rule}"/>')
    parts.append(f'<path d="M64 277 H1736" stroke="{rule}"/>')
    starts = [(0,6,325,'01 / INPUT','Capture an answer'),
              (6,12,875,'02 / CHOICE','Room between the question and options'),
              (12,18,1425,'03 / INDIVIDUAL INPUT','One value. One focused interaction.'),
              (18,22,1975,'04 / FEEDBACK','One task or many, at a glance'),
              (22,31,2525,'05 / SPECIALIZED VALUES','Structured values with useful context'),
              (31,len(COMPONENTS),3075,'06 / FLOWS & NAVIGATION','Files, priorities, shortcuts, and actions')]
    for start,end,top,title,subtitle in starts:
        text(64,top,title,accent,18,weight=650)
        text(440,top,subtitle,muted,18,'editorial')
        for j in range(start,end):
            local = j-start
            x = MARGIN+(CARD_W+GAP)*(local%3)
            y = top+26+(CARD_H+18)*(local//3)
            comp,state = COMPONENTS[j]
            parts.append(f'<g id="{comp}"><rect x="{x:g}" y="{y:g}" width="{CARD_W:g}" height="{CARD_H}" fill="{surface}" stroke="{rule}"/>')
            text(x+20,y+29,f'{j+1:02}  {comp}',fg,17,weight=650)
            # State captions are editorial metadata, not terminal output.
            text(x+20,y+52,state.upper(),muted,12)
            rows = specimen(mode,comp)
            baseline = y+88
            for rownum, (value,role,active) in enumerate(rows):
                yy = baseline+rownum*19.5
                if active:
                    # A reverse-video row is terminal-realistic, unlike web shadows/radii.
                    boxed = mode in ('box', 'round', 'double')
                    rx = x+22+10.2 if boxed else x+20
                    rw = (len(value)-2)*10.2 if boxed else CARD_W-40
                    parts.append(f'<rect x="{rx:g}" y="{yy-15:g}" width="{rw:g}" height="19.5" fill="{accent}"/>')
                text(x+22,yy,value, selected if active else colors[role],17)
            parts.append('</g>')
    parts.append(f'<path d="M64 4160 H1736" stroke="{rule}"/>')
    text(64,4197,'THROWAWAY PROTOTYPE  /  NO THEME SELECTED YET',muted,15)
    text(64,4233,f'{len(COMPONENTS)} components · {len(SPECS)} directions · terminal-native primitives',muted,15,'editorial')
    text(1360,4233,f'example / {slug}.svg',accent,15)
    parts.append('</svg>')
    return '\n'.join(parts)


manifest = []
for i, (name,slug,mode,description,palette) in enumerate(SPECS,1):
    filename = f'{i:02}-{slug}.svg'
    (ASSETS / filename).write_text(make_sheet(i,name,slug,mode,description,palette),encoding='utf-8')
    manifest.append(dict(number=i,name=name,id=slug,mode=mode,description=description,grammar=NOTES[mode],palette=palette,components=[name for name,_ in COMPONENTS],width=WIDTH,height=HEIGHT,svg='sheets/'+filename))
(ROOT / 'themes.js').write_text('// Generated throwaway prototype data.\nwindow.THEMES = '+json.dumps(manifest,ensure_ascii=False,indent=2)+';\n',encoding='utf-8')
print(f'Generated {len(manifest)} SVG sheets, each with {len(COMPONENTS)} components, in {ASSETS}')

# Structure-only view: isolate the actual prompt grammars from colour palettes.
# These names and explanations describe the fifteen distinct rendering modes.
STRUCTURE_INFO = {
    'rail': ('Continuous rail', 'A vertical spine links the question, breathing space, choices, and help.', 'Sequential prompts and focused selections'),
    'minimal': ('Conversational inline', 'The question and answer read like a conversation, with almost no frame.', 'Friendly defaults and lightweight flows'),
    'ascii': ('ASCII console', 'A question mark, indentation, and explicit ASCII symbols carry every state.', 'Restricted terminals and portable output'),
    'box': ('Square enclosure', 'A ruled enclosure contains the title and choices; the focused row reverses colour.', 'Contained forms and visually grouped decisions'),
    'bracket': ('Bracketed question', 'The title sits in a short bracketed band above compact, indented answers.', 'Warm, compact command-line interactions'),
    'round': ('Rounded enclosure', 'Rounded Unicode corners soften an otherwise complete terminal frame.', 'Friendly forms with clear boundaries'),
    'form': ('Fixed-label form', 'Uppercase field labels, a rule, and a left edge create an instrument-panel rhythm.', 'Configuration and dense data entry'),
    'chevron': ('Forward chevron', 'A leading chevron and a directional hint keep the interaction moving forward.', 'Fast setup flows and action-oriented prompts'),
    'plain': ('Plain text', 'A bare question, indentation, and explicit text symbols provide the entire vocabulary.', 'Monochrome and minimal terminal environments'),
    'double': ('Double enclosure', 'Heavy double rules and reverse-video selection make boundaries unmistakable.', 'High-energy tools and strongly grouped decisions'),
    'branch': ('Branching rail', 'The title branches into a vertical context line that continues through the options.', 'Nested configuration and hierarchical flows'),
    'line': ('Underlined question', 'A restrained title rule separates the question without enclosing the response.', 'Calm forms and long interactive sessions'),
    'block': ('Reverse-video label', 'An uppercase, filled label establishes hierarchy before indented terminal rows.', 'Decisive wizards and high-contrast workflows'),
    'ledger': ('Numbered ledger', 'A numbered step, dotted rule, and indented answers create an auditable sequence.', 'Repeatable setup and review-oriented forms'),
    'colon': ('Key:value diagnostic', 'Machine-like field names and explicit hint prefixes expose the structure.', 'Developer tools and diagnostic interactions'),
}
structure_manifest = []
for number, (mode, (title, description, best_for)) in enumerate(STRUCTURE_INFO.items(), 1):
    users = [dict(id=slug, name=name, number=i)
             for i, (name, slug, candidate, _, _) in enumerate(SPECS, 1)
             if candidate == mode]
    palette = next(spec[4] for spec in SPECS if spec[2] == mode)
    _, surface, fg, muted, accent, selected, success, error, rule = palette
    structure_manifest.append(dict(
        number=number, id=mode, title=title, description=description,
        bestFor=best_for, themes=users, surface=surface,
        colors=dict(text=fg, muted=muted, accent=accent, selected=selected,
                    success=success, error=error, rule=rule),
        specimens={component: [dict(text=value, role=role, selected=active)
                              for value, role, active in specimen(mode, component)]
                   for component in ('Select', 'TextInput', 'StepperForm', 'MultiSpinner')},
    ))
(ROOT / 'structures.js').write_text(
    '// Generated throwaway structure data. Source: prompt() and specimen().\n'
    'window.STRUCTURES = '+json.dumps(structure_manifest, ensure_ascii=False, indent=2)+';\n',
    encoding='utf-8')
print(f'Generated {len(structure_manifest)} unique prompt structures in structures.js')
