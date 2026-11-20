/// Internal vocabulary for a bounded OSC background query.
///
/// The query is written by the owning session and its reply is parsed inside
/// the session's existing reader. This library performs no terminal I/O and is
/// not exported from the public barrel.
library;

import 'dart:math' as math;

/// The xterm OSC 11 request for the current text background colour.
const String osc11BackgroundRequest = '\x1b]11;?\x07';

/// The fixed library-selected bound for one background query.
const Duration backgroundQueryTimeout = Duration(milliseconds: 250);

/// The usable observation from one background query.
enum BackgroundQueryResult { light, dark, unavailable }

const String _responsePrefix = '\x1b]11;rgb:';
const int _bel = 0x07;
const int _escape = 0x1b;
const int _backslash = 0x5c;

/// Returns the end index of the first OSC terminator in [value], if present.
///
/// Both BEL and the two-byte string terminator are accepted. The search starts
/// after `ESC ]` so an escape byte inside a payload cannot terminate it early.
int? oscTerminatorEnd(String value) {
  for (var index = 2; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit == _bel) return index + 1;
    if (unit == _escape &&
        index + 1 < value.length &&
        value.codeUnitAt(index + 1) == _backslash) {
      return index + 2;
    }
  }
  return null;
}

/// Whether [value] can still become a valid OSC 11 background response.
///
/// Used only while a query is waiting, so a partial reply stays in the reader
/// until it completes or the query times out. Anything else is ordinary input.
bool isOsc11BackgroundPrefix(String value) {
  if (_responsePrefix.startsWith(value)) return true;
  if (!value.startsWith(_responsePrefix)) return false;
  final tail = value.substring(_responsePrefix.length);
  if (tail.length > 16) return false;
  final groups = tail.split('/');
  if (groups.length > 3) return false;
  return groups.every(
    (group) => group.length <= 4 && group.codeUnits.every(_isHexDigit),
  );
}

/// Parses one complete OSC 11 response, returning null when it is not usable.
///
/// Malformed and unsolicited replies stay in the input stream; only a valid
/// reply to a waiting query may be consumed.
BackgroundQueryResult? parseOsc11BackgroundResponse(String raw) {
  final end = oscTerminatorEnd(raw);
  if (end == null || end != raw.length) return null;
  final terminator = raw.endsWith('\x1b\\') ? 2 : 1;
  final body = raw.substring(2, raw.length - terminator);
  final match = RegExp(
    r'^11;rgb:([0-9a-fA-F]{1,4})/([0-9a-fA-F]{1,4})/([0-9a-fA-F]{1,4})$',
  ).firstMatch(body);
  if (match == null) return null;
  final luminance =
      0.2126 * _channelLuminance(match.group(1)!) +
      0.7152 * _channelLuminance(match.group(2)!) +
      0.0722 * _channelLuminance(match.group(3)!);
  return luminance > 0.5
      ? BackgroundQueryResult.light
      : BackgroundQueryResult.dark;
}

bool _isHexDigit(int unit) =>
    (unit >= 0x30 && unit <= 0x39) ||
    (unit >= 0x41 && unit <= 0x46) ||
    (unit >= 0x61 && unit <= 0x66);

double _channelLuminance(String hex) {
  final maximum = (1 << (hex.length * 4)) - 1;
  final srgb = int.parse(hex, radix: 16) / maximum;
  final linear = srgb <= 0.04045
      ? srgb / 12.92
      : math.pow((srgb + 0.055) / 1.055, 2.4);
  return linear.toDouble();
}
