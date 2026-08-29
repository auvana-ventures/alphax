import 'dart:convert';
import 'dart:typed_data';

import 'package:alphax_transform/alphax_transform.dart';

Map<String, Object?> summarizeUser(Object? decodedJson) {
  final json = decodedJson! as Map<Object?, Object?>;
  return <String, Object?>{
    'id': json['id'],
    'name': json['name'],
  };
}

Future<void> main() async {
  final bytes = Uint8List.fromList(
    utf8.encode('{"id":7,"name":"AlphaX"}'),
  );
  final result = await decodeJson<Map<String, Object?>>(
    bytes: bytes,
    transform: summarizeUser,
    debugName: 'alphax-transform-example',
  );
  print(result);
}
