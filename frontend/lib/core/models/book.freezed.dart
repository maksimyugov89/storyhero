// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Book _$BookFromJson(Map<String, dynamic> json) {
  return _Book.fromJson(json);
}

/// @nodoc
mixin _$Book {
  // обязательные поля
  @JsonKey(fromJson: _bookIdToString)
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'child_id', fromJson: _childIdToString)
  String get childId => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String? get userId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  DateTime get createdAt => throw _privateConstructorUsedError; // статус книги (draft / editing / final)
  @JsonKey(name: 'status')
  String get status => throw _privateConstructorUsedError; // необязательные поля
  @JsonKey(name: 'cover_url')
  String? get coverUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'final_pdf_url')
  String? get finalPdfUrl => throw _privateConstructorUsedError; // Статус оплаты книги
  @JsonKey(name: 'is_paid')
  bool get isPaid => throw _privateConstructorUsedError;
  @JsonKey(name: 'pages')
  List<dynamic>? get pages => throw _privateConstructorUsedError;
  @JsonKey(name: 'edit_history')
  List<dynamic>? get editHistory => throw _privateConstructorUsedError;
  @JsonKey(name: 'images_final')
  List<dynamic>? get imagesFinal => throw _privateConstructorUsedError;

  /// Serializes this Book to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BookCopyWith<Book> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BookCopyWith<$Res> {
  factory $BookCopyWith(Book value, $Res Function(Book) then) =
      _$BookCopyWithImpl<$Res, Book>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _bookIdToString) String id,
    @JsonKey(name: 'child_id', fromJson: _childIdToString) String childId,
    @JsonKey(name: 'user_id') String? userId,
    String title,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    DateTime createdAt,
    @JsonKey(name: 'status') String status,
    @JsonKey(name: 'cover_url') String? coverUrl,
    @JsonKey(name: 'final_pdf_url') String? finalPdfUrl,
    @JsonKey(name: 'is_paid') bool isPaid,
    @JsonKey(name: 'pages') List<dynamic>? pages,
    @JsonKey(name: 'edit_history') List<dynamic>? editHistory,
    @JsonKey(name: 'images_final') List<dynamic>? imagesFinal,
  });
}

/// @nodoc
class _$BookCopyWithImpl<$Res, $Val extends Book>
    implements $BookCopyWith<$Res> {
  _$BookCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? childId = null,
    Object? userId = freezed,
    Object? title = null,
    Object? createdAt = null,
    Object? status = null,
    Object? coverUrl = freezed,
    Object? finalPdfUrl = freezed,
    Object? isPaid = null,
    Object? pages = freezed,
    Object? editHistory = freezed,
    Object? imagesFinal = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            childId: null == childId
                ? _value.childId
                : childId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: freezed == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String?,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            coverUrl: freezed == coverUrl
                ? _value.coverUrl
                : coverUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            finalPdfUrl: freezed == finalPdfUrl
                ? _value.finalPdfUrl
                : finalPdfUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            isPaid: null == isPaid
                ? _value.isPaid
                : isPaid // ignore: cast_nullable_to_non_nullable
                      as bool,
            pages: freezed == pages
                ? _value.pages
                : pages // ignore: cast_nullable_to_non_nullable
                      as List<dynamic>?,
            editHistory: freezed == editHistory
                ? _value.editHistory
                : editHistory // ignore: cast_nullable_to_non_nullable
                      as List<dynamic>?,
            imagesFinal: freezed == imagesFinal
                ? _value.imagesFinal
                : imagesFinal // ignore: cast_nullable_to_non_nullable
                      as List<dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BookImplCopyWith<$Res> implements $BookCopyWith<$Res> {
  factory _$$BookImplCopyWith(
    _$BookImpl value,
    $Res Function(_$BookImpl) then,
  ) = __$$BookImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _bookIdToString) String id,
    @JsonKey(name: 'child_id', fromJson: _childIdToString) String childId,
    @JsonKey(name: 'user_id') String? userId,
    String title,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    DateTime createdAt,
    @JsonKey(name: 'status') String status,
    @JsonKey(name: 'cover_url') String? coverUrl,
    @JsonKey(name: 'final_pdf_url') String? finalPdfUrl,
    @JsonKey(name: 'is_paid') bool isPaid,
    @JsonKey(name: 'pages') List<dynamic>? pages,
    @JsonKey(name: 'edit_history') List<dynamic>? editHistory,
    @JsonKey(name: 'images_final') List<dynamic>? imagesFinal,
  });
}

/// @nodoc
class __$$BookImplCopyWithImpl<$Res>
    extends _$BookCopyWithImpl<$Res, _$BookImpl>
    implements _$$BookImplCopyWith<$Res> {
  __$$BookImplCopyWithImpl(_$BookImpl _value, $Res Function(_$BookImpl) _then)
    : super(_value, _then);

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? childId = null,
    Object? userId = freezed,
    Object? title = null,
    Object? createdAt = null,
    Object? status = null,
    Object? coverUrl = freezed,
    Object? finalPdfUrl = freezed,
    Object? isPaid = null,
    Object? pages = freezed,
    Object? editHistory = freezed,
    Object? imagesFinal = freezed,
  }) {
    return _then(
      _$BookImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        childId: null == childId
            ? _value.childId
            : childId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: freezed == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String?,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        coverUrl: freezed == coverUrl
            ? _value.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        finalPdfUrl: freezed == finalPdfUrl
            ? _value.finalPdfUrl
            : finalPdfUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        isPaid: null == isPaid
            ? _value.isPaid
            : isPaid // ignore: cast_nullable_to_non_nullable
                  as bool,
        pages: freezed == pages
            ? _value._pages
            : pages // ignore: cast_nullable_to_non_nullable
                  as List<dynamic>?,
        editHistory: freezed == editHistory
            ? _value._editHistory
            : editHistory // ignore: cast_nullable_to_non_nullable
                  as List<dynamic>?,
        imagesFinal: freezed == imagesFinal
            ? _value._imagesFinal
            : imagesFinal // ignore: cast_nullable_to_non_nullable
                  as List<dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BookImpl implements _Book {
  const _$BookImpl({
    @JsonKey(fromJson: _bookIdToString) required this.id,
    @JsonKey(name: 'child_id', fromJson: _childIdToString)
    required this.childId,
    @JsonKey(name: 'user_id') this.userId,
    required this.title,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    required this.createdAt,
    @JsonKey(name: 'status') this.status = 'draft',
    @JsonKey(name: 'cover_url') this.coverUrl,
    @JsonKey(name: 'final_pdf_url') this.finalPdfUrl,
    @JsonKey(name: 'is_paid') this.isPaid = false,
    @JsonKey(name: 'pages') final List<dynamic>? pages,
    @JsonKey(name: 'edit_history') final List<dynamic>? editHistory,
    @JsonKey(name: 'images_final') final List<dynamic>? imagesFinal,
  }) : _pages = pages,
       _editHistory = editHistory,
       _imagesFinal = imagesFinal;

  factory _$BookImpl.fromJson(Map<String, dynamic> json) =>
      _$$BookImplFromJson(json);

  // обязательные поля
  @override
  @JsonKey(fromJson: _bookIdToString)
  final String id;
  @override
  @JsonKey(name: 'child_id', fromJson: _childIdToString)
  final String childId;
  @override
  @JsonKey(name: 'user_id')
  final String? userId;
  @override
  final String title;
  @override
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  final DateTime createdAt;
  // статус книги (draft / editing / final)
  @override
  @JsonKey(name: 'status')
  final String status;
  // необязательные поля
  @override
  @JsonKey(name: 'cover_url')
  final String? coverUrl;
  @override
  @JsonKey(name: 'final_pdf_url')
  final String? finalPdfUrl;
  // Статус оплаты книги
  @override
  @JsonKey(name: 'is_paid')
  final bool isPaid;
  final List<dynamic>? _pages;
  @override
  @JsonKey(name: 'pages')
  List<dynamic>? get pages {
    final value = _pages;
    if (value == null) return null;
    if (_pages is EqualUnmodifiableListView) return _pages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<dynamic>? _editHistory;
  @override
  @JsonKey(name: 'edit_history')
  List<dynamic>? get editHistory {
    final value = _editHistory;
    if (value == null) return null;
    if (_editHistory is EqualUnmodifiableListView) return _editHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<dynamic>? _imagesFinal;
  @override
  @JsonKey(name: 'images_final')
  List<dynamic>? get imagesFinal {
    final value = _imagesFinal;
    if (value == null) return null;
    if (_imagesFinal is EqualUnmodifiableListView) return _imagesFinal;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'Book(id: $id, childId: $childId, userId: $userId, title: $title, createdAt: $createdAt, status: $status, coverUrl: $coverUrl, finalPdfUrl: $finalPdfUrl, isPaid: $isPaid, pages: $pages, editHistory: $editHistory, imagesFinal: $imagesFinal)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BookImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.childId, childId) || other.childId == childId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.finalPdfUrl, finalPdfUrl) ||
                other.finalPdfUrl == finalPdfUrl) &&
            (identical(other.isPaid, isPaid) || other.isPaid == isPaid) &&
            const DeepCollectionEquality().equals(other._pages, _pages) &&
            const DeepCollectionEquality().equals(
              other._editHistory,
              _editHistory,
            ) &&
            const DeepCollectionEquality().equals(
              other._imagesFinal,
              _imagesFinal,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    childId,
    userId,
    title,
    createdAt,
    status,
    coverUrl,
    finalPdfUrl,
    isPaid,
    const DeepCollectionEquality().hash(_pages),
    const DeepCollectionEquality().hash(_editHistory),
    const DeepCollectionEquality().hash(_imagesFinal),
  );

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BookImplCopyWith<_$BookImpl> get copyWith =>
      __$$BookImplCopyWithImpl<_$BookImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BookImplToJson(this);
  }
}

abstract class _Book implements Book {
  const factory _Book({
    @JsonKey(fromJson: _bookIdToString) required final String id,
    @JsonKey(name: 'child_id', fromJson: _childIdToString)
    required final String childId,
    @JsonKey(name: 'user_id') final String? userId,
    required final String title,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    required final DateTime createdAt,
    @JsonKey(name: 'status') final String status,
    @JsonKey(name: 'cover_url') final String? coverUrl,
    @JsonKey(name: 'final_pdf_url') final String? finalPdfUrl,
    @JsonKey(name: 'is_paid') final bool isPaid,
    @JsonKey(name: 'pages') final List<dynamic>? pages,
    @JsonKey(name: 'edit_history') final List<dynamic>? editHistory,
    @JsonKey(name: 'images_final') final List<dynamic>? imagesFinal,
  }) = _$BookImpl;

  factory _Book.fromJson(Map<String, dynamic> json) = _$BookImpl.fromJson;

  // обязательные поля
  @override
  @JsonKey(fromJson: _bookIdToString)
  String get id;
  @override
  @JsonKey(name: 'child_id', fromJson: _childIdToString)
  String get childId;
  @override
  @JsonKey(name: 'user_id')
  String? get userId;
  @override
  String get title;
  @override
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  DateTime get createdAt; // статус книги (draft / editing / final)
  @override
  @JsonKey(name: 'status')
  String get status; // необязательные поля
  @override
  @JsonKey(name: 'cover_url')
  String? get coverUrl;
  @override
  @JsonKey(name: 'final_pdf_url')
  String? get finalPdfUrl; // Статус оплаты книги
  @override
  @JsonKey(name: 'is_paid')
  bool get isPaid;
  @override
  @JsonKey(name: 'pages')
  List<dynamic>? get pages;
  @override
  @JsonKey(name: 'edit_history')
  List<dynamic>? get editHistory;
  @override
  @JsonKey(name: 'images_final')
  List<dynamic>? get imagesFinal;

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BookImplCopyWith<_$BookImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
