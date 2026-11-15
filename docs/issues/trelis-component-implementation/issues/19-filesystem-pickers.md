# 19: Deliver FilePicker and DirectoryPicker

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver read-only public pickers for an existing file or existing directory. Users can browse, navigate parent directories, enter a path directly, refresh, control hidden entries and distinguish Open from Choose without the component mutating the filesystem or opening selected content.

**Blocked by:**
- [09: Deliver Select and Radio](09-select-radio.md)
- [18: Deliver PathInput](18-path-input.md)

**Status:** resolved

- [x] FilePicker accepts only an existing required file and DirectoryPicker only an existing required directory; no save-as or creation behavior is introduced.
- [x] Open and Choose are separate discoverable actions where both are possible, and no Ctrl+Enter requirement exists.
- [x] Rich and linear flows provide direct path entry, parent navigation, refresh and an explicit hidden-item toggle with stable identity/reviewable state.
- [x] Linked-directory traversal is explicit opt-in, visibly labeled, and has cycle/error handling; the starting base is not claimed as a sandbox.
- [x] Access/refresh/stale-reference errors retain context; acceptance rechecks existence/type without claiming race-free future access or filesystem mutation.
