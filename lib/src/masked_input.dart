part of 'text_input.dart';

/// One element of a mask template.
sealed class MaskElement {}

/// An editable grapheme and its caller-declared rule.
final class MaskSlot extends MaskElement {
  MaskSlot(this.description, this.accepts, {this.required = true});
  final String description;
  final bool Function(String) accepts;
  final bool required;
}

/// Literal presentation, not editable data.
final class MaskLiteral extends MaskElement {
  MaskLiteral(this.text);
  final String text;
}

/// A named finite arrangement of editable slots and literals.
final class MaskTemplate {
  MaskTemplate(this.name, List<MaskElement> elements)
    : elements = List.unmodifiable(elements);
  final String name;
  final List<MaskElement> elements;
}

/// The selected template, raw slot data, and formatted representation.
final class MaskedValue {
  MaskedValue(this.template, this.slots, this.formatted);
  final String template;
  final List<String> slots;
  final String formatted;
  String get raw => slots.join();
}

final class MaskedInput {
  MaskedInput(this.label, {required List<MaskTemplate> templates})
    : templates = List.unmodifiable(templates);
  final String label;
  final List<MaskTemplate> templates;

  Future<PromptResult<MaskedValue>> prompt({PromptSource? source}) async {
    if (source is! SuppliedAnswer) return Unavailable('Not implemented.');
    final matches = <MaskedValue>[];
    for (final template in templates) {
      for (final formatted in [false, true]) {
        final chars = source.value.characters.toList();
        final slots = <String>[];
        var offset = 0;
        var valid = true;
        for (final element in template.elements) {
          if (element is MaskLiteral) {
            if (formatted) {
              for (final c in element.text.characters) {
                if (offset >= chars.length || chars[offset++] != c) {
                  valid = false;
                  break;
                }
              }
            }
          } else if (element is MaskSlot) {
            if (offset >= chars.length || !element.accepts(chars[offset])) {
              valid = false;
              break;
            }
            slots.add(chars[offset++]);
          }
        }
        if (valid && offset == chars.length) {
          var i = 0;
          final result = template.elements
              .map((e) => e is MaskLiteral ? e.text : slots[i++])
              .join();
          final value = MaskedValue(
            template.name,
            List.unmodifiable(slots),
            result,
          );
          if (!matches.any(
            (m) => m.template == value.template && m.raw == value.raw,
          )) {
            matches.add(value);
          }
        }
      }
    }
    return matches.length == 1
        ? Accepted(matches.single)
        : Unavailable('Invalid or ambiguous mask.');
  }
}
