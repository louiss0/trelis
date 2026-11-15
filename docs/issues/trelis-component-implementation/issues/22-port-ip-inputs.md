# 22: Deliver PortInput and IPAddressInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver strict local numeric port and IP address entry. PortInput defaults to ASCII decimal 1–65535 with explicit zero semantics. IPAddressInput supports IPv4/IPv6 addresses, explicit address-with-prefix CIDR and explicit scoped IPv6 without hostname resolution or environmental claims.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] PortInput rejects signs, grouping, fractions, out-of-range values and implicit socket binding; zero requires explicit explained automatic-allocation opt-in.
- [x] IPv4 uses strict four-decimal-octet syntax; legitimate IPv6 forms are accepted without requiring canonical spelling or URL-style bracket extraction.
- [x] CIDR mode validates family-specific prefix bounds and preserves address host bits rather than silently converting to a network.
- [x] Scoped IPv6 is explicit, preserves and labels zone identity separately, and does not apply URL escaping or discard the zone.
- [x] All drafts remain correctable, and no accepted value implies port availability, address reachability, interface existence or future operation success.
