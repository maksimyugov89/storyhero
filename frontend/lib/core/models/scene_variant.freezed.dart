// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scene_variant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TextVariant _$TextVariantFromJson(Map<String, dynamic> json) {
  return _TextVariant.fromJson(json);
}

/// @nodoc
mixin _$TextVariant {
  String get id => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  int get variantNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'instruction')
  String? get instruction => throw _privateConstructorUsedError; // Инструкция, которая привела к этому варианту
  bool get isSelected => throw _privateConstructorUsedError;

  /// Serializes this TextVariant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TextVariant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TextVariantCopyWith<TextVariant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TextVariantCopyWith<$Res> {
  factory $TextVariantCopyWith(
    TextVariant value,
    $Res Function(TextVariant) then,
  ) = _$TextVariantCopyWithImpl<$Res, TextVariant>;
  @useResult
  $Res call({
    String id,
    String text,
    int variantNumber,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'instruction') String? instruction,
    bool isSelected,
  });
}

/// @nodoc
class _$TextVariantCopyWithImpl<$Res, $Val extends TextVariant>
    implements $TextVariantCopyWith<$Res> {
  _$TextVariantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TextVariant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? variantNumber = null,
    Object? createdAt = freezed,
    Object? instruction = freezed,
    Object? isSelected = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            variantNumber: null == variantNumber
                ? _value.variantNumber
                : variantNumber // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String?,
            instruction: freezed == instruction
                ? _value.instruction
                : instruction // ignore: cast_nullable_to_non_nullable
                      as String?,
            isSelected: null == isSelected
                ? _value.isSelected
                : isSelected // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TextVariantImplCopyWith<$Res>
    implements $TextVariantCopyWith<$Res> {
  factory _$$TextVariantImplCopyWith(
    _$TextVariantImpl value,
    $Res Function(_$TextVariantImpl) then,
  ) = __$$TextVariantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String text,
    int variantNumber,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'instruction') String? instruction,
    bool isSelected,
  });
}

/// @nodoc
class __$$TextVariantImplCopyWithImpl<$Res>
    extends _$TextVariantCopyWithImpl<$Res, _$TextVariantImpl>
    implements _$$TextVariantImplCopyWith<$Res> {
  __$$TextVariantImplCopyWithImpl(
    _$TextVariantImpl _value,
    $Res Function(_$TextVariantImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TextVariant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? variantNumber = null,
    Object? createdAt = freezed,
    Object? instruction = freezed,
    Object? isSelected = null,
  }) {
    return _then(
      _$TextVariantImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        variantNumber: null == variantNumber
            ? _value.variantNumber
            : variantNumber // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String?,
        instruction: freezed == instruction
            ? _value.instruction
            : instruction // ignore: cast_nullable_to_non_nullable
                  as String?,
        isSelected: null == isSelected
            ? _value.isSelected
            : isSelected // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TextVariantImpl implements _TextVariant {
  const _$TextVariantImpl({
    required this.id,
    required this.text,
    required this.variantNumber,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'instruction') this.instruction,
    this.isSelected = false,
  });

  factory _$TextVariantImpl.fromJson(Map<String, dynamic> json) =>
      _$$TextVariantImplFromJson(json);

  @override
  final String id;
  @override
  final String text;
  @override
  final int variantNumber;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @override
  @JsonKey(name: 'instruction')
  final String? instruction;
  // Инструкция, которая привела к этому варианту
  @override
  @JsonKey()
  final bool isSelected;

  @override
  String toString() {
    return 'TextVariant(id: $id, text: $text, variantNumber: $variantNumber, createdAt: $createdAt, instruction: $instruction, isSelected: $isSelected)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TextVariantImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.variantNumber, variantNumber) ||
                other.variantNumber == variantNumber) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.instruction, instruction) ||
                other.instruction == instruction) &&
            (identical(other.isSelected, isSelected) ||
                other.isSelected == isSelected));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    text,
    variantNumber,
    createdAt,
    instruction,
    isSelected,
  );

  /// Create a copy of TextVariant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TextVariantImplCopyWith<_$TextVariantImpl> get copyWith =>
      __$$TextVariantImplCopyWithImpl<_$TextVariantImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TextVariantImplToJson(this);
  }
}

abstract class _TextVariant implements TextVariant {
  const factory _TextVariant({
    required final String id,
    required final String text,
    required final int variantNumber,
    @JsonKey(name: 'created_at') final String? createdAt,
    @JsonKey(name: 'instruction') final String? instruction,
    final bool isSelected,
  }) = _$TextVariantImpl;

  factory _TextVariant.fromJson(Map<String, dynamic> json) =
      _$TextVariantImpl.fromJson;

  @override
  String get id;
  @override
  String get text;
  @override
  int get variantNumber;
  @override
  @JsonKey(name: 'created_at')
  String? get createdAt;
  @override
  @JsonKey(name: 'instruction')
  String? get instruction; // Инструкция, которая привела к этому варианту
  @override
  bool get isSelected;

  /// Create a copy of TextVariant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TextVariantImplCopyWith<_$TextVariantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ImageVariant _$ImageVariantFromJson(Map<String, dynamic> json) {
  return _ImageVariant.fromJson(json);
}

/// @nodoc
mixin _$ImageVariant {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String get imageUrl => throw _privateConstructorUsedError;
  int get variantNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'instruction')
  String? get instruction => throw _privateConstructorUsedError; // Инструкция для изменения
  bool get isSelected => throw _privateConstructorUsedError;

  /// Serializes this ImageVariant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ImageVariant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ImageVariantCopyWith<ImageVariant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ImageVariantCopyWith<$Res> {
  factory $ImageVariantCopyWith(
    ImageVariant value,
    $Res Function(ImageVariant) then,
  ) = _$ImageVariantCopyWithImpl<$Res, ImageVariant>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'image_url') String imageUrl,
    int variantNumber,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'instruction') String? instruction,
    bool isSelected,
  });
}

/// @nodoc
class _$ImageVariantCopyWithImpl<$Res, $Val extends ImageVariant>
    implements $ImageVariantCopyWith<$Res> {
  _$ImageVariantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ImageVariant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? imageUrl = null,
    Object? variantNumber = null,
    Object? createdAt = freezed,
    Object? instruction = freezed,
    Object? isSelected = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            imageUrl: null == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            variantNumber: null == variantNumber
                ? _value.variantNumber
                : variantNumber // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String?,
            instruction: freezed == instruction
                ? _value.instruction
                : instruction // ignore: cast_nullable_to_non_nullable
                      as String?,
            isSelected: null == isSelected
                ? _value.isSelected
                : isSelected // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ImageVariantImplCopyWith<$Res>
    implements $ImageVariantCopyWith<$Res> {
  factory _$$ImageVariantImplCopyWith(
    _$ImageVariantImpl value,
    $Res Function(_$ImageVariantImpl) then,
  ) = __$$ImageVariantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'image_url') String imageUrl,
    int variantNumber,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'instruction') String? instruction,
    bool isSelected,
  });
}

/// @nodoc
class __$$ImageVariantImplCopyWithImpl<$Res>
    extends _$ImageVariantCopyWithImpl<$Res, _$ImageVariantImpl>
    implements _$$ImageVariantImplCopyWith<$Res> {
  __$$ImageVariantImplCopyWithImpl(
    _$ImageVariantImpl _value,
    $Res Function(_$ImageVariantImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ImageVariant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? imageUrl = null,
    Object? variantNumber = null,
    Object? createdAt = freezed,
    Object? instruction = freezed,
    Object? isSelected = null,
  }) {
    return _then(
      _$ImageVariantImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        imageUrl: null == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        variantNumber: null == variantNumber
            ? _value.variantNumber
            : variantNumber // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String?,
        instruction: freezed == instruction
            ? _value.instruction
            : instruction // ignore: cast_nullable_to_non_nullable
                  as String?,
        isSelected: null == isSelected
            ? _value.isSelected
            : isSelected // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ImageVariantImpl implements _ImageVariant {
  const _$ImageVariantImpl({
    required this.id,
    @JsonKey(name: 'image_url') required this.imageUrl,
    required this.variantNumber,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'instruction') this.instruction,
    this.isSelected = false,
  });

  factory _$ImageVariantImpl.fromJson(Map<String, dynamic> json) =>
      _$$ImageVariantImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'image_url')
  final String imageUrl;
  @override
  final int variantNumber;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @override
  @JsonKey(name: 'instruction')
  final String? instruction;
  // Инструкция для изменения
  @override
  @JsonKey()
  final bool isSelected;

  @override
  String toString() {
    return 'ImageVariant(id: $id, imageUrl: $imageUrl, variantNumber: $variantNumber, createdAt: $createdAt, instruction: $instruction, isSelected: $isSelected)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImageVariantImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.variantNumber, variantNumber) ||
                other.variantNumber == variantNumber) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.instruction, instruction) ||
                other.instruction == instruction) &&
            (identical(other.isSelected, isSelected) ||
                other.isSelected == isSelected));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    imageUrl,
    variantNumber,
    createdAt,
    instruction,
    isSelected,
  );

  /// Create a copy of ImageVariant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ImageVariantImplCopyWith<_$ImageVariantImpl> get copyWith =>
      __$$ImageVariantImplCopyWithImpl<_$ImageVariantImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ImageVariantImplToJson(this);
  }
}

abstract class _ImageVariant implements ImageVariant {
  const factory _ImageVariant({
    required final String id,
    @JsonKey(name: 'image_url') required final String imageUrl,
    required final int variantNumber,
    @JsonKey(name: 'created_at') final String? createdAt,
    @JsonKey(name: 'instruction') final String? instruction,
    final bool isSelected,
  }) = _$ImageVariantImpl;

  factory _ImageVariant.fromJson(Map<String, dynamic> json) =
      _$ImageVariantImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'image_url')
  String get imageUrl;
  @override
  int get variantNumber;
  @override
  @JsonKey(name: 'created_at')
  String? get createdAt;
  @override
  @JsonKey(name: 'instruction')
  String? get instruction; // Инструкция для изменения
  @override
  bool get isSelected;

  /// Create a copy of ImageVariant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ImageVariantImplCopyWith<_$ImageVariantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SceneVariants _$SceneVariantsFromJson(Map<String, dynamic> json) {
  return _SceneVariants.fromJson(json);
}

/// @nodoc
mixin _$SceneVariants {
  String get sceneId => throw _privateConstructorUsedError;
  List<TextVariant> get textVariants => throw _privateConstructorUsedError;
  List<ImageVariant> get imageVariants => throw _privateConstructorUsedError;
  int get maxTextVariants => throw _privateConstructorUsedError;
  int get maxImageVariants => throw _privateConstructorUsedError;
  String? get selectedTextVariantId => throw _privateConstructorUsedError;
  String? get selectedImageVariantId => throw _privateConstructorUsedError;

  /// Serializes this SceneVariants to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SceneVariants
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SceneVariantsCopyWith<SceneVariants> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SceneVariantsCopyWith<$Res> {
  factory $SceneVariantsCopyWith(
    SceneVariants value,
    $Res Function(SceneVariants) then,
  ) = _$SceneVariantsCopyWithImpl<$Res, SceneVariants>;
  @useResult
  $Res call({
    String sceneId,
    List<TextVariant> textVariants,
    List<ImageVariant> imageVariants,
    int maxTextVariants,
    int maxImageVariants,
    String? selectedTextVariantId,
    String? selectedImageVariantId,
  });
}

/// @nodoc
class _$SceneVariantsCopyWithImpl<$Res, $Val extends SceneVariants>
    implements $SceneVariantsCopyWith<$Res> {
  _$SceneVariantsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SceneVariants
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sceneId = null,
    Object? textVariants = null,
    Object? imageVariants = null,
    Object? maxTextVariants = null,
    Object? maxImageVariants = null,
    Object? selectedTextVariantId = freezed,
    Object? selectedImageVariantId = freezed,
  }) {
    return _then(
      _value.copyWith(
            sceneId: null == sceneId
                ? _value.sceneId
                : sceneId // ignore: cast_nullable_to_non_nullable
                      as String,
            textVariants: null == textVariants
                ? _value.textVariants
                : textVariants // ignore: cast_nullable_to_non_nullable
                      as List<TextVariant>,
            imageVariants: null == imageVariants
                ? _value.imageVariants
                : imageVariants // ignore: cast_nullable_to_non_nullable
                      as List<ImageVariant>,
            maxTextVariants: null == maxTextVariants
                ? _value.maxTextVariants
                : maxTextVariants // ignore: cast_nullable_to_non_nullable
                      as int,
            maxImageVariants: null == maxImageVariants
                ? _value.maxImageVariants
                : maxImageVariants // ignore: cast_nullable_to_non_nullable
                      as int,
            selectedTextVariantId: freezed == selectedTextVariantId
                ? _value.selectedTextVariantId
                : selectedTextVariantId // ignore: cast_nullable_to_non_nullable
                      as String?,
            selectedImageVariantId: freezed == selectedImageVariantId
                ? _value.selectedImageVariantId
                : selectedImageVariantId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SceneVariantsImplCopyWith<$Res>
    implements $SceneVariantsCopyWith<$Res> {
  factory _$$SceneVariantsImplCopyWith(
    _$SceneVariantsImpl value,
    $Res Function(_$SceneVariantsImpl) then,
  ) = __$$SceneVariantsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String sceneId,
    List<TextVariant> textVariants,
    List<ImageVariant> imageVariants,
    int maxTextVariants,
    int maxImageVariants,
    String? selectedTextVariantId,
    String? selectedImageVariantId,
  });
}

/// @nodoc
class __$$SceneVariantsImplCopyWithImpl<$Res>
    extends _$SceneVariantsCopyWithImpl<$Res, _$SceneVariantsImpl>
    implements _$$SceneVariantsImplCopyWith<$Res> {
  __$$SceneVariantsImplCopyWithImpl(
    _$SceneVariantsImpl _value,
    $Res Function(_$SceneVariantsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SceneVariants
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sceneId = null,
    Object? textVariants = null,
    Object? imageVariants = null,
    Object? maxTextVariants = null,
    Object? maxImageVariants = null,
    Object? selectedTextVariantId = freezed,
    Object? selectedImageVariantId = freezed,
  }) {
    return _then(
      _$SceneVariantsImpl(
        sceneId: null == sceneId
            ? _value.sceneId
            : sceneId // ignore: cast_nullable_to_non_nullable
                  as String,
        textVariants: null == textVariants
            ? _value._textVariants
            : textVariants // ignore: cast_nullable_to_non_nullable
                  as List<TextVariant>,
        imageVariants: null == imageVariants
            ? _value._imageVariants
            : imageVariants // ignore: cast_nullable_to_non_nullable
                  as List<ImageVariant>,
        maxTextVariants: null == maxTextVariants
            ? _value.maxTextVariants
            : maxTextVariants // ignore: cast_nullable_to_non_nullable
                  as int,
        maxImageVariants: null == maxImageVariants
            ? _value.maxImageVariants
            : maxImageVariants // ignore: cast_nullable_to_non_nullable
                  as int,
        selectedTextVariantId: freezed == selectedTextVariantId
            ? _value.selectedTextVariantId
            : selectedTextVariantId // ignore: cast_nullable_to_non_nullable
                  as String?,
        selectedImageVariantId: freezed == selectedImageVariantId
            ? _value.selectedImageVariantId
            : selectedImageVariantId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SceneVariantsImpl implements _SceneVariants {
  const _$SceneVariantsImpl({
    required this.sceneId,
    final List<TextVariant> textVariants = const [],
    final List<ImageVariant> imageVariants = const [],
    this.maxTextVariants = 5,
    this.maxImageVariants = 3,
    this.selectedTextVariantId,
    this.selectedImageVariantId,
  }) : _textVariants = textVariants,
       _imageVariants = imageVariants;

  factory _$SceneVariantsImpl.fromJson(Map<String, dynamic> json) =>
      _$$SceneVariantsImplFromJson(json);

  @override
  final String sceneId;
  final List<TextVariant> _textVariants;
  @override
  @JsonKey()
  List<TextVariant> get textVariants {
    if (_textVariants is EqualUnmodifiableListView) return _textVariants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_textVariants);
  }

  final List<ImageVariant> _imageVariants;
  @override
  @JsonKey()
  List<ImageVariant> get imageVariants {
    if (_imageVariants is EqualUnmodifiableListView) return _imageVariants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imageVariants);
  }

  @override
  @JsonKey()
  final int maxTextVariants;
  @override
  @JsonKey()
  final int maxImageVariants;
  @override
  final String? selectedTextVariantId;
  @override
  final String? selectedImageVariantId;

  @override
  String toString() {
    return 'SceneVariants(sceneId: $sceneId, textVariants: $textVariants, imageVariants: $imageVariants, maxTextVariants: $maxTextVariants, maxImageVariants: $maxImageVariants, selectedTextVariantId: $selectedTextVariantId, selectedImageVariantId: $selectedImageVariantId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SceneVariantsImpl &&
            (identical(other.sceneId, sceneId) || other.sceneId == sceneId) &&
            const DeepCollectionEquality().equals(
              other._textVariants,
              _textVariants,
            ) &&
            const DeepCollectionEquality().equals(
              other._imageVariants,
              _imageVariants,
            ) &&
            (identical(other.maxTextVariants, maxTextVariants) ||
                other.maxTextVariants == maxTextVariants) &&
            (identical(other.maxImageVariants, maxImageVariants) ||
                other.maxImageVariants == maxImageVariants) &&
            (identical(other.selectedTextVariantId, selectedTextVariantId) ||
                other.selectedTextVariantId == selectedTextVariantId) &&
            (identical(other.selectedImageVariantId, selectedImageVariantId) ||
                other.selectedImageVariantId == selectedImageVariantId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    sceneId,
    const DeepCollectionEquality().hash(_textVariants),
    const DeepCollectionEquality().hash(_imageVariants),
    maxTextVariants,
    maxImageVariants,
    selectedTextVariantId,
    selectedImageVariantId,
  );

  /// Create a copy of SceneVariants
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SceneVariantsImplCopyWith<_$SceneVariantsImpl> get copyWith =>
      __$$SceneVariantsImplCopyWithImpl<_$SceneVariantsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SceneVariantsImplToJson(this);
  }
}

abstract class _SceneVariants implements SceneVariants {
  const factory _SceneVariants({
    required final String sceneId,
    final List<TextVariant> textVariants,
    final List<ImageVariant> imageVariants,
    final int maxTextVariants,
    final int maxImageVariants,
    final String? selectedTextVariantId,
    final String? selectedImageVariantId,
  }) = _$SceneVariantsImpl;

  factory _SceneVariants.fromJson(Map<String, dynamic> json) =
      _$SceneVariantsImpl.fromJson;

  @override
  String get sceneId;
  @override
  List<TextVariant> get textVariants;
  @override
  List<ImageVariant> get imageVariants;
  @override
  int get maxTextVariants;
  @override
  int get maxImageVariants;
  @override
  String? get selectedTextVariantId;
  @override
  String? get selectedImageVariantId;

  /// Create a copy of SceneVariants
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SceneVariantsImplCopyWith<_$SceneVariantsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
