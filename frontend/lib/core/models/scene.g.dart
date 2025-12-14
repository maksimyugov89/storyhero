// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scene.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SceneImpl _$$SceneImplFromJson(Map<String, dynamic> json) => _$SceneImpl(
  id: _sceneIdToString(json['id']),
  bookId: json['book_id'] as String,
  order: (json['order'] as num).toInt(),
  shortSummary: _shortSummaryFromJson(json['short_summary']),
  imagePrompt: json['image_prompt'] as String?,
  draftUrl: json['draft_url'] as String?,
  finalUrl: json['final_url'] as String?,
);

Map<String, dynamic> _$$SceneImplToJson(_$SceneImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'book_id': instance.bookId,
      'order': instance.order,
      'short_summary': instance.shortSummary,
      'image_prompt': instance.imagePrompt,
      'draft_url': instance.draftUrl,
      'final_url': instance.finalUrl,
    };
