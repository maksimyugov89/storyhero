// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookImpl _$$BookImplFromJson(Map<String, dynamic> json) => _$BookImpl(
  id: _bookIdToString(json['id']),
  childId: _childIdToString(json['child_id']),
  userId: json['user_id'] as String?,
  title: json['title'] as String,
  createdAt: _dateTimeFromJson(json['created_at']),
  status: json['status'] as String? ?? 'draft',
  coverUrl: json['cover_url'] as String?,
  finalPdfUrl: json['final_pdf_url'] as String?,
  isPaid: json['is_paid'] as bool? ?? false,
  pages: json['pages'] as List<dynamic>?,
  editHistory: json['edit_history'] as List<dynamic>?,
  imagesFinal: json['images_final'] as List<dynamic>?,
);

Map<String, dynamic> _$$BookImplToJson(_$BookImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'child_id': instance.childId,
      'user_id': instance.userId,
      'title': instance.title,
      'created_at': instance.createdAt.toIso8601String(),
      'status': instance.status,
      'cover_url': instance.coverUrl,
      'final_pdf_url': instance.finalPdfUrl,
      'is_paid': instance.isPaid,
      'pages': instance.pages,
      'edit_history': instance.editHistory,
      'images_final': instance.imagesFinal,
    };
