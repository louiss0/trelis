# Screen-reader detection and terminal locality

**Status:** Bounded primary-source research for the adaptive presentation design. This is not a tested native implementation or a claim that any API can establish that a particular terminal's output is being read by a screen reader.

## Question

Which documented native hints can a Dart terminal application use, and what evidence establishes whether its output is consumed locally? The design requires explicit on/off overrides and treats native hints as best effort, not a substitute for user control.

## Native hints

### Windows

[`SystemParametersInfo` with `SPI_GETSCREENREADER`](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow) retrieves a system screen-reader parameter through a `BOOL` output. Microsoft explains that accessibility aids typically set this parameter, but [Narrator does not set it](https://learn.microsoft.com/en-us/windows/win32/winauto/screen-reader-parameter). A false result therefore does not establish that no screen reader is in use; a positive result does not establish that this terminal is being read with it. A failed API call must also be distinguished from a successful false result.

Dart's [`DynamicLibrary.open`](https://api.dart.dev/dart-ffi/DynamicLibrary/DynamicLibrary.open.html) and [`DynamicLibrary.lookup`](https://api.dart.dev/dart-ffi/DynamicLibrary/lookup.html) provide a possible FFI route to native functions. This establishes feasibility in principle, not a verified Windows binding: ABI declarations, output allocation, cleanup, platform availability, and error handling still need implementation and testing.

### macOS

Apple documents [`NSWorkspace.isVoiceOverEnabled`](https://developer.apple.com/documentation/appkit/nsworkspace/isvoiceoverenabled?language=objc), a VoiceOver-specific state. Its existence does not establish a tested Dart terminal integration, detection of other assistive technology, or that this terminal's output is being consumed using VoiceOver. Availability, native bridging, session scope, and remote behavior require verification.

### Linux

The bounded search examined GNOME ATK/AT-SPI documentation, including the [`Atk.Object::notification` API](https://docs.gtk.org/atk/signal.Object.notification.html), but did not establish an authoritative general-purpose screen-reader-running detector suitable for this terminal use case. This is a limit of the investigation, not proof that no such mechanism exists.

## Locality is a separate problem

- OpenSSH documents `SSH_CONNECTION` and `SSH_TTY` as session environment variables; `SSH_TTY` is not set without an allocated TTY. Their presence can provide evidence of SSH provenance, but their absence cannot prove locality. See [OpenSSH `ssh(1)`](https://man.openbsd.org/ssh.1).
- Windows [`SM_REMOTESESSION`](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getsystemmetrics) describes a Terminal Services client-session condition, not every remote-output path. Microsoft documents an exception involving RemoteFX vGPU and the limitations of this check in [Detecting the Remote Desktop Services environment](https://learn.microsoft.com/en-us/windows/win32/termserv/detecting-the-terminal-services-environment).
- tmux maintains session environments and may have multiple attached clients; see the [tmux FAQ](https://github.com/tmux/tmux/wiki/FAQ). **Inference:** a pane's inherited environment cannot reliably identify every current or future person viewing its output, especially after reattachment or with multiple viewers. Nested transports, containers, and forwarding create similar uncertainty.

A TTY, terminal name, missing SSH variables, or `SM_REMOTESESSION == 0` alone is not sufficient evidence that the person consuming output is local. This investigation has not established a universal positive locality test. The design's “reasonably known to be local” rule therefore still needs concrete evidence criteria; detected remote or ambiguous paths should not be silently treated as local.

## Candidate indicators (bounded evidence)

- **OpenSSH:** [`SSH_CONNECTION`, `SSH_CLIENT`, and `SSH_TTY`](https://man.openbsd.org/ssh#ENVIRONMENT) are documented OpenSSH session variables. Presence is consistent with SSH provenance; absence does not rule out SSH, and inherited or manually supplied values are not authenticated evidence of a live connection.
- **tmux:** tmux's [pane-spawning source](https://github.com/tmux/tmux/blob/master/spawn.c) sets `TMUX` and `TMUX_PANE`. Their presence is consistent with descent from a tmux pane, but inheritance, reattachment, multiple clients, cleared environments, or nesting prevent them from proving current viewers or locality.
- **GNU screen:** Its [environment documentation](https://www.gnu.org/software/screen/manual/html_node/Environment.html) describes `STY` and `WINDOW`. These identify screen session/window context when present, not current attachment or ultimate viewer locality; absence is not proof of a non-screen session.
- **Windows RDP:** [`WTSQuerySessionInformation` and `WTSClientProtocolType`](https://learn.microsoft.com/en-us/windows/win32/api/wtsapi32/ne-wtsapi32-wts_info_class) can identify the queried Windows session's client protocol; an RDP result is not itself proof of an actively connected client. [`WTSConnectState`](https://learn.microsoft.com/en-us/windows/win32/api/wtsapi32/ne-wtsapi32-wts_connectstate_class) is a separate observation. Errors are unknown, and neither API describes all nested remote paths.
- **Containers:** The [systemd Container Interface](https://systemd.io/CONTAINER_INTERFACE/) specifies a `container` variable in the container manager's PID 1 environment, not necessarily every process, and is not a universal runtime guarantee. [`systemd-detect-virt --container`](https://www.freedesktop.org/software/systemd/man/latest/systemd-detect-virt.html) is systemd-specific; a nonzero status does not prove the absence of a container. No universal contract was established for `/.dockerenv` or a particular cgroup string. A detected container does not itself establish whether a user is local or remote.

These are indicators of different layers, not authentication or proof of the ultimate viewer's location. The environment can be stale, altered, or absent. Windows API outcomes describe particular Windows session properties; nested transports remain possible.

## Consequences for design and testing

- Keep native screen-reader hints separate from locality classification. A positive native signal can contribute an automatic hint only when the agreed locality criteria are met; false, failed, and unknown observations do not veto an affirmative application hint.
- Preserve explicit on/off control and the agreed once-per-shared-session resolution. Document that automatic detection can miss Narrator and remote screen-reader users.
- Test resolution with synthetic positive, negative, failure, and unknown signals, including local, remote, and ambiguous locality; exercise conflicts with application hints and explicit preferences.
- Validate any actual native bindings and locality assumptions on the supported OS and terminal combinations. Include Windows Narrator and another reader, SSH, remote desktop, containers, multiplexers, reattachment, and multiple viewers where relevant. An OS signal or passing synthetic test does not establish usable spoken output.
- Further research is needed to define defensible positive locality evidence, verify the macOS native bridge and platform scope, and identify any supported Linux hints. Do not infer general absence from this bounded survey.
