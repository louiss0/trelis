# Cron preview evidence (partial qualification)

This is evidence for the fixtures currently run, **not** a claim of full Cronie,
Quartz, IANA-provider, or scheduler conformance. A preview is civil-time
matching, not execution, misfire, clock-change, or delivery emulation.

## Provider identity

The direct dependency in `pubspec.yaml` is exactly `timezone: 0.11.2`. The
installed package's generated `lib/data/latest_all.dart` identifies its actual
database as **2026e**. This generated file is authoritative for the loaded
snapshot; the package README says 2025c and is stale for this installed copy.
On this machine `Get-FileHash -Algorithm SHA256` reported:

- `lib/data/latest_all.dart`:
  `C50921B38ABB27B4EF4F96508A8243ADE7100E914D5F6EF443E876A7CE9A6C42`
- `lib/src/location.dart`:
  `8217A743B270B9FE8812071451264705A0F0091677AD1C29D7C6DA1231C0587B`

Upstream: [timezone package 0.11.2](https://pub.dev/packages/timezone/versions/0.11.2),
[IANA tz database](https://www.iana.org/time-zones). A separate isolate calls
`initializeTimeZones` from `data/latest_all.dart` and returns the selected
location, keeping package-global database changes out of the caller isolate;
UTC instants are mapped to
civil time with `TZDateTime.from`, using `Location.transitionAt` and
`Location.timeZone` when selecting second or minute candidate resolution.

`test/cron_input_test.dart` checks New York's 2024 spring gap and autumn fold,
Monrovia's 1950 sub-minute offset, and Lagos's 1908 transition into a
sub-minute offset. These are selected examples, not an exhaustive comparison
against the IANA transition corpus. Preview budgets count scanned candidate
instants; a sub-minute offset anywhere in the horizon changes Unix candidate
resolution to seconds. The exact same expression and context can therefore
consume a different budget in different zones or horizons. Expression input is
limited to 4096 UTF-16 code units; supplied answers exceeding that limit are
rejected before field parsing. Zone identifiers are limited to 255 UTF-16 code
units before provider loading. Field sets are compiled once per preview; each
candidate uses set lookups and bounded civil-day calculations. The preview's
work budget counts candidate instants, not parsing, provider initialization,
or elapsed time. `cron_large_step_test.dart` uses a separate process with a
timeout to verify that a maximum integer Unix step does not wrap into an
infinite expansion. This is not a hard wall-clock guarantee.

## Profile sources and checked examples

- Cronie [crontab(5)](https://github.com/cronie-crond/cronie/blob/master/man/crontab.5)
  is rolling `master`, not an implementation version pinned by this project.
  The Unix subset has five fields and excludes command lines and macros.
  `cron_profile_conformance_test.dart` checks the leading-asterisk day-field
  rule (including `*/2`), and Sunday as `0`, `7`, and `SUN`.
- Quartz [2.3.0 tutorial](https://www.quartz-scheduler.org/documentation/quartz-2.3.0/tutorials/tutorial-lesson-06.html)
  documents six required fields, optional year, and special day tokens.
  The implemented preview has explicit local year bounds 1970–2199.
  `cron_input_test.dart` exercises L, LW, L-1, W, # and weekday-L examples;
  `cron_profile_conformance_test.dart` checks standalone weekday L (Saturday),
  L-offset-W, Quartz Sunday numbering and the exclusive question-mark day rule.

Those links describe reference semantics; neither parser was compared against
an exact pinned Cronie or Quartz engine. Known qualification gaps include a
complete syntax and boundary corpus, provider failures other than an unknown
zone, and worst-case wall-clock responsiveness. Initialization's documented
`TimeZoneInitException` and unknown-zone `LocationNotFoundException` are mapped
to provider-error outcomes; the initialization failure is not injected by the
current tests. The package initializer clears and repopulates its isolate's
global database and sets its local zone to UTC. A regression fixture verifies
that preview leaves the caller isolate's local zone unchanged; it does not
qualify all possible interactions with other timezone consumers. Interactive preview
cancellation is covered for Ctrl+C, rich Escape and linear `/cancel` in
`cron_interaction_conformance_test.dart`. The Windows console probe additionally
checks rich Escape and linear `/cancel` while a long preview is active and
compares console state before and after. Do not claim full Quartz compatibility or
whole-ticket acceptance until the remaining gaps are resolved.
