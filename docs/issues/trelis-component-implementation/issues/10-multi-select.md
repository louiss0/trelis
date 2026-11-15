# 10: Deliver MultiSelect

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver a complete ordered-set selection component in both modes. Focused choices can be inspected and toggled independently, hidden selections survive filtering and are reviewable, count constraints are enforced without partial application, and accepted results retain original option order.

**Blocked by:**
- [09: Deliver Select and Radio](09-select-radio.md)

**Status:** resolved

- [x] Rich Space toggles without submitting and Enter validates/submits; linear stable item numbers toggle one item per line and /done submits.
- [x] Filtering preserves selections by identity, reports total and hidden-selected counts, and /selected reviews the complete selection including hidden items.
- [x] Empty is allowed by default and never means cancellation; configured minimum/maximum constraints are visible and enforced as specified.
- [x] Select visible and Clear visible, including advertised linear commands, affect only enabled items in the full current filtered result set.
- [x] Invalid bulk additions preserve prior state rather than partially applying; final results are identities in original option order.
