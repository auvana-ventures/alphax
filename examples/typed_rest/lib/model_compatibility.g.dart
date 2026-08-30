// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_compatibility.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JsonSerializableUser _$JsonSerializableUserFromJson(
  Map<String, dynamic> json,
) => JsonSerializableUser(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
);

Map<String, dynamic> _$JsonSerializableUserToJson(
  JsonSerializableUser instance,
) => <String, dynamic>{'id': instance.id, 'name': instance.name};

_FreezedUser _$FreezedUserFromJson(Map<String, dynamic> json) =>
    _FreezedUser(id: (json['id'] as num).toInt(), name: json['name'] as String);

Map<String, dynamic> _$FreezedUserToJson(_FreezedUser instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};
