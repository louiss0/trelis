/// Internal, immutable presentation content and composition primitives.
///
/// These types deliberately carry display-safe values only. They describe a
/// declaration and its repaired result; they cannot read input, mutate a
/// component, or write to a terminal.
library;

import 'text_measurement.dart';

/// Semantic content that a structure may place.
enum PresentationSlot { label, context, body, validation }

/// Text which has been encoded for display and is not terminal instructions.
///
/// The encoding is [displaySafe], the same policy the layout path measures, so
/// protected content is spelled identically whether it is wrapped or emitted
/// on an unwrapped line.
final class DisplayText {
  DisplayText._(this.value);

  factory DisplayText.from(String text) => DisplayText._(displaySafe(text));

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

/// The identity model a query/results row uses.
///
/// `SearchSelect`, `CommandPalette` and `TimezoneSelect` present choices whose
/// displayed reference identifies the same source choice for the whole prompt.
/// `Autocomplete` presents response-local candidates: the same text can appear
/// at a different position for a different query, so a position is not an
/// identity and no candidate can be accepted after its response is replaced.
enum QueryResultsIdentityModel { sourceStableChoice, responseLocalCandidate }

/// The explicit state of a query/results body.
///
/// [idle] is a query stage with no presented results yet, [loading] is an
/// outstanding asynchronous request whose rows cannot be accepted, [ready] and
/// [empty] are completed responses, and [failure] records that the last request
/// produced no results and editing the query is the retry.
enum QueryResultsPhase { idle, loading, ready, empty, failure }

/// A typed, display-safe accompaniment to a query/results state.
enum QueryResultsNotice {
  /// The response named unknown or duplicate source identities.
  invalidIdentities,

  /// The shown state can only be replaced by editing the query.
  retryByEditing,

  /// A previously focused choice is absent from the current results.
  focusedResultRemoved,

  /// The presented results layer was dismissed without accepting.
  dismissed,
}

/// One immutable, display-safe query/results row.
final class QueryResultRow {
  const QueryResultRow({
    required this.label,
    required this.position,
    this.reference,
    this.focused = false,
    this.isDefault = false,
    this.unavailableReason,
  });

  final DisplayText label;

  /// The displayed ordinal of this row in the current presentation.
  final int position;

  /// The displayed source-stable reference, or null when the row is a
  /// response-local candidate.
  final int? reference;

  final bool focused;
  final bool isDefault;
  final DisplayText? unavailableReason;

  bool get isAvailable => unavailableReason == null;
}

/// The immutable projection a query/results component produces before any
/// structural layout or output.
///
/// Behavior builds this only for a current, open presentation: an obsolete or
/// closed-session response is rejected before projection, so nothing here can
/// describe a stale answer.
final class QueryResultsPresentation {
  QueryResultsPresentation({
    required this.component,
    required this.label,
    required this.query,
    required this.phase,
    required this.identityModel,
    required this.totalResults,
    Iterable<QueryResultRow> rows = const [],
    Iterable<QueryResultsNotice> notices = const [],
    this.page,
    this.pageCount,
  }) : rows = List.unmodifiable(rows),
       notices = List.unmodifiable(notices);

  /// The component identity that produced this projection.
  final String component;
  final DisplayText label;
  final DisplayText query;
  final QueryResultsPhase phase;
  final QueryResultsIdentityModel identityModel;

  /// Results matching the query before any paging.
  final int totalResults;

  final List<QueryResultRow> rows;
  final List<QueryResultsNotice> notices;

  /// The displayed 1-based page, when this component pages its results.
  final int? page;
  final int? pageCount;

  /// Whether a presented row can be accepted in this state.
  bool get canAccept =>
      phase == QueryResultsPhase.ready && rows.any((row) => row.isAvailable);

  /// Whether the only way to obtain results again is a new query.
  bool get retryAvailable => phase == QueryResultsPhase.failure;
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
