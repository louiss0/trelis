# 24: Deliver ColorInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver textual sRGB color entry with declared hex/RGB/HSL/static-name formats and alpha supported by default. Users can understand and correct values without relying on a swatch, preserve supported precision/source for re-editing, and distinguish actual transparency from absent input.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] The declared CSS Color 4 sRGB subset supports hex, modern/legacy literal RGB/HSL forms, static names, alpha and transparent with alpha last in hex.
- [x] Contextual/system colors, variables, calculations, relative-color syntax and wider color spaces are excluded rather than approximated silently.
- [x] Out-of-range channels, saturation/lightness and alpha are rejected; cyclic hue interpretation is explicit and previewed.
- [x] Supported sRGB/alpha precision and validated source expression survive acceptance/re-editing without implicit 8-bit quantization.
- [x] Rounded hex/swatch displays are labeled approximate supplementary previews, while full textual value/alpha/errors remain available in no-color rich and linear modes.
