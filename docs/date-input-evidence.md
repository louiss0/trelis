# DateInput implementation evidence

## Bounded date-only arithmetic qualification

`prompty-civil-arithmetic-v1` is in-package integer arithmetic, not a wrapper
around ICU or an instant-based calendar. Its explicit Gregorian profile is
proleptic CE 0001 through 9999; the Buddhist profile is restricted to the
modern January-based BE 2484 through 9999. For these explicitly declared profiles, the qualified rule set has Gregorian
month identity M01-M12, no intercalary month, and the conventional Gregorian
leap rule. The latter maps BE year to proleptic Gregorian year by subtracting 543.

Source inspected: [ICU release 76.1 buddhcal.cpp](https://github.com/unicode-org/icu/blob/release-76-1/icu4c/source/i18n/buddhcal.cpp),
`kBuddhistEraStart = -543`, `handleGetExtendedYear` and
`handleComputeFields`. This source establishes ICU's year mapping, not that
this package links ICU or qualifies ICU historical cutovers. The implementation
uses only dates from 1941 onward in the Buddhist profile and has no historical
cutover. Accepted results identify the input era, calendar, month identity and
provider as well as their separately encoded Gregorian civil fields.

`test/date_input_windows_calendar_test.dart` independently obtains Buddhist
fields from Windows .NET `ThaiBuddhistCalendar` for 1941-01-01, 2000-02-29,
2024-02-29, 2100-03-01 and 9456-12-31, then converts those fields through the
public DateInput boundary and compares the resulting ISO fields. Boundary tests
also reject pre-2484 Buddhist years and invalid leap days. The separate
`dart test test/date_input_windows_cycle_test.dart` check passed on this host:
it compares the first and last day of every month in a complete 400-year
Gregorian cycle (9,600 dates) against .NET ThaiBuddhistCalendar. This is
bounded cross-check evidence, not an exhaustive comparison of every date. The
qualification is limited to the stated arithmetic rules and ranges; it does not
qualify other Buddhist variants, historical Thai new-year conventions, other
provider versions, or platform preference adapters.

## Preference adapters

Windows reads effective `GetLocaleInfoEx` user overrides twice. Linux glibc
uses an isolated `newlocale` LC_TIME object and `nl_langinfo_l`, accepting only
numeric full-year patterns with no alternate-era or alternate-digit fields.
The glibc item indices correspond to [glibc 2.39 langinfo.h](https://github.com/bminor/glibc/blob/glibc-2.39/locale/langinfo.h).
macOS uses current Foundation locale, NSDateFormatter short style and calendar,
and NSNumberFormatter digit information. Unknown, incomplete, short-year or
unmapped profiles fail closed. Slash entry deliberately replaces native
separators. Neither Linux nor macOS adapters were executed on this host.

## Execution evidence and limits

On this Windows host, OS version 10.0.26200.0, Dart 3.13.2 windows_x64,
`dart test test/date_input_windows_test.dart test/date_input_windows_calendar_test.dart`
reported `All tests passed!` for the effective M/d/yyyy, calendar 1, ASCII
digits setting and the .NET calendar vectors. Scripted interaction tests cover
slash traversal, adjustment retaining an invalid dependent day, explicit review,
EOF at review, and preventing identified paste from submitting review commands.
The redirected native DateInput check verifies that a rich prompt returns
unavailable for redirected input; it does not verify an interactive console.
These are automated checks, not Windows Terminal or NVDA task completion.
The DateInput component still requires recorded human nonvisual task evidence
in the whole-library ticket 32 gate; no accessibility qualification is claimed.
