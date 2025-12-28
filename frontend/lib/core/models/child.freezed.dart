// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'child.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Child _$ChildFromJson(Map<String, dynamic> json) {
  return _Child.fromJson(json);
}

/// @nodoc
mixin _$Child {
  @JsonKey(fromJson: _idToString)
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get age => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _genderFromJson)
  ChildGender get gender => throw _privateConstructorUsedError;
  String get interests => throw _privateConstructorUsedError;
  String get fears => throw _privateConstructorUsedError;
  String get character => throw _privateConstructorUsedError;
  String get moral => throw _privateConstructorUsedError;
  @JsonKey(name: 'face_url')
  String? get faceUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'photos', fromJson: _photosFromJson)
  List<String>? get photos => throw _privateConstructorUsedError;

  /// Serializes this Child to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Child
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChildCopyWith<Child> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChildCopyWith<$Res> {
  factory $ChildCopyWith(Child value, $Res Function(Child) then) =
      _$ChildCopyWithImpl<$Res, Child>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _idToString) String id,
    String name,
    int age,
    @JsonKey(fromJson: _genderFromJson) ChildGender gender,
    String interests,
    String fears,
    String character,
    String moral,
    @JsonKey(name: 'face_url') String? faceUrl,
    @JsonKey(name: 'photos', fromJson: _photosFromJson) List<String>? photos,
  });
}

/// @nodoc
class _$ChildCopyWithImpl<$Res, $Val extends Child>
    implements $ChildCopyWith<$Res> {
  _$ChildCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Child
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? age = null,
    Object? gender = null,
    Object? interests = null,
    Object? fears = null,
    Object? character = null,
    Object? moral = null,
    Object? faceUrl = freezed,
    Object? photos = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            age: null == age
                ? _value.age
                : age // ignore: cast_nullable_to_non_nullable
                      as int,
            gender: null == gender
                ? _value.gender
                : gender // ignore: cast_nullable_to_non_nullable
                      as ChildGender,
            interests: null == interests
                ? _value.interests
                : interests // ignore: cast_nullable_to_non_nullable
                      as String,
            fears: null == fears
                ? _value.fears
                : fears // ignore: cast_nullable_to_non_nullable
                      as String,
            character: null == character
                ? _value.character
                : character // ignore: cast_nullable_to_non_nullable
                      as String,
            moral: null == moral
                ? _value.moral
                : moral // ignore: cast_nullable_to_non_nullable
                      as String,
            faceUrl: freezed == faceUrl
                ? _value.faceUrl
                : faceUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            photos: freezed == photos
                ? _value.photos
                : photos // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChildImplCopyWith<$Res> implements $ChildCopyWith<$Res> {
  factory _$$ChildImplCopyWith(
    _$ChildImpl value,
    $Res Function(_$ChildImpl) then,
  ) = __$$ChildImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _idToString) String id,
    String name,
    int age,
    @JsonKey(fromJson: _genderFromJson) ChildGender gender,
    String interests,
    String fears,
    String character,
    String moral,
    @JsonKey(name: 'face_url') String? faceUrl,
    @JsonKey(name: 'photos', fromJson: _photosFromJson) List<String>? photos,
  });
}

/// @nodoc
class __$$ChildImplCopyWithImpl<$Res>
    extends _$ChildCopyWithImpl<$Res, _$ChildImpl>
    implements _$$ChildImplCopyWith<$Res> {
  __$$ChildImplCopyWithImpl(
    _$ChildImpl _value,
    $Res Function(_$ChildImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Child
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? age = null,
    Object? gender = null,
    Object? interests = null,
    Object? fears = null,
    Object? character = null,
    Object? moral = null,
    Object? faceUrl = freezed,
    Object? photos = freezed,
  }) {
    return _then(
      _$ChildImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        age: null == age
            ? _value.age
            : age // ignore: cast_nullable_to_non_nullable
                  as int,
        gender: null == gender
            ? _value.gender
            : gender // ignore: cast_nullable_to_non_nullable
                  as ChildGender,
        interests: null == interests
            ? _value.interests
            : interests // ignore: cast_nullable_to_non_nullable
                  as String,
        fears: null == fears
            ? _value.fears
            : fears // ignore: cast_nullable_to_non_nullable
                  as String,
        character: null == character
            ? _value.character
            : character // ignore: cast_nullable_to_non_nullable
                  as String,
        moral: null == moral
            ? _value.moral
            : moral // ignore: cast_nullable_to_non_nullable
                  as String,
        faceUrl: freezed == faceUrl
            ? _value.faceUrl
            : faceUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        photos: freezed == photos
            ? _value._photos
            : photos // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChildImpl implements _Child {
  const _$ChildImpl({
    @JsonKey(fromJson: _idToString) required this.id,
    required this.name,
    required this.age,
    @JsonKey(fromJson: _genderFromJson) this.gender = ChildGender.female,
    required this.interests,
    required this.fears,
    required this.character,
    required this.moral,
    @JsonKey(name: 'face_url') this.faceUrl,
    @JsonKey(name: 'photos', fromJson: _photosFromJson)
    final List<String>? photos,
  }) : _photos = photos;

  factory _$ChildImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChildImplFromJson(json);

  @override
  @JsonKey(fromJson: _idToString)
  final String id;
  @override
  final String name;
  @override
  final int age;
  @override
  @JsonKey(fromJson: _genderFromJson)
  final ChildGender gender;
  @override
  final String interests;
  @override
  final String fears;
  @override
  final String character;
  @override
  final String moral;
  @override
  @JsonKey(name: 'face_url')
  final String? faceUrl;
  final List<String>? _photos;
  @override
  @JsonKey(name: 'photos', fromJson: _photosFromJson)
  List<String>? get photos {
    final value = _photos;
    if (value == null) return null;
    if (_photos is EqualUnmodifiableListView) return _photos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'Child(id: $id, name: $name, age: $age, gender: $gender, interests: $interests, fears: $fears, character: $character, moral: $moral, faceUrl: $faceUrl, photos: $photos)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChildImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.age, age) || other.age == age) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.interests, interests) ||
                other.interests == interests) &&
            (identical(other.fears, fears) || other.fears == fears) &&
            (identical(other.character, character) ||
                other.character == character) &&
            (identical(other.moral, moral) || other.moral == moral) &&
            (identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl) &&
            const DeepCollectionEquality().equals(other._photos, _photos));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    age,
    gender,
    interests,
    fears,
    character,
    moral,
    faceUrl,
    const DeepCollectionEquality().hash(_photos),
  );

  /// Create a copy of Child
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChildImplCopyWith<_$ChildImpl> get copyWith =>
      __$$ChildImplCopyWithImpl<_$ChildImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChildImplToJson(this);
  }
}

abstract class _Child implements Child {
  const factory _Child({
    @JsonKey(fromJson: _idToString) required final String id,
    required final String name,
    required final int age,
    @JsonKey(fromJson: _genderFromJson) final ChildGender gender,
    required final String interests,
    required final String fears,
    required final String character,
    required final String moral,
    @JsonKey(name: 'face_url') final String? faceUrl,
    @JsonKey(name: 'photos', fromJson: _photosFromJson)
    final List<String>? photos,
  }) = _$ChildImpl;

  factory _Child.fromJson(Map<String, dynamic> json) = _$ChildImpl.fromJson;

  @override
  @JsonKey(fromJson: _idToString)
  String get id;
  @override
  String get name;
  @override
  int get age;
  @override
  @JsonKey(fromJson: _genderFromJson)
  ChildGender get gender;
  @override
  String get interests;
  @override
  String get fears;
  @override
  String get character;
  @override
  String get moral;
  @override
  @JsonKey(name: 'face_url')
  String? get faceUrl;
  @override
  @JsonKey(name: 'photos', fromJson: _photosFromJson)
  List<String>? get photos;

  /// Create a copy of Child
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChildImplCopyWith<_$ChildImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
