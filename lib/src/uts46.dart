/// Pure-Dart Unicode IDNA Compatible Preprocessing (UTS #46), nontransitional
/// processing with STD3 rules, hyphen checks, Bidi and ContextJ/ContextO.
///
/// Tables are generated directly from these Unicode 16.0.0 source files:
/// https://www.unicode.org/Public/idna/16.0.0/IdnaMappingTable.txt
/// https://www.unicode.org/Public/16.0.0/ucd/UnicodeData.txt
/// https://www.unicode.org/Public/16.0.0/ucd/CompositionExclusions.txt
/// https://www.unicode.org/Public/16.0.0/ucd/Scripts.txt
/// https://www.unicode.org/Public/16.0.0/ucd/extracted/DerivedJoiningType.txt
library;

part 'uts46_data.dart';

const uts46UnicodeVersion = '16.0.0';

final class Uts46 {
  const Uts46({this.verifyDnsLength = true});
  final bool verifyDnsLength;

  String toAscii(String input) => _process(input, true);
  String toUnicode(String input) => _process(input, false);

  String _process(String input, bool ascii) {
    final mapped = <int>[];
    for (final codePoint in input.runes) {
      final entry = _find(_uts46Mappings, codePoint);
      if (entry == null) throw const FormatException('Disallowed code point.');
      var kind = entry.kind;
      if (kind == 4) kind = 3;
      if (kind == 5) kind = 2;
      if (kind == 3) throw const FormatException('Disallowed code point.');
      if (kind == 1) continue;
      if (kind == 2) {
        mapped.addAll(entry.mapping);
      } else {
        mapped.add(codePoint);
      }
    }
    final normalized = String.fromCharCodes(_nfc(mapped));
    final labels = normalized.split('.');
    final output = <String>[];
    final bidiDomain = labels.any(
      (label) =>
          label.runes.any((codePoint) {
            final bidi = _bidi(codePoint);
            return bidi == 'R' || bidi == 'AL' || bidi == 'AN';
          }) ||
          label.length >= 4 &&
              label.substring(0, 4).toLowerCase() == 'xn--' &&
              _punyDecode(label.substring(4)).any((codePoint) {
                final bidi = _bidi(codePoint);
                return bidi == 'R' || bidi == 'AL' || bidi == 'AN';
              }),
    );
    for (var i = 0; i < labels.length; i++) {
      final label = labels[i];
      if (label.isEmpty) {
        if (i == labels.length - 1 && labels.length > 1) {
          output.add('');
          continue;
        }
        throw const FormatException('Empty label.');
      }
      var unicodeLabel = label.toLowerCase();
      if (unicodeLabel.length >= 4 &&
          unicodeLabel.substring(0, 4).toLowerCase() == 'xn--') {
        unicodeLabel = String.fromCharCodes(
          _punyDecode(unicodeLabel.substring(4)),
        );
        if (!unicodeLabel.runes.any((c) => c >= 0x80) ||
            String.fromCharCodes(_nfc(unicodeLabel.runes.toList())) !=
                unicodeLabel ||
            _punyEncode(unicodeLabel.runes.toList()) !=
                label.substring(4).toLowerCase()) {
          throw const FormatException('Invalid Punycode label.');
        }
        // A Punycode label must also pass mapping and all validity checks.
        final remapped = _process(unicodeLabel, false);
        if (remapped != unicodeLabel) {
          throw const FormatException('Invalid Punycode label.');
        }
      }
      _validateLabel(unicodeLabel, bidiDomain);
      var result = unicodeLabel;
      if (ascii && result.runes.any((c) => c >= 0x80)) {
        result = 'xn--${_punyEncode(result.runes.toList())}';
      }
      if (ascii) {
        if (result.isEmpty ||
            verifyDnsLength && result.length > 63 ||
            !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(result)) {
          throw const FormatException('Invalid ASCII label.');
        }
      }
      output.add(result);
    }
    final result = output.join('.');
    if (ascii &&
        verifyDnsLength &&
        result.replaceFirst(RegExp(r'\.$'), '').length > 253) {
      throw const FormatException('Domain name is too long.');
    }
    return result;
  }

  void _validateLabel(String label, bool bidiDomain) {
    final cps = label.runes.toList();
    if (cps.length >= 2 && cps[0] == 45 && cps[1] == 45 ||
        cps.length >= 4 && cps[2] == 45 && cps[3] == 45 ||
        cps.first == 45 ||
        cps.last == 45) {
      throw const FormatException('Invalid hyphen position.');
    }
    if (_in(_marks, cps.first) != 0) {
      throw const FormatException('Leading combining mark.');
    }
    _validateContext(cps);
    if (!bidiDomain) return;
    final first = _bidi(cps.first);
    final rtl = first == 'R' || first == 'AL';
    if (!rtl && first != 'L') {
      throw const FormatException('Invalid Bidi label.');
    }
    final allowed = rtl
        ? const {'R', 'AL', 'AN', 'EN', 'ES', 'CS', 'ET', 'ON', 'BN', 'NSM'}
        : const {'L', 'EN', 'ES', 'CS', 'ET', 'ON', 'BN', 'NSM'};
    var hasArabicNumber = false;
    var hasEuropeanNumber = false;
    for (final c in cps) {
      final bidi = _bidi(c);
      if (!allowed.contains(bidi)) {
        throw const FormatException('Invalid Bidi label.');
      }
      hasArabicNumber |= bidi == 'AN';
      hasEuropeanNumber |= bidi == 'EN';
    }
    if (rtl && hasArabicNumber && hasEuropeanNumber) {
      throw const FormatException('Mixed Bidi numbers.');
    }
    final last = cps.reversed
        .map(_bidi)
        .firstWhere((value) => value != 'NSM', orElse: () => '');
    if (rtl
        ? !const {'R', 'AL', 'EN', 'AN'}.contains(last)
        : !const {'L', 'EN'}.contains(last)) {
      throw const FormatException('Invalid Bidi label ending.');
    }
  }

  void _validateContext(List<int> cps) {
    var hasKatakanaMiddleDot = false;
    var hasArabicIndic = false;
    var hasExtendedArabicIndic = false;
    for (var i = 0; i < cps.length; i++) {
      final c = cps[i];
      if (c >= 0x660 && c <= 0x669) hasArabicIndic = true;
      if (c >= 0x6f0 && c <= 0x6f9) hasExtendedArabicIndic = true;
      switch (c) {
        case 0x200c:
          if (i > 0 && _ccc(cps[i - 1]) == 9) break;
          if (i == 0 || i + 1 == cps.length) {
            throw const FormatException('Invalid ZWNJ context.');
          }
          var previous = i - 1;
          while (previous >= 0 && _joining(cps[previous]) == 'T') {
            previous--;
          }
          var next = i + 1;
          while (next < cps.length && _joining(cps[next]) == 'T') {
            next++;
          }
          final before = previous < 0 ? '' : _joining(cps[previous]);
          final after = next == cps.length ? '' : _joining(cps[next]);
          if (!const {'L', 'D'}.contains(before) ||
              !const {'R', 'D'}.contains(after)) {
            throw const FormatException('Invalid ZWNJ context.');
          }
        case 0x200d:
          if (i == 0 || _ccc(cps[i - 1]) != 9) {
            throw const FormatException('Invalid ZWJ context.');
          }
        case 0xb7:
          if (i == 0 ||
              i + 1 == cps.length ||
              cps[i - 1] != 0x6c ||
              cps[i + 1] != 0x6c) {
            throw const FormatException('Invalid middle-dot context.');
          }
        case 0x375:
          if (i == 0 || _in(_scriptGreek, cps[i - 1]) == 0) {
            throw const FormatException('Invalid Greek numeral-sign context.');
          }
        case 0x5f3:
        case 0x5f4:
          if (i == 0 || _in(_scriptHebrew, cps[i - 1]) == 0) {
            throw const FormatException('Invalid Hebrew punctuation context.');
          }
        case 0x30fb:
          hasKatakanaMiddleDot = true;
      }
    }
    if (hasKatakanaMiddleDot &&
        !cps.any(
          (c) =>
              _in(_scriptHiragana, c) != 0 ||
              _in(_scriptKatakana, c) != 0 ||
              _in(_scriptHan, c) != 0,
        )) {
      throw const FormatException('Invalid Katakana middle-dot context.');
    }
    if (hasArabicIndic && hasExtendedArabicIndic) {
      throw const FormatException('Mixed Arabic-Indic digits.');
    }
  }
}

final class _M {
  const _M(this.start, this.end, this.kind, this.mapping);
  final int start;
  final int end;
  final int kind;
  final List<int> mapping;
}

final class _D {
  const _D(this.codePoint, this.mapping);
  final int codePoint;
  final List<int> mapping;
}

final class _C {
  const _C(this.first, this.second, this.composite);
  final int first;
  final int second;
  final int composite;
}

final class _R {
  const _R(this.start, this.end, this.value);
  final int start;
  final int end;
  final Object value;
}

_M? _find(List<_M> table, int c) {
  var low = 0;
  var high = table.length - 1;
  while (low <= high) {
    final middle = (low + high) >> 1;
    final entry = table[middle];
    if (c < entry.start) {
      high = middle - 1;
    } else if (c > entry.end) {
      low = middle + 1;
    } else {
      return entry;
    }
  }
  return null;
}

Object _in(List<_R> table, int c) {
  var low = 0;
  var high = table.length - 1;
  while (low <= high) {
    final middle = (low + high) >> 1;
    final entry = table[middle];
    if (c < entry.start) {
      high = middle - 1;
    } else if (c > entry.end) {
      low = middle + 1;
    } else {
      return entry.value;
    }
  }
  return 0;
}

int _ccc(int c) => _in(_combiningClasses, c) as int;
String _bidi(int c) {
  final value = _in(_bidiClasses, c);
  return value is String ? value : 'L';
}

String _joining(int c) {
  final value = _in(_joiningTypes, c);
  return value is String ? value : 'U';
}

List<int> _nfc(List<int> input) {
  final decomposed = <int>[];
  void decompose(int c) {
    const sBase = 0xac00;
    const lBase = 0x1100;
    const vBase = 0x1161;
    const tBase = 0x11a7;
    const nCount = 588;
    const sCount = 11172;
    final sIndex = c - sBase;
    if (sIndex >= 0 && sIndex < sCount) {
      decomposed.add(lBase + sIndex ~/ nCount);
      decomposed.add(vBase + (sIndex % nCount) ~/ 28);
      if (sIndex % 28 != 0) decomposed.add(tBase + sIndex % 28);
      return;
    }
    var low = 0;
    var high = _canonicalDecompositions.length - 1;
    _D? found;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final entry = _canonicalDecompositions[middle];
      if (c < entry.codePoint) {
        high = middle - 1;
      } else if (c > entry.codePoint) {
        low = middle + 1;
      } else {
        found = entry;
        break;
      }
    }
    if (found == null) {
      decomposed.add(c);
    } else {
      for (final mapped in found.mapping) {
        decompose(mapped);
      }
    }
  }

  for (final c in input) {
    decompose(c);
  }
  for (var i = 1; i < decomposed.length; i++) {
    final c = decomposed[i];
    final cc = _ccc(c);
    if (cc == 0) continue;
    var j = i;
    while (j > 0 && _ccc(decomposed[j - 1]) > cc) {
      decomposed[j] = decomposed[j - 1];
      j--;
    }
    decomposed[j] = c;
  }
  if (decomposed.isEmpty) return decomposed;
  final result = <int>[decomposed.first];
  var starter = 0;
  var previousClass = _ccc(decomposed.first);
  for (var i = 1; i < decomposed.length; i++) {
    final c = decomposed[i];
    final cc = _ccc(c);
    final composite = _compose(result[starter], c);
    if (composite != null && (previousClass < cc || previousClass == 0)) {
      result[starter] = composite;
    } else {
      result.add(c);
      if (cc == 0) starter = result.length - 1;
      previousClass = cc;
    }
  }
  return result;
}

int? _compose(int first, int second) {
  const sBase = 0xac00;
  const lBase = 0x1100;
  const vBase = 0x1161;
  const tBase = 0x11a7;
  if (first >= lBase &&
      first < lBase + 19 &&
      second >= vBase &&
      second < vBase + 21) {
    return sBase + ((first - lBase) * 21 + second - vBase) * 28;
  }
  if (first >= sBase &&
      first < sBase + 11172 &&
      (first - sBase) % 28 == 0 &&
      second > tBase &&
      second < tBase + 28) {
    return first + second - tBase;
  }
  var low = 0;
  var high = _compositions.length - 1;
  while (low <= high) {
    final middle = (low + high) >> 1;
    final entry = _compositions[middle];
    if (first < entry.first || first == entry.first && second < entry.second) {
      high = middle - 1;
    } else if (first > entry.first ||
        first == entry.first && second > entry.second) {
      low = middle + 1;
    } else {
      return entry.composite;
    }
  }
  return null;
}

const _initialN = 128;
const _initialBias = 72;
int _adapt(int delta, int points, bool first) {
  delta = first ? delta ~/ 700 : delta ~/ 2;
  delta += delta ~/ points;
  var k = 0;
  while (delta > 455) {
    delta ~/= 35;
    k += 36;
  }
  return k + (36 * delta) ~/ (delta + 38);
}

String _punyEncode(List<int> input) {
  final output = <int>[];
  var basic = 0;
  for (final c in input) {
    if (c < 128) {
      output.add(c);
      basic++;
    }
  }
  var handled = basic;
  if (basic > 0) output.add(45);
  var n = _initialN;
  var delta = 0;
  var bias = _initialBias;
  while (handled < input.length) {
    var m = 0x10ffff;
    for (final c in input) {
      if (c >= n && c < m) m = c;
    }
    delta += (m - n) * (handled + 1);
    n = m;
    for (final c in input) {
      if (c < n) delta++;
      if (c != n) continue;
      var q = delta;
      for (var k = 36; ; k += 36) {
        final threshold = k <= bias
            ? 1
            : k >= bias + 26
            ? 26
            : k - bias;
        if (q < threshold) break;
        final digit = threshold + (q - threshold) % (36 - threshold);
        output.add(digit + 22 + 75 * (digit < 26 ? 1 : 0));
        q = (q - threshold) ~/ (36 - threshold);
      }
      output.add(q + 22 + 75 * (q < 26 ? 1 : 0));
      bias = _adapt(delta, handled + 1, handled == basic);
      delta = 0;
      handled++;
    }
    delta++;
    n++;
  }
  return String.fromCharCodes(output);
}

List<int> _punyDecode(String input) {
  if (input.isEmpty || !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(input)) {
    throw const FormatException('Invalid Punycode.');
  }
  final chars = input.codeUnits;
  final output = <int>[];
  final delimiter = input.lastIndexOf('-');
  var index = 0;
  if (delimiter >= 0) {
    for (var i = 0; i < delimiter; i++) {
      if (chars[i] >= 128) throw const FormatException('Invalid Punycode.');
      output.add(chars[i]);
    }
    index = delimiter + 1;
  }
  var n = _initialN;
  var i = 0;
  var bias = _initialBias;
  while (index < chars.length) {
    final oldI = i;
    var weight = 1;
    for (var k = 36; ; k += 36) {
      if (index >= chars.length) {
        throw const FormatException('Invalid Punycode.');
      }
      final c = chars[index++];
      final digit = c >= 48 && c <= 57
          ? c - 22
          : c >= 65 && c <= 90
          ? c - 65
          : c >= 97 && c <= 122
          ? c - 97
          : 36;
      if (digit >= 36) throw const FormatException('Invalid Punycode.');
      i += digit * weight;
      final threshold = k <= bias
          ? 1
          : k >= bias + 26
          ? 26
          : k - bias;
      if (digit < threshold) break;
      weight *= 36 - threshold;
    }
    bias = _adapt(i - oldI, output.length + 1, oldI == 0);
    n += i ~/ (output.length + 1);
    i %= output.length + 1;
    if (n > 0x10ffff || n >= 0xd800 && n <= 0xdfff) {
      throw const FormatException('Invalid Punycode.');
    }
    output.insert(i, n);
    i++;
  }
  return output;
}
