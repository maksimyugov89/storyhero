// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'child_photo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChildPhotoImpl _$$ChildPhotoImplFromJson(Map<String, dynamic> json) =>
    _$ChildPhotoImpl(
      url: json['url'] as String,
      filename: json['filename'] as String,
      isAvatar: json['is_avatar'] as bool? ?? false,
    );

Map<String, dynamic> _$$ChildPhotoImplToJson(_$ChildPhotoImpl instance) =>
    <String, dynamic>{
      'url': instance.url,
      'filename': instance.filename,
      'is_avatar': instance.isAvatar,
    };

_$ChildPhotosResponseImpl _$$ChildPhotosResponseImplFromJson(
  Map<String, dynamic> json,
) => _$ChildPhotosResponseImpl(
  childId: json['child_id'] as String,
  photos:
      (json['photos'] as List<dynamic>?)
          ?.map((e) => ChildPhoto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$$ChildPhotosResponseImplToJson(
  _$ChildPhotosResponseImpl instance,
) => <String, dynamic>{
  'child_id': instance.childId,
  'photos': instance.photos.map((e) => e.toJson()).toList(),
};
