part of 'text_input.dart';

/// Field order for an explicit proleptic Gregorian, full-year override.
enum DateFieldOrder { dayMonthYear, monthDayYear, yearMonthDay }

/// A proleptic Gregorian date without a time or time zone.
final class CivilDate {
  CivilDate._(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;
}

/// Date entry. Automatic system resolution and interactive entry are not yet
/// available; they fail closed rather than guessing a calendar or convention.
final class DateInput {
  DateInput(this.label, {this.order}) {
    if (label.trim().isEmpty || label.runes.any((c) => c < 32 || c == 127)) {
      throw ArgumentError.value(label, 'label');
    }
  }

  final String label;
  final DateFieldOrder? order;

  CivilDate? _parse(String text, DateFieldOrder order) {
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final yearIndex = order == DateFieldOrder.yearMonthDay ? 0 : 2;
    for (var i = 0; i < 3; i++) {
      final pattern = i == yearIndex ? r'^[0-9]{4}$' : r'^[0-9]{1,2}$';
      if (!RegExp(pattern).hasMatch(parts[i])) return null;
    }
    final fields = parts.map(int.parse).toList();
    final year = fields[yearIndex];
    final month =
        fields[switch (order) {
          DateFieldOrder.dayMonthYear => 1,
          DateFieldOrder.monthDayYear => 0,
          DateFieldOrder.yearMonthDay => 1,
        }];
    final day =
        fields[switch (order) {
          DateFieldOrder.dayMonthYear => 0,
          DateFieldOrder.monthDayYear => 1,
          DateFieldOrder.yearMonthDay => 2,
        }];
    if (year < 1 || month < 1 || month > 12 || day < 1) return null;
    final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    final days = <int>[
      31,
      leap ? 29 : 28,
      31,
      30,
      31,
      30,
      31,
      31,
      30,
      31,
      30,
      31,
    ];
    if (day > days[month - 1]) return null;
    return CivilDate._(year, month, day);
  }

  Future<PromptResult<CivilDate>> prompt({
    PromptSource? source,
    PromptMode? mode,
    PromptMode? userPreference,
    PromptMode? applicationPreference,
    Stdout? output,
  }) async {
    final resolvedOrder = order;
    if (resolvedOrder == null) {
      return Unavailable(
        'System date preferences are not yet resolved; an explicit Gregorian field order is required.',
      );
    }
    if (source is! SuppliedAnswer) {
      return Unavailable(
        'Interactive date entry and review are not yet available.',
      );
    }
    final value = _parse(source.value, resolvedOrder);
    if (value == null) return Unavailable('Invalid proleptic Gregorian date.');
    return Accepted(value);
  }
}
