/// Internal, immutable presentation content and composition primitives.
///
/// These types deliberately carry display-safe values only. They describe a
/// declaration and its repaired result; they cannot read input, mutate a
/// component, or write to a terminal.
library;

/// Semantic content that a structure may place.
enum PresentationSlot { label, context, body, validation }

/// Text which has been encoded for display and is not terminal instructions.
final class DisplayText {
  DisplayText._(this.value);

  factory DisplayText.from(String text) {
    final escaped = StringBuffer();
    for (final rune in text.runes) {
      final isControl =
          (rune >= 0 && rune <= 0x1f) || (rune >= 0x7f && rune <= 0x9f);
      final isBidi =
          rune == 0x061c ||
          (rune >= 0x200e && rune <= 0x200f) ||
          (rune >= 0x202a && rune <= 0x202e) ||
          (rune >= 0x2066 && rune <= 0x2069);
      if (isControl || isBidi) {
        escaped.write(r'\u{');
        escaped.write(rune.toRadixString(16).toUpperCase().padLeft(4, '0'));
        escaped.write('}');
      } else {
        escaped.writeCharCode(rune);
      }
    }
    return DisplayText._(escaped.toString());
  }

  final String value;
}

/// The sole logical-caret owner in a text-entry presentation.
final class TextInputEditableRegion {
  const TextInputEditableRegion({
    required this.beforeCaret,
    required this.afterCaret,
  });

  final DisplayText beforeCaret;
  final DisplayText afterCaret;
}

/// The display-safe, immutable content supplied by TextInput behavior.
final class TextInputPresentationContent {
  const TextInputPresentationContent({
    required this.label,
    required this.context,
    required this.editable,
    this.validation,
  });

  final DisplayText label;
  final DisplayText context;
  final TextInputEditableRegion editable;
  final DisplayText? validation;

  List<PresentationSlot> get protectedSlots => [
    PresentationSlot.label,
    PresentationSlot.context,
    PresentationSlot.body,
    if (validation != null) PresentationSlot.validation,
  ];

  PresentationContentNode nodeFor(PresentationSlot slot) => switch (slot) {
    PresentationSlot.label => PresentationContentNode.text(slot, label),
    PresentationSlot.context => PresentationContentNode.text(slot, context),
    PresentationSlot.body => PresentationContentNode.editable(editable),
    PresentationSlot.validation => PresentationContentNode.text(
      slot,
      validation!,
    ),
  };
}

/// An immutable structural declaration. Its omissions are diagnosable even
/// though the compositor repairs required content for a running prompt.
final class PresentationDeclaration {
  PresentationDeclaration(Iterable<PresentationSlot> slots)
    : _slots = Set.unmodifiable(slots);

  final Set<PresentationSlot> _slots;

  List<PresentationSlot> diagnoseOmittedProtectedSlots(
    TextInputPresentationContent content,
  ) => [
    for (final slot in content.protectedSlots)
      if (!_slots.contains(slot)) slot,
  ];

  bool places(PresentationSlot slot) => _slots.contains(slot);
}

/// A node in a declaration result. An editable node intentionally has no text.
final class PresentationContentNode {
  const PresentationContentNode.text(this.slot, this.text) : editable = null;

  const PresentationContentNode.editable(this.editable)
    : slot = PresentationSlot.body,
      text = null;

  final PresentationSlot slot;
  final DisplayText? text;
  final TextInputEditableRegion? editable;
}

/// A repaired composition: the safety area follows the body and precedes any
/// optional hints a structure may add.
final class PresentationComposition {
  PresentationComposition({
    required Iterable<PresentationContentNode> body,
    required Iterable<PresentationContentNode> safetyArea,
  }) : body = List.unmodifiable(body),
       safetyArea = List.unmodifiable(safetyArea);

  final List<PresentationContentNode> body;
  final List<PresentationContentNode> safetyArea;

  List<PresentationSlot> get bodySlots =>
      List.unmodifiable(body.map((node) => node.slot));
  List<PresentationSlot> get safetyAreaSlots =>
      List.unmodifiable(safetyArea.map((node) => node.slot));
}

/// Shared protected-content repair for typed presentations.
final class PresentationCompositor {
  const PresentationCompositor();

  PresentationComposition composeTextInput(
    TextInputPresentationContent content,
    PresentationDeclaration declaration,
  ) {
    final omitted = declaration.diagnoseOmittedProtectedSlots(content);
    return PresentationComposition(
      body: [
        for (final slot in content.protectedSlots)
          if (declaration.places(slot)) content.nodeFor(slot),
      ],
      safetyArea: [for (final slot in omitted) content.nodeFor(slot)],
    );
  }
}
