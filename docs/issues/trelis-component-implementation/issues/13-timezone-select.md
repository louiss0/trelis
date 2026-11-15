# 13: Deliver TimezoneSelect

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver searchable selection of a canonical timezone identity from a declared IANA-zone dataset. Search labels/cities/offsets are contextual only; offset previews identify their dataset and reference instant and cannot silently turn the answer into a fixed offset.

**Blocked by:**
- [11: Deliver SearchSelect](11-search-select.md)

**Status:** resolved

- [x] The component returns a canonical zone identity, never a displayed UTC offset as an implicit substitute.
- [x] Search follows the explicit SearchSelect query/result/focus/matching rules with advertised extra searchable fields.
- [x] Dataset version and reference instant behind offset previews are identified and kept coherent.
- [x] Canonical/alias matching, unavailable/unknown zones and stale results preserve identity rather than guessing a replacement.
- [x] Rich and linear acceptance tasks produce the same zone identity without performing network/timezone-environment checks implicitly.
