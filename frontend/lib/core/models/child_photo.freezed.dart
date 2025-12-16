// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'child_photo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ChildPhoto _$ChildPhotoFromJson(Map<String, dynamic> json) {
  return _ChildPhoto.fromJson(json);
}

/// @nodoc
mixin _$ChildPhoto {
  String get url => throw _privateConstructorUsedError;
  String get filename => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_avatar')
  bool get isAvatar => throw _privateConstructorUsedError;

  /// Serializes this ChildPhoto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChildPhoto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChildPhotoCopyWith<ChildPhoto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChildPhotoCopyWith<$Res> {
  factory $ChildPhotoCopyWith(
    ChildPhoto value,
    $Res Function(ChildPhoto) then,
  ) = _$ChildPhotoCopyWithImpl<$Res, ChildPhoto>;
  @useResult
  $Res call({
    String url,
    String filename,
    @JsonKey(name: 'is_avatar') bool isAvatar,
  });
}

/// @nodoc
class _$ChildPhotoCopyWithImpl<$Res, $Val extends ChildPhoto>
    implements $ChildPhotoCopyWith<$Res> {
  _$ChildPhotoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChildPhoto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? filename = null,
    Object? isAvatar = null,
  }) {
    return _then(
      _value.copyWith(
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String,
            filename: null == filename
                ? _value.filename
                : filename // ignore: cast_nullable_to_non_nullable
                      as String,
            isAvatar: null == isAvatar
                ? _value.isAvatar
                : isAvatar // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChildPhotoImplCopyWith<$Res>
    implements $ChildPhotoCopyWith<$Res> {
  factory _$$ChildPhotoImplCopyWith(
    _$ChildPhotoImpl value,
    $Res Function(_$ChildPhotoImpl) then,
  ) = __$$ChildPhotoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String url,
    String filename,
    @JsonKey(name: 'is_avatar') bool isAvatar,
  });
}

/// @nodoc
class __$$ChildPhotoImplCopyWithImpl<$Res>
    extends _$ChildPhotoCopyWithImpl<$Res, _$ChildPhotoImpl>
    implements _$$ChildPhotoImplCopyWith<$Res> {
  __$$ChildPhotoImplCopyWithImpl(
    _$ChildPhotoImpl _value,
    $Res Function(_$ChildPhotoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChildPhoto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? filename = null,
    Object? isAvatar = null,
  }) {
    return _then(
      _$ChildPhotoImpl(
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        filename: null == filename
            ? _value.filename
            : filename // ignore: cast_nullable_to_non_nullable
                  as String,
        isAvatar: null == isAvatar
            ? _value.isAvatar
            : isAvatar // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChildPhotoImpl implements _ChildPhoto {
  const _$ChildPhotoImpl({
    required this.url,
    required this.filename,
    @JsonKey(name: 'is_avatar') this.isAvatar = false,
  });

  factory _$ChildPhotoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChildPhotoImplFromJson(json);

  @override
  final String url;
  @override
  final String filename;
  @override
  @JsonKey(name: 'is_avatar')
  final bool isAvatar;

  @override
  String toString() {
    return 'ChildPhoto(url: $url, filename: $filename, isAvatar: $isAvatar)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChildPhotoImpl &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.filename, filename) ||
                other.filename == filename) &&
            (identical(other.isAvatar, isAvatar) ||
                other.isAvatar == isAvatar));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, url, filename, isAvatar);

  /// Create a copy of ChildPhoto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChildPhotoImplCopyWith<_$ChildPhotoImpl> get copyWith =>
      __$$ChildPhotoImplCopyWithImpl<_$ChildPhotoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChildPhotoImplToJson(this);
  }
}

abstract class _ChildPhoto implements ChildPhoto {
  const factory _ChildPhoto({
    required final String url,
    required final String filename,
    @JsonKey(name: 'is_avatar') final bool isAvatar,
  }) = _$ChildPhotoImpl;

  factory _ChildPhoto.fromJson(Map<String, dynamic> json) =
      _$ChildPhotoImpl.fromJson;

  @override
  String get url;
  @override
  String get filename;
  @override
  @JsonKey(name: 'is_avatar')
  bool get isAvatar;

  /// Create a copy of ChildPhoto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChildPhotoImplCopyWith<_$ChildPhotoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChildPhotosResponse _$ChildPhotosResponseFromJson(Map<String, dynamic> json) {
  return _ChildPhotosResponse.fromJson(json);
}

/// @nodoc
mixin _$ChildPhotosResponse {
  @JsonKey(name: 'child_id')
  String get childId => throw _privateConstructorUsedError;
  List<ChildPhoto> get photos => throw _privateConstructorUsedError;

  /// Serializes this ChildPhotosResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChildPhotosResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChildPhotosResponseCopyWith<ChildPhotosResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChildPhotosResponseCopyWith<$Res> {
  factory $ChildPhotosResponseCopyWith(
    ChildPhotosResponse value,
    $Res Function(ChildPhotosResponse) then,
  ) = _$ChildPhotosResponseCopyWithImpl<$Res, ChildPhotosResponse>;
  @useResult
  $Res call({
    @JsonKey(name: 'child_id') String childId,
    List<ChildPhoto> photos,
  });
}

/// @nodoc
class _$ChildPhotosResponseCopyWithImpl<$Res, $Val extends ChildPhotosResponse>
    implements $ChildPhotosResponseCopyWith<$Res> {
  _$ChildPhotosResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChildPhotosResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? childId = null, Object? photos = null}) {
    return _then(
      _value.copyWith(
            childId: null == childId
                ? _value.childId
                : childId // ignore: cast_nullable_to_non_nullable
                      as String,
            photos: null == photos
                ? _value.photos
                : photos // ignore: cast_nullable_to_non_nullable
                      as List<ChildPhoto>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChildPhotosResponseImplCopyWith<$Res>
    implements $ChildPhotosResponseCopyWith<$Res> {
  factory _$$ChildPhotosResponseImplCopyWith(
    _$ChildPhotosResponseImpl value,
    $Res Function(_$ChildPhotosResponseImpl) then,
  ) = __$$ChildPhotosResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'child_id') String childId,
    List<ChildPhoto> photos,
  });
}

/// @nodoc
class __$$ChildPhotosResponseImplCopyWithImpl<$Res>
    extends _$ChildPhotosResponseCopyWithImpl<$Res, _$ChildPhotosResponseImpl>
    implements _$$ChildPhotosResponseImplCopyWith<$Res> {
  __$$ChildPhotosResponseImplCopyWithImpl(
    _$ChildPhotosResponseImpl _value,
    $Res Function(_$ChildPhotosResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChildPhotosResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? childId = null, Object? photos = null}) {
    return _then(
      _$ChildPhotosResponseImpl(
        childId: null == childId
            ? _value.childId
            : childId // ignore: cast_nullable_to_non_nullable
                  as String,
        photos: null == photos
            ? _value._photos
            : photos // ignore: cast_nullable_to_non_nullable
                  as List<ChildPhoto>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChildPhotosResponseImpl implements _ChildPhotosResponse {
  const _$ChildPhotosResponseImpl({
    @JsonKey(name: 'child_id') required this.childId,
    final List<ChildPhoto> photos = const [],
  }) : _photos = photos;

  factory _$ChildPhotosResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChildPhotosResponseImplFromJson(json);

  @override
  @JsonKey(name: 'child_id')
  final String childId;
  final List<ChildPhoto> _photos;
  @override
  @JsonKey()
  List<ChildPhoto> get photos {
    if (_photos is EqualUnmodifiableListView) return _photos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_photos);
  }

  @override
  String toString() {
    return 'ChildPhotosResponse(childId: $childId, photos: $photos)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChildPhotosResponseImpl &&
            (identical(other.childId, childId) || other.childId == childId) &&
            const DeepCollectionEquality().equals(other._photos, _photos));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    childId,
    const DeepCollectionEquality().hash(_photos),
  );

  /// Create a copy of ChildPhotosResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChildPhotosResponseImplCopyWith<_$ChildPhotosResponseImpl> get copyWith =>
      __$$ChildPhotosResponseImplCopyWithImpl<_$ChildPhotosResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ChildPhotosResponseImplToJson(this);
  }
}

abstract class _ChildPhotosResponse implements ChildPhotosResponse {
  const factory _ChildPhotosResponse({
    @JsonKey(name: 'child_id') required final String childId,
    final List<ChildPhoto> photos,
  }) = _$ChildPhotosResponseImpl;

  factory _ChildPhotosResponse.fromJson(Map<String, dynamic> json) =
      _$ChildPhotosResponseImpl.fromJson;

  @override
  @JsonKey(name: 'child_id')
  String get childId;
  @override
  List<ChildPhoto> get photos;

  /// Create a copy of ChildPhotosResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChildPhotosResponseImplCopyWith<_$ChildPhotosResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
