import 'package:alphax/annotations.dart';
import 'package:alphax_generator/alphax_generator.dart';
import 'package:source_gen_test/source_gen_test.dart';

Future<void> main() async {
  initializeBuildLogTracking();
  final reader = await initializeLibraryReaderForDirectory(
    'test/fixtures',
    'diagnostic_input.dart',
  );

  testAnnotatedElements<AlphaXApi>(
    reader,
    const AlphaXApiGenerator(),
    expectedAnnotatedTests: const <String>[
      'MissingPathBindingApi',
      'DuplicateBodyApi',
      'MissingDecoderApi',
      'ValidSurfaceApi',
    ],
  );
}
