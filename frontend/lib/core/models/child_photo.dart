import 'package:freezed_annotation/freezed_annotation.dart';

part 'child_photo.freezed.dart';
part 'child_photo.g.dart';

@freezed
class ChildPhoto with _$ChildPhoto {
  const factory ChildPhoto({
    required String url,
    required String filename,
    @JsonKey(name: 'is_avatar') @Default(false) bool isAvatar,
  }) = _ChildPhoto;

  factory ChildPhoto.fromJson(Map<String, dynamic> json) => _$ChildPhotoFromJson(json);
}

@freezed
class ChildPhotosResponse with _$ChildPhotosResponse {
  const factory ChildPhotosResponse({
    @JsonKey(name: 'child_id') required String childId,
    @Default([]) List<ChildPhoto> photos,
  }) = _ChildPhotosResponse;

  factory ChildPhotosResponse.fromJson(Map<String, dynamic> json) => _$ChildPhotosResponseFromJson(json);
}

