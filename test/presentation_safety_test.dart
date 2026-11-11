import 'package:prompty/src/presentation.dart';
import 'package:test/test.dart';

void main() {
  test('protected TextInput content omitted by a declaration is diagnosed and repaired', () {
    final content = TextInputPresentationContent(
      label: DisplayText.from('Name'),
      context: DisplayText.from('(Required).'),
      validation: DisplayText.from('Enter a value.'),
      editable: TextInputEditableRegion(
        beforeCaret: DisplayText.from('draft'),
        afterCaret: DisplayText.from(''),
      ),
    );
    final declaration = PresentationDeclaration({
      PresentationSlot.label,
      PresentationSlot.context,
      PresentationSlot.body,
    });

    final composition = PresentationCompositor().composeTextInput(
      content,
      declaration,
    );

    expect(declaration.diagnoseOmittedProtectedSlots(content), [
      PresentationSlot.validation,
    ]);
    expect(composition.bodySlots, isNot(contains(PresentationSlot.validation)));
    expect(composition.safetyAreaSlots, [PresentationSlot.validation]);
    expect(composition.safetyArea.single.text!.value, 'Enter a value.');
    expect(
      () => composition.safetyArea.add(composition.safetyArea.single),
      throwsUnsupportedError,
    );
  });
}
