import 'package:trelis/src/testing/compat_api.dart';

Future<void> main(List<String> args) async {
  final result = await KeyChordInput(
    'Sequence',
    requireObservation: true,
  ).prompt(mode: args.first == 'linear' ? PromptMode.linear : PromptMode.rich);
  if (result is Accepted<List<KeyGesture>>) {
    print(
      result.value
          .map(
            (g) =>
                '${g.key}:${g.modifiers.map((m) => m.name).join("+")}:${g.provenance.name}',
          )
          .join(','),
    );
  } else {
    print(result.runtimeType);
  }
}
