# 16: Deliver Slider and RangeSlider

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver precise single-value and two-endpoint input with equivalent rich/linear typed entry and adjustment. Bounds, steps, units, active endpoint and constraints remain textual; values are never silently rounded, clipped or swapped.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Both typed and adjusted values satisfy declared step alignment from minimum, bounds and exact precision constraints; invalid text remains editable.
- [x] Slider focus adjusts with arrows while numeric-editor focus retains ordinary text editing; visible Edit/Submit actions avoid mandatory modifier keys.
- [x] RangeSlider identifies Lower/Upper, uses Tab for endpoint/action traversal, and never swaps endpoint roles.
- [x] Endpoint movement stops at the other endpoint or configured minimum gap; equality follows the configured gap rule and inverted typed ranges remain correctable.
- [x] Linear input supports the same single value or reviewed endpoint pair with explicit submission and no fabricated default.
