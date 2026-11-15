# 23: Deliver URLInput and EmailInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver strict absolute URL entry under explicitly allowed scheme profiles and one modern bare transport email address. Preserve accepted spelling and meaningful case/quoting, provide explicit internationalized-domain interpretation, and keep credential safety, SMTPUTF8 and local-versus-network validation boundaries clear.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] URLInput requires an explicit allowed absolute scheme/profile, rejects relative/base-guessed input and repair-dependent malformed forms, and applies scheme-specific structure rather than generic parser acceptance.
- [x] All embedded URL userinfo is rejected with redacted errors; accepted URL spelling and path/query semantics are preserved while interpreted/canonical forms are labeled separately.
- [x] Internationalized DNS hosts use a declared versioned UTS #46 nontransitional/IDNA validation profile, not Punycode alone, with separate Unicode/ASCII interpretation where useful.
- [x] EmailInput accepts one bare SMTP transport address including quoted local parts/address literals, excluding display-name/header/folding/list forms and preserving local-part case.
- [x] Unicode domains are supported, Unicode local parts require explicit SMTPUTF8 opt-in, transport octet limits are enforced separately from graphemes, and neither component performs reachability/deliverability/ownership checks implicitly.
