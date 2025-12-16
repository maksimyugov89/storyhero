// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'child.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChildImpl _$$ChildImplFromJson(Map<String, dynamic> json) => _$ChildImpl(
  id: _idToString(json['id']),
  name: json['name'] as String,
  age: (json['age'] as num).toInt(),
  interests: json['interests'] as String,
  fears: json['fears'] as String,
  character: json['character'] as String,
  moral: json['moral'] as String,
  faceUrl: json['face_url'] as String?,
  photos: _photosFromJson(json['photos']),
);

Map<String, dynamic> _$$ChildImplToJson(_$ChildImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'age': instance.age,
      'interests': instance.interests,
      'fears': instance.fears,
      'character': instance.character,
      'moral': instance.moral,
      'face_url': instance.faceUrl,
      'photos': instance.photos,
    };
