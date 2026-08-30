import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/alpha_x_api_generator.dart';

/// Creates the AlphaX shared-part builder used by `build_runner`.
Builder alphaxBuilder(BuilderOptions options) =>
    SharedPartBuilder(<Generator>[AlphaXApiGenerator()], 'alphax_generator');
