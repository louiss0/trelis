import 'package:test/test.dart';
import 'package:trelis/src/state_help_presentation.dart';

void main() {
  group('composable choice state markers', () {
    test(
      'focus, single selection and default show independently in Unicode',
      () {
        final focused = ChoicePresentation(
          label: 'Alpha',
          focused: true,
          selected: false,
        );
        final selected = ChoicePresentation(label: 'Beta', selected: true);
        final defaultChoice = ChoicePresentation(
          label: 'Gamma',
          isDefault: true,
        );

        expect(focused.markers(glyphs: StateGlyphs.unicode).focus, '→');
        expect(focused.markers(glyphs: StateGlyphs.unicode).selection, '○');
        expect(focused.markers(glyphs: StateGlyphs.unicode).defaultMarker, ' ');
        expect(selected.markers(glyphs: StateGlyphs.unicode).selection, '●');
        expect(selected.markers(glyphs: StateGlyphs.unicode).focus, ' ');
        expect(
          defaultChoice.markers(glyphs: StateGlyphs.unicode).defaultMarker,
          '★',
        );
      },
    );

    test('focus, multi-selection and default show independently in ASCII', () {
      final row = ChoicePresentation(
        label: 'Alpha',
        focused: true,
        checked: true,
        isDefault: true,
      );
      final unchecked = ChoicePresentation(label: 'Beta', checked: false);
      final markers = row.markers(glyphs: StateGlyphs.ascii);

      expect(markers.focus, '>');
      expect(markers.selection, 'x');
      expect(markers.defaultMarker, 'D');
      expect(unchecked.markers(glyphs: StateGlyphs.ascii).selection, '-');
    });

    test(
      'all five single-selection styles have distinct Unicode and ASCII pairs',
      () {
        expect(
          SingleSelectionStyle.values.map((style) => style.unicodePair).toSet(),
          {'●/○', '■/□', '▲/△', '◉/○', '✓/○'},
        );
        expect(
          SingleSelectionStyle.values.map((style) => style.asciiPair).toSet(),
          {'(*)/( )', '[x]/[ ]', '<^>/< >', '(o)/(.)', 'x/-'},
        );
        for (final style in SingleSelectionStyle.values) {
          expect(
            renderChoiceRow(
              ChoicePresentation(label: 'A', selected: true, style: style),
              glyphs: StateGlyphs.unicode,
            ),
            contains(
              style.selectedGlyph(StateGlyphs.unicode, selectedState: true),
            ),
          );
          expect(
            renderChoiceRow(
              ChoicePresentation(label: 'A', selected: true, style: style),
              glyphs: StateGlyphs.ascii,
            ),
            contains(
              style.selectedGlyph(StateGlyphs.ascii, selectedState: true),
            ),
          );
        }
      },
    );

    test('narrow monochrome rows keep markers intact and labels readable', () {
      const row = ChoicePresentation(
        label: 'Alpha Beta',
        focused: true,
        checked: false,
        isDefault: true,
      );
      final rendered = renderChoiceRow(
        row,
        glyphs: StateGlyphs.ascii,
        width: 20,
      );

      expect(rendered, isNot(contains('\x1b[')));
      final lines = rendered.split('\n');
      expect(lines, hasLength(greaterThan(1)));
      expect(lines.first, contains('> D'));
      expect(lines.first, contains('-'));
      expect(lines.first, isNot(contains('Alpha Beta')));
      expect(lines.first, contains('Alpha'));
      expect(lines.last.trim(), 'Beta');
      expect(
        lines.first.indexOf('> D'),
        greaterThan(0),
        reason: 'focus and default markers stay intact on one line',
      );
    });

    test('tree disclosure occupies its own aligned position', () {
      final rows = [
        ChoicePresentation(label: 'Leaf', disclosure: DisclosureState.leaf),
        ChoicePresentation(label: 'Open', disclosure: DisclosureState.expanded),
        ChoicePresentation(
          label: 'Shut',
          disclosure: DisclosureState.collapsed,
        ),
      ];
      final unicode = [
        for (final row in rows)
          renderChoiceRow(row, glyphs: StateGlyphs.unicode),
      ];
      final ascii = [
        for (final row in rows) renderChoiceRow(row, glyphs: StateGlyphs.ascii),
      ];

      expect(unicode.map((line) => line[0]), [' ', '▾', '▸']);
      expect(ascii.map((line) => line[0]), [' ', 'v', '>']);
      final prefixCells = ChoicePresentation(label: 'x')
          .markers()
          .prefix
          .length;
      expect(
        [for (final line in unicode) line.substring(prefixCells)],
        ['Leaf', 'Open', 'Shut'],
        reason: 'a leaf keeps a blank but aligned disclosure position',
      );
    });
  });

  group('restrictions and status text', () {
    test(
      'locked and unavailable rows stay focusable but cannot be accepted',
      () {
        final locked = ChoicePresentation(
          label: 'Admin',
          focused: true,
          restriction: ChoiceRestriction.locked,
          reason: 'needs owner role',
        );
        final unavailable = ChoicePresentation(
          label: 'Archive',
          restriction: ChoiceRestriction.unavailable,
          reason: 'maintenance window',
        );

        for (final row in [locked, unavailable]) {
          expect(row.focusable, isTrue);
          expect(row.selectable, isFalse);
          expect(row.acceptable, isFalse);
        }
        final lockedRow = renderChoiceRow(locked, glyphs: StateGlyphs.unicode);
        final unavailableRow = renderChoiceRow(
          unavailable,
          glyphs: StateGlyphs.ascii,
        );
        expect(lockedRow, contains('[L]'));
        expect(lockedRow, contains('needs owner role'));
        expect(unavailableRow, contains('[!'));
        expect(unavailableRow, contains('maintenance window'));
      },
    );

    test(
      'status messages always carry textual labels beside their symbols',
      () {
        expect(
          renderStatus(Status.success, 'Saved', glyphs: StateGlyphs.unicode),
          '✓ Success: Saved',
        );
        expect(
          renderStatus(Status.warning, 'Slow', glyphs: StateGlyphs.unicode),
          '! Warning: Slow',
        );
        expect(
          renderStatus(Status.error, 'Failed', glyphs: StateGlyphs.unicode),
          '× Error: Failed',
        );
        expect(
          renderStatus(Status.success, 'Saved', glyphs: StateGlyphs.ascii),
          '+ Success: Saved',
        );
        expect(
          renderStatus(Status.warning, 'Slow', glyphs: StateGlyphs.ascii),
          '! Warning: Slow',
        );
        expect(
          renderStatus(Status.error, 'Failed', glyphs: StateGlyphs.ascii),
          'x Error: Failed',
        );
      },
    );
  });
}
