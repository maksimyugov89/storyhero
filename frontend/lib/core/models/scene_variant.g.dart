// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scene_variant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TextVariantImpl _$$TextVariantImplFromJson(Map<String, dynamic> json) =>
    _$TextVariantImpl(
      id: json['id'] as String,
      text: json['text'] as String,
      variantNumber: (json['variantNumber'] as num).toInt(),
      createdAt: json['created_at'] as String?,
      instruction: json['instruction'] as String?,
      isSelected: json['isSelected'] as bool? ?? false,
    );

Map<String, dynamic> _$$TextVariantImplToJson(_$TextVariantImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'variantNumber': instance.variantNumber,
      'created_at': instance.createdAt,
      'instruction': instance.instruction,
      'isSelected': instance.isSelected,
    };

_$ImageVariantImpl _$$ImageVariantImplFromJson(Map<String, dynamic> json) =>
    _$ImageVariantImpl(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      variantNumber: (json['variantNumber'] as num).toInt(),
      createdAt: json['created_at'] as String?,
      instruction: json['instruction'] as String?,
      isSelected: json['isSelected'] as bool? ?? false,
    );

Map<String, dynamic> _$$ImageVariantImplToJson(_$ImageVariantImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'image_url': instance.imageUrl,
      'variantNumber': instance.variantNumber,
      'created_at': instance.createdAt,
      'instruction': instance.instruction,
      'isSelected': instance.isSelected,
    };

_$SceneVariantsImpl _$$SceneVariantsImplFromJson(Map<String, dynamic> json) =>
    _$SceneVariantsImpl(
      sceneId: json['sceneId'] as String,
      textVariants:
          (json['textVariants'] as List<dynamic>?)
              ?.map((e) => TextVariant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      imageVariants:
          (json['imageVariants'] as List<dynamic>?)
              ?.map((e) => ImageVariant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      maxTextVariants: (json['maxTextVariants'] as num?)?.toInt() ?? 5,
      maxImageVariants: (json['maxImageVariants'] as num?)?.toInt() ?? 3,
      selectedTextVariantId: json['selectedTextVariantId'] as String?,
      selectedImageVariantId: json['selectedImageVariantId'] as String?,
    );

Map<String, dynamic> _$$SceneVariantsImplToJson(_$SceneVariantsImpl instance) =>
    <String, dynamic>{
      'sceneId': instance.sceneId,
      'textVariants': instance.textVariants.map((e) => e.toJson()).toList(),
      'imageVariants': instance.imageVariants.map((e) => e.toJson()).toList(),
      'maxTextVariants': instance.maxTextVariants,
      'maxImageVariants': instance.maxImageVariants,
      'selectedTextVariantId': instance.selectedTextVariantId,
      'selectedImageVariantId': instance.selectedImageVariantId,
    };
