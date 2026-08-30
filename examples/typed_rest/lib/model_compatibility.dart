import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart' as json;

part 'model_compatibility.freezed.dart';
part 'model_compatibility.g.dart';

@json.JsonSerializable()
final class JsonSerializableUser {
  const JsonSerializableUser({required this.id, required this.name});

  factory JsonSerializableUser.fromJson(Map<String, Object?> json) =>
      _$JsonSerializableUserFromJson(json);

  final int id;
  final String name;

  Map<String, Object?> toJson() => _$JsonSerializableUserToJson(this);
}

@freezed
abstract class FreezedUser with _$FreezedUser {
  const factory FreezedUser({required int id, required String name}) =
      _FreezedUser;

  factory FreezedUser.fromJson(Map<String, Object?> json) =>
      _$FreezedUserFromJson(json);
}
