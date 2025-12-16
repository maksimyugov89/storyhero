// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scene.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Scene _$SceneFromJson(Map<String, dynamic> json) {
  return _Scene.fromJson(json);
}

/// @nodoc
mixin _$Scene {
  @JsonKey(fromJson: _sceneIdToString)
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'book_id')
  String get bookId => throw _privateConstructorUsedError;
  int get order => throw _privateConstructorUsedError;
  @JsonKey(name: 'short_summary', fromJson: _shortSummaryFromJson)
  String get shortSummary => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_prompt')
  String? get imagePrompt => throw _privateConstructorUsedError; // Сделано опциональным, т.к. API может не возвращать
  @JsonKey(name: 'draft_url')
  String? get draftUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url', fromJson: _imageUrlFromJson)
  String? get finalUrl => throw _privateConstructorUsedError;

  /// Serializes this Scene to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Scene
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SceneCopyWith<Scene> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SceneCopyWith<$Res> {
  factory $SceneCopyWith(Scene value, $Res Function(Scene) then) =
      _$SceneCopyWithImpl<$Res, Scene>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _sceneIdToString) String id,
    @JsonKey(name: 'book_id') String bookId,
    int order,
    @JsonKey(name: 'short_summary', fromJson: _shortSummaryFromJson)
    String shortSummary,
    @JsonKey(name: 'image_prompt') String? imagePrompt,
    @JsonKey(name: 'draft_url') String? draftUrl,
    @JsonKey(name: 'image_url', fromJson: _imageUrlFromJson) String? finalUrl,
  });
}

/// @nodoc
class _$SceneCopyWithImpl<$Res, $Val extends Scene>
    implements $SceneCopyWith<$Res> {
  _$SceneCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Scene
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? bookId = null,
    Object? order = null,
    Object? shortSummary = null,
    Object? imagePrompt = freezed,
    Object? draftUrl = freezed,
    Object? finalUrl = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            bookId: null == bookId
                ? _value.bookId
                : bookId // ignore: cast_nullable_to_non_nullable
                      as String,
            order: null == order
                ? _value.order
                : order // ignore: cast_nullable_to_non_nullable
                      as int,
            shortSummary: null == shortSummary
                ? _value.shortSummary
                : shortSummary // ignore: cast_nullable_to_non_nullable
                      as String,
            imagePrompt: freezed == imagePrompt
                ? _value.imagePrompt
                : imagePrompt // ignore: cast_nullable_to_non_nullable
                      as String?,
            draftUrl: freezed == draftUrl
                ? _value.draftUrl
                : draftUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            finalUrl: freezed == finalUrl
                ? _value.finalUrl
                : finalUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SceneImplCopyWith<$Res> implements $SceneCopyWith<$Res> {
  factory _$$SceneImplCopyWith(
    _$SceneImpl value,
    $Res Function(_$SceneImpl) then,
  ) = __$$SceneImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _sceneIdToString) String id,
    @JsonKey(name: 'book_id') String bookId,
    int order,
    @JsonKey(name: 'short_summary', fromJson: _shortSummaryFromJson)
    String shortSummary,
    @JsonKey(name: 'image_prompt') String? imagePrompt,
    @JsonKey(name: 'draft_url') String? draftUrl,
    @JsonKey(name: 'image_url', fromJson: _imageUrlFromJson) String? finalUrl,
  });
}

/// @nodoc
class __$$SceneImplCopyWithImpl<$Res>
    extends _$SceneCopyWithImpl<$Res, _$SceneImpl>
    implements _$$SceneImplCopyWith<$Res> {
  __$$SceneImplCopyWithImpl(
    _$SceneImpl _value,
    $Res Function(_$SceneImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Scene
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? bookId = null,
    Object? order = null,
    Object? shortSummary = null,
    Object? imagePrompt = freezed,
    Object? draftUrl = freezed,
    Object? finalUrl = freezed,
  }) {
    return _then(
      _$SceneImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        bookId: null == bookId
            ? _value.bookId
            : bookId // ignore: cast_nullable_to_non_nullable
                  as String,
        order: null == order
            ? _value.order
            : order // ignore: cast_nullable_to_non_nullable
                  as int,
        shortSummary: null == shortSummary
            ? _value.shortSummary
            : shortSummary // ignore: cast_nullable_to_non_nullable
                  as String,
        imagePrompt: freezed == imagePrompt
            ? _value.imagePrompt
            : imagePrompt // ignore: cast_nullable_to_non_nullable
                  as String?,
        draftUrl: freezed == draftUrl
            ? _value.draftUrl
            : draftUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        finalUrl: freezed == finalUrl
            ? _value.finalUrl
            : finalUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SceneImpl implements _Scene {
  const _$SceneImpl({
    @JsonKey(fromJson: _sceneIdToString) required this.id,
    @JsonKey(name: 'book_id') required this.bookId,
    required this.order,
    @JsonKey(name: 'short_summary', fromJson: _shortSummaryFromJson)
    required this.shortSummary,
    @JsonKey(name: 'image_prompt') this.imagePrompt,
    @JsonKey(name: 'draft_url') this.draftUrl,
    @JsonKey(name: 'image_url', fromJson: _imageUrlFromJson) this.finalUrl,
  });

  factory _$SceneImpl.fromJson(Map<String, dynamic> json) =>
      _$$SceneImplFromJson(json);

  @override
  @JsonKey(fromJson: _sceneIdToString)
  final String id;
  @override
  @JsonKey(name: 'book_id')
  final String bookId;
  @override
  final int order;
  @override
  @JsonKey(name: 'short_summary', fromJson: _shortSummaryFromJson)
  final String shortSummary;
  @override
  @JsonKey(name: 'image_prompt')
  final String? imagePrompt;
  // Сделано опциональным, т.к. API может не возвращать
  @override
  @JsonKey(name: 'draft_url')
  final String? draftUrl;
  @override
  @JsonKey(name: 'image_url', fromJson: _imageUrlFromJson)
  final String? finalUrl;

  @override
  String toString() {
    return 'Scene(id: $id, bookId: $bookId, order: $order, shortSummary: $shortSummary, imagePrompt: $imagePrompt, draftUrl: $draftUrl, finalUrl: $finalUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SceneImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.bookId, bookId) || other.bookId == bookId) &&
            (identical(other.order, order) || other.order == order) &&
            (identical(other.shortSummary, shortSummary) ||
                other.shortSummary == shortSummary) &&
            (identical(other.imagePrompt, imagePrompt) ||
                other.imagePrompt == imagePrompt) &&
            (identical(other.draftUrl, draftUrl) ||
                other.draftUrl == draftUrl) &&
            (identical(other.finalUrl, finalUrl) ||
                other.finalUrl == finalUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    bookId,
    order,
    shortSummary,
    imagePrompt,
    draftUrl,
    finalUrl,
  );

  /// Create a copy of Scene
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SceneImplCopyWith<_$SceneImpl> get copyWith =>
      __$$SceneImplCopyWithImpl<_$SceneImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SceneImplToJson(this);
  }
}

abstract class _Scene implements Scene {
  const factory _Scene({
    @JsonKey(fromJson: _sceneIdToString) required final String id,
    @JsonKey(name: 'book_id') required final String bookId,
    required final int order,
    @JsonKey(name: 'short_summary', fromJson: _shortSummaryFromJson)
    required final String shortSummary,
    @JsonKey(name: 'image_prompt') final String? imagePrompt,
    @JsonKey(name: 'draft_url') final String? draftUrl,
    @JsonKey(name: 'image_url', fromJson: _imageUrlFromJson)
    final String? finalUrl,
  }) = _$SceneImpl;

  factory _Scene.fromJson(Map<String, dynamic> json) = _$SceneImpl.fromJson;

  @override
  @JsonKey(fromJson: _sceneIdToString)
  String get id;
  @override
  @JsonKey(name: 'book_id')
  String get bookId;
  @override
  int get order;
  @override
  @JsonKey(name: 'short_summary', fromJson: _shortSummaryFromJson)
  String get shortSummary;
  @override
  @JsonKey(name: 'image_prompt')
  String? get imagePrompt; // Сделано опциональным, т.к. API может не возвращать
  @override
  @JsonKey(name: 'draft_url')
  String? get draftUrl;
  @override
  @JsonKey(name: 'image_url', fromJson: _imageUrlFromJson)
  String? get finalUrl;

  /// Create a copy of Scene
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SceneImplCopyWith<_$SceneImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
