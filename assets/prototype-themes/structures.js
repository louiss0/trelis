// Generated throwaway structure data. Source: prompt() and specimen().
window.STRUCTURES = [
  {
    "number": 1,
    "id": "rail",
    "title": "Continuous rail",
    "description": "A vertical spine links the question, breathing space, choices, and help.",
    "bestFor": "Sequential prompts and focused selections",
    "themes": [
      {
        "id": "signal",
        "name": "Signal",
        "number": 1
      },
      {
        "id": "deep-space",
        "name": "Deep Space",
        "number": 26
      },
      {
        "id": "ultraviolet",
        "name": "Ultraviolet",
        "number": 39
      }
    ],
    "surface": "#191b28",
    "colors": {
      "text": "#e6e8f4",
      "muted": "#a1a7bd",
      "accent": "#b6a2ff",
      "selected": "#191329",
      "success": "#9bddb4",
      "error": "#ff929e",
      "rule": "#3b3d55"
    },
    "specimens": {
      "Select": [
        {
          "text": "┌  Choose a template",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│",
          "role": "rule",
          "selected": false
        },
        {
          "text": "│  ◆ Starter",
          "role": "accent",
          "selected": true
        },
        {
          "text": "│    Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "│    Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "└  ↑/↓ move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "┌  Project name",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│  ◆ orbit▏",
          "role": "accent",
          "selected": false
        },
        {
          "text": "└  enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "┌  New workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│  1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "│  ◆ 2  Runtime     [Dart]",
          "role": "accent",
          "selected": true
        },
        {
          "text": "│  3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "│  4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "└  enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "✓ Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "⠹ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "⠹ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "□ Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 2,
    "id": "minimal",
    "title": "Conversational inline",
    "description": "The question and answer read like a conversation, with almost no frame.",
    "bestFor": "Friendly defaults and lightweight flows",
    "themes": [
      {
        "id": "paper",
        "name": "Paper",
        "number": 2
      },
      {
        "id": "moss",
        "name": "Moss",
        "number": 27
      },
      {
        "id": "obsidian",
        "name": "Obsidian",
        "number": 35
      }
    ],
    "surface": "#faf9f5",
    "colors": {
      "text": "#282d32",
      "muted": "#666b70",
      "accent": "#205cc5",
      "selected": "#ffffff",
      "success": "#277243",
      "error": "#b53535",
      "rule": "#cbc9c1"
    },
    "specimens": {
      "Select": [
        {
          "text": "Choose a template",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "rule",
          "selected": false
        },
        {
          "text": "› Starter",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "  Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "↑/↓ move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "Project name",
          "role": "muted",
          "selected": false
        },
        {
          "text": "› orbit▏",
          "role": "accent",
          "selected": false
        },
        {
          "text": "enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "New workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "› 2  Runtime     [Dart]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "✓ Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "◒ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "◒ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "· Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 3,
    "id": "ascii",
    "title": "ASCII console",
    "description": "A question mark, indentation, and explicit ASCII symbols carry every state.",
    "bestFor": "Restricted terminals and portable output",
    "themes": [
      {
        "id": "mainframe",
        "name": "Mainframe",
        "number": 3
      },
      {
        "id": "terminal-amber",
        "name": "Terminal Amber",
        "number": 23
      },
      {
        "id": "terminal-green",
        "name": "Terminal Green",
        "number": 43
      }
    ],
    "surface": "#0d1a10",
    "colors": {
      "text": "#b2e9b9",
      "muted": "#81a989",
      "accent": "#90f6a3",
      "selected": "#0d1a10",
      "success": "#90f6a3",
      "error": "#ffb184",
      "rule": "#365740"
    },
    "specimens": {
      "Select": [
        {
          "text": "? CHOOSE A TEMPLATE",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  > Starter",
          "role": "accent",
          "selected": false
        },
        {
          "text": "    Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "    Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "  -- up/down move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "? PROJECT NAME",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  > orbit_",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  -- enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "? NEW WORKSPACE",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "  > 2  Runtime     [Dart]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "  4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "  -- enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "[x] Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "/ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "/ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "[ ] Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 4,
    "id": "box",
    "title": "Square enclosure",
    "description": "A ruled enclosure contains the title and choices; the focused row reverses colour.",
    "bestFor": "Contained forms and visually grouped decisions",
    "themes": [
      {
        "id": "blueprint",
        "name": "Blueprint",
        "number": 4
      },
      {
        "id": "porcelain",
        "name": "Porcelain",
        "number": 16
      },
      {
        "id": "sandstone",
        "name": "Sandstone",
        "number": 32
      }
    ],
    "surface": "#102c4b",
    "colors": {
      "text": "#e0efff",
      "muted": "#95b6d6",
      "accent": "#74d7ff",
      "selected": "#102c4b",
      "success": "#9de4d0",
      "error": "#ffb5ae",
      "rule": "#386387"
    },
    "specimens": {
      "Select": [
        {
          "text": "┌ Choose a template ───────────────────────┐",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│                                          │",
          "role": "rule",
          "selected": false
        },
        {
          "text": "│ ▸ Starter                                │",
          "role": "accent",
          "selected": true
        },
        {
          "text": "│   Library                                │",
          "role": "text",
          "selected": false
        },
        {
          "text": "│   Workspace                              │",
          "role": "text",
          "selected": false
        },
        {
          "text": "└──────────────────────────────────────────┘",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  ↑/↓ move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "┌ Project name ────────────────────────────┐",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│ ▸ orbit▏                                 │",
          "role": "accent",
          "selected": false
        },
        {
          "text": "└──────────────────────────────────────────┘",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "┌ New workspace ───────────────────────────┐",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│ 1  Project     orbit                     │",
          "role": "success",
          "selected": false
        },
        {
          "text": "│ ▸ 2  Runtime     [Dart]                  │",
          "role": "accent",
          "selected": true
        },
        {
          "text": "│ 3  Features                              │",
          "role": "text",
          "selected": false
        },
        {
          "text": "│ 4  Review                                │",
          "role": "text",
          "selected": false
        },
        {
          "text": "└──────────────────────────────────────────┘",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "■ Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "⠹ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "⠹ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "□ Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 5,
    "id": "bracket",
    "title": "Bracketed question",
    "description": "The title sits in a short bracketed band above compact, indented answers.",
    "bestFor": "Warm, compact command-line interactions",
    "themes": [
      {
        "id": "ember",
        "name": "Ember",
        "number": 5
      },
      {
        "id": "copper",
        "name": "Copper",
        "number": 28
      },
      {
        "id": "clay",
        "name": "Clay",
        "number": 36
      },
      {
        "id": "desert-dusk",
        "name": "Desert Dusk",
        "number": 44
      }
    ],
    "surface": "#2a2119",
    "colors": {
      "text": "#f3e4cf",
      "muted": "#b6a38a",
      "accent": "#ffc16e",
      "selected": "#2a2119",
      "success": "#bbd58f",
      "error": "#ff9680",
      "rule": "#63503c"
    },
    "specimens": {
      "Select": [
        {
          "text": "[ Choose a template ]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  » Starter",
          "role": "accent",
          "selected": false
        },
        {
          "text": "    Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "    Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "  ↑/↓ move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "[ Project name ]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  » orbit▏",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "[ New workspace ]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "  » 2  Runtime     [Dart]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "  4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "  enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "[✓] Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "◐ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "◐ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "[ ] Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 6,
    "id": "round",
    "title": "Rounded enclosure",
    "description": "Rounded Unicode corners soften an otherwise complete terminal frame.",
    "bestFor": "Friendly forms with clear boundaries",
    "themes": [
      {
        "id": "orchid",
        "name": "Orchid",
        "number": 6
      },
      {
        "id": "lavender",
        "name": "Lavender",
        "number": 19
      },
      {
        "id": "matcha",
        "name": "Matcha",
        "number": 34
      },
      {
        "id": "sakura",
        "name": "Sakura",
        "number": 42
      }
    ],
    "surface": "#2c2035",
    "colors": {
      "text": "#f5e8fa",
      "muted": "#bfa5ca",
      "accent": "#eba7f7",
      "selected": "#2c2035",
      "success": "#b5e5c4",
      "error": "#ffaaa6",
      "rule": "#64466f"
    },
    "specimens": {
      "Select": [
        {
          "text": "╭ Choose a template ───────────────────────╮",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│                                          │",
          "role": "rule",
          "selected": false
        },
        {
          "text": "│ ❯ Starter                                │",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│   Library                                │",
          "role": "text",
          "selected": false
        },
        {
          "text": "│   Workspace                              │",
          "role": "text",
          "selected": false
        },
        {
          "text": "╰──────────────────────────────────────────╯",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  ↑/↓ move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "╭ Project name ────────────────────────────╮",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│ ❯ orbit▏                                 │",
          "role": "accent",
          "selected": false
        },
        {
          "text": "╰──────────────────────────────────────────╯",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "╭ New workspace ───────────────────────────╮",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│ 1  Project     orbit                     │",
          "role": "success",
          "selected": false
        },
        {
          "text": "│ ❯ 2  Runtime     [Dart]                  │",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│ 3  Features                              │",
          "role": "text",
          "selected": false
        },
        {
          "text": "│ 4  Review                                │",
          "role": "text",
          "selected": false
        },
        {
          "text": "╰──────────────────────────────────────────╯",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "✓ Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "⠋ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "⠋ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "· Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 7,
    "id": "form",
    "title": "Fixed-label form",
    "description": "Uppercase field labels, a rule, and a left edge create an instrument-panel rhythm.",
    "bestFor": "Configuration and dense data entry",
    "themes": [
      {
        "id": "workbench",
        "name": "Workbench",
        "number": 7
      },
      {
        "id": "slate",
        "name": "Slate",
        "number": 24
      },
      {
        "id": "polar",
        "name": "Polar",
        "number": 37
      }
    ],
    "surface": "#f7f9fc",
    "colors": {
      "text": "#243448",
      "muted": "#5b6c80",
      "accent": "#155fbd",
      "selected": "#ffffff",
      "success": "#24714c",
      "error": "#bb3945",
      "rule": "#b7c4d3"
    },
    "specimens": {
      "Select": [
        {
          "text": "CHOOSE A TEMPLATE FIELD",
          "role": "accent",
          "selected": false
        },
        {
          "text": "------------------------------------------",
          "role": "rule",
          "selected": false
        },
        {
          "text": "|",
          "role": "rule",
          "selected": false
        },
        {
          "text": "| > Starter",
          "role": "accent",
          "selected": true
        },
        {
          "text": "|   Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "|   Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "  up/down move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "PROJECT NAME      FIELD",
          "role": "accent",
          "selected": false
        },
        {
          "text": "------------------------------------------",
          "role": "rule",
          "selected": false
        },
        {
          "text": "| > orbit_",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "NEW WORKSPACE     FIELD",
          "role": "accent",
          "selected": false
        },
        {
          "text": "------------------------------------------",
          "role": "rule",
          "selected": false
        },
        {
          "text": "| 1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "| > 2  Runtime     [Dart]",
          "role": "accent",
          "selected": true
        },
        {
          "text": "| 3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "| 4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "  enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "[x] Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "/ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "/ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "[ ] Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 8,
    "id": "chevron",
    "title": "Forward chevron",
    "description": "A leading chevron and a directional hint keep the interaction moving forward.",
    "bestFor": "Fast setup flows and action-oriented prompts",
    "themes": [
      {
        "id": "tide",
        "name": "Tide",
        "number": 8
      },
      {
        "id": "solar",
        "name": "Solar",
        "number": 25
      },
      {
        "id": "sea-glass",
        "name": "Sea Glass",
        "number": 40
      }
    ],
    "surface": "#102d30",
    "colors": {
      "text": "#e1f5f2",
      "muted": "#93b8b5",
      "accent": "#70e4ce",
      "selected": "#102d30",
      "success": "#a5e1a5",
      "error": "#ffaaa1",
      "rule": "#345e61"
    },
    "specimens": {
      "Select": [
        {
          "text": "❯ Choose a template",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  ❯ Starter",
          "role": "accent",
          "selected": false
        },
        {
          "text": "    Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "    Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "  ↳ ↑/↓ move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "❯ Project name",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  ❯ orbit▏",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  ↳ enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "❯ New workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "  ❯ 2  Runtime     [Dart]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "  4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "  ↳ enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "✓ Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "◓ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "◓ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "· Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 9,
    "id": "plain",
    "title": "Plain text",
    "description": "A bare question, indentation, and explicit text symbols provide the entire vocabulary.",
    "bestFor": "Monochrome and minimal terminal environments",
    "themes": [
      {
        "id": "ink",
        "name": "Ink",
        "number": 9
      },
      {
        "id": "basalt",
        "name": "Basalt",
        "number": 17
      },
      {
        "id": "carbon",
        "name": "Carbon",
        "number": 41
      }
    ],
    "surface": "#191919",
    "colors": {
      "text": "#f5f5f5",
      "muted": "#b2b2b2",
      "accent": "#ffffff",
      "selected": "#101010",
      "success": "#eeeeee",
      "error": "#ffffff",
      "rule": "#5c5c5c"
    },
    "specimens": {
      "Select": [
        {
          "text": "Choose a template?",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  > Starter",
          "role": "accent",
          "selected": false
        },
        {
          "text": "    Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "    Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "  (up/down move / enter select)",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "Project name?",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  > orbit_",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  (enter to continue)",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "New workspace?",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "  > 2  Runtime     [Dart]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "  4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "  (enter next / alt+left back)",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "[x] Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "* Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "* Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "[ ] Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 10,
    "id": "double",
    "title": "Double enclosure",
    "description": "Heavy double rules and reverse-video selection make boundaries unmistakable.",
    "bestFor": "High-energy tools and strongly grouped decisions",
    "themes": [
      {
        "id": "arcade",
        "name": "Arcade",
        "number": 10
      },
      {
        "id": "vinyl",
        "name": "Vinyl",
        "number": 21
      },
      {
        "id": "neon-grid",
        "name": "Neon Grid",
        "number": 31
      }
    ],
    "surface": "#201a37",
    "colors": {
      "text": "#f0ebff",
      "muted": "#b3a4d2",
      "accent": "#c7f36b",
      "selected": "#201a37",
      "success": "#71edc1",
      "error": "#ff9acb",
      "rule": "#655589"
    },
    "specimens": {
      "Select": [
        {
          "text": "╔ Choose a template ═══════════════════════╗",
          "role": "accent",
          "selected": false
        },
        {
          "text": "║                                          ║",
          "role": "rule",
          "selected": false
        },
        {
          "text": "║ » Starter                                ║",
          "role": "accent",
          "selected": true
        },
        {
          "text": "║   Library                                ║",
          "role": "text",
          "selected": false
        },
        {
          "text": "║   Workspace                              ║",
          "role": "text",
          "selected": false
        },
        {
          "text": "╚══════════════════════════════════════════╝",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  ↑/↓ move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "╔ Project name ════════════════════════════╗",
          "role": "accent",
          "selected": false
        },
        {
          "text": "║ » orbit▏                                 ║",
          "role": "accent",
          "selected": false
        },
        {
          "text": "╚══════════════════════════════════════════╝",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "╔ New workspace ═══════════════════════════╗",
          "role": "accent",
          "selected": false
        },
        {
          "text": "║ 1  Project     orbit                     ║",
          "role": "success",
          "selected": false
        },
        {
          "text": "║ » 2  Runtime     [Dart]                  ║",
          "role": "accent",
          "selected": true
        },
        {
          "text": "║ 3  Features                              ║",
          "role": "text",
          "selected": false
        },
        {
          "text": "║ 4  Review                                ║",
          "role": "text",
          "selected": false
        },
        {
          "text": "╚══════════════════════════════════════════╝",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "◆ Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "◈ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "◈ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "◇ Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 11,
    "id": "branch",
    "title": "Branching rail",
    "description": "The title branches into a vertical context line that continues through the options.",
    "bestFor": "Nested configuration and hierarchical flows",
    "themes": [
      {
        "id": "fieldnotes",
        "name": "Fieldnotes",
        "number": 11
      },
      {
        "id": "botanical",
        "name": "Botanical",
        "number": 22
      },
      {
        "id": "forest-floor",
        "name": "Forest Floor",
        "number": 38
      }
    ],
    "surface": "#f5f4e9",
    "colors": {
      "text": "#303d30",
      "muted": "#64715c",
      "accent": "#3d7046",
      "selected": "#ffffff",
      "success": "#3d7046",
      "error": "#ad4331",
      "rule": "#bac4ab"
    },
    "specimens": {
      "Select": [
        {
          "text": "╭─ Choose a template",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│",
          "role": "rule",
          "selected": false
        },
        {
          "text": "│  ↳ Starter",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│    Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "│    Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "└  ↑/↓ move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "╭─ Project name",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│  ↳ orbit▏",
          "role": "accent",
          "selected": false
        },
        {
          "text": "└  enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "╭─ New workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│  1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "│  ↳ 2  Runtime     [Dart]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "│  3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "│  4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "└  enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "[✓] Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "◴ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "◴ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "[ ] Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 12,
    "id": "line",
    "title": "Underlined question",
    "description": "A restrained title rule separates the question without enclosing the response.",
    "bestFor": "Calm forms and long interactive sessions",
    "themes": [
      {
        "id": "nordic",
        "name": "Nordic",
        "number": 12
      },
      {
        "id": "glacier",
        "name": "Glacier",
        "number": 20
      },
      {
        "id": "blue-hour",
        "name": "Blue Hour",
        "number": 33
      }
    ],
    "surface": "#2e3848",
    "colors": {
      "text": "#e9eef5",
      "muted": "#a6b4c8",
      "accent": "#9bd5e0",
      "selected": "#2e3848",
      "success": "#b4d69c",
      "error": "#efa5af",
      "rule": "#52637c"
    },
    "specimens": {
      "Select": [
        {
          "text": "Choose a template",
          "role": "accent",
          "selected": false
        },
        {
          "text": "──────────────────────",
          "role": "rule",
          "selected": false
        },
        {
          "text": "",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  › Starter",
          "role": "accent",
          "selected": false
        },
        {
          "text": "    Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "    Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "  ↑/↓ move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "Project name",
          "role": "accent",
          "selected": false
        },
        {
          "text": "──────────────────────",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  › orbit▏",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "New workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "──────────────────────",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "  › 2  Runtime     [Dart]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "  4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "  enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "✓ Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "◌ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "◌ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "– Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 13,
    "id": "block",
    "title": "Reverse-video label",
    "description": "An uppercase, filled label establishes hierarchy before indented terminal rows.",
    "bestFor": "Decisive wizards and high-contrast workflows",
    "themes": [
      {
        "id": "punch",
        "name": "Punch",
        "number": 13
      },
      {
        "id": "citrus",
        "name": "Citrus",
        "number": 18
      }
    ],
    "surface": "#fffaf2",
    "colors": {
      "text": "#27221f",
      "muted": "#74655c",
      "accent": "#a83e17",
      "selected": "#ffffff",
      "success": "#2e6c42",
      "error": "#b32d35",
      "rule": "#ccb8a7"
    },
    "specimens": {
      "Select": [
        {
          "text": " CHOOSE A TEMPLATE ",
          "role": "accent",
          "selected": true
        },
        {
          "text": "",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  ▶ Starter",
          "role": "accent",
          "selected": true
        },
        {
          "text": "    Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "    Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "  ↑/↓ MOVE / ENTER SELECT",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": " PROJECT NAME ",
          "role": "accent",
          "selected": true
        },
        {
          "text": "  ▶ orbit▏",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  ENTER TO CONTINUE",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": " NEW WORKSPACE ",
          "role": "accent",
          "selected": true
        },
        {
          "text": "  1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "  ▶ 2  Runtime     [Dart]",
          "role": "accent",
          "selected": true
        },
        {
          "text": "  3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "  4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "  ENTER NEXT / ALT+LEFT BACK",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "[X] Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "◑ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "◑ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "[ ] Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 14,
    "id": "ledger",
    "title": "Numbered ledger",
    "description": "A numbered step, dotted rule, and indented answers create an auditable sequence.",
    "bestFor": "Repeatable setup and review-oriented forms",
    "themes": [
      {
        "id": "ledger",
        "name": "Ledger",
        "number": 14
      },
      {
        "id": "typewriter",
        "name": "Typewriter",
        "number": 30
      }
    ],
    "surface": "#f7f0e2",
    "colors": {
      "text": "#42392f",
      "muted": "#776958",
      "accent": "#83562d",
      "selected": "#ffffff",
      "success": "#416a44",
      "error": "#ad3b37",
      "rule": "#c3b398"
    },
    "specimens": {
      "Select": [
        {
          "text": "01 / Choose a template",
          "role": "accent",
          "selected": false
        },
        {
          "text": "..........................................",
          "role": "rule",
          "selected": false
        },
        {
          "text": "",
          "role": "rule",
          "selected": false
        },
        {
          "text": "   > Starter",
          "role": "accent",
          "selected": false
        },
        {
          "text": "     Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "     Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "   note: up/down move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "01 / Project name",
          "role": "accent",
          "selected": false
        },
        {
          "text": "..........................................",
          "role": "rule",
          "selected": false
        },
        {
          "text": "   > orbit_",
          "role": "accent",
          "selected": false
        },
        {
          "text": "   note: enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "01 / New workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "..........................................",
          "role": "rule",
          "selected": false
        },
        {
          "text": "   1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "   > 2  Runtime     [Dart]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "   3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "   4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "   note: enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "[+] Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "/ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "/ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "[-] Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  },
  {
    "number": 15,
    "id": "colon",
    "title": "Key:value diagnostic",
    "description": "Machine-like field names and explicit hint prefixes expose the structure.",
    "bestFor": "Developer tools and diagnostic interactions",
    "themes": [
      {
        "id": "infrared",
        "name": "Infrared",
        "number": 15
      },
      {
        "id": "midnight-mint",
        "name": "Midnight Mint",
        "number": 29
      },
      {
        "id": "ion",
        "name": "Ion",
        "number": 45
      }
    ],
    "surface": "#2d1d23",
    "colors": {
      "text": "#f8e8ed",
      "muted": "#c09fa9",
      "accent": "#ff9a9f",
      "selected": "#2d1d23",
      "success": "#b7d6ad",
      "error": "#ffb16f",
      "rule": "#69434f"
    },
    "specimens": {
      "Select": [
        {
          "text": "ask:choose_a_template",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "rule",
          "selected": false
        },
        {
          "text": "  :: Starter",
          "role": "accent",
          "selected": false
        },
        {
          "text": "     Library",
          "role": "text",
          "selected": false
        },
        {
          "text": "     Workspace",
          "role": "text",
          "selected": false
        },
        {
          "text": "hint:↑/↓ move / enter select",
          "role": "muted",
          "selected": false
        }
      ],
      "TextInput": [
        {
          "text": "ask:project_name",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  :: orbit▏",
          "role": "accent",
          "selected": false
        },
        {
          "text": "hint:enter to continue",
          "role": "muted",
          "selected": false
        }
      ],
      "StepperForm": [
        {
          "text": "ask:new_workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  1  Project     orbit",
          "role": "success",
          "selected": false
        },
        {
          "text": "  :: 2  Runtime     [Dart]",
          "role": "accent",
          "selected": false
        },
        {
          "text": "  3  Features",
          "role": "text",
          "selected": false
        },
        {
          "text": "  4  Review",
          "role": "text",
          "selected": false
        },
        {
          "text": "hint:enter next / alt+left back",
          "role": "muted",
          "selected": false
        }
      ],
      "MultiSpinner": [
        {
          "text": "Preparing workspace",
          "role": "accent",
          "selected": false
        },
        {
          "text": "",
          "role": "text",
          "selected": false
        },
        {
          "text": "[+] Validate config    done",
          "role": "success",
          "selected": false
        },
        {
          "text": "⠸ Install packages   running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "⠸ Compile assets     running",
          "role": "accent",
          "selected": false
        },
        {
          "text": "! Publish preview    failed",
          "role": "error",
          "selected": false
        },
        {
          "text": "[ ] Upload artifacts   waiting",
          "role": "muted",
          "selected": false
        },
        {
          "text": "2 running / 1 failed / 1 waiting",
          "role": "muted",
          "selected": false
        }
      ]
    }
  }
];
