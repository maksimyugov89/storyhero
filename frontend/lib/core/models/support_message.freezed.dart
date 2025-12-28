// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'support_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SupportMessage _$SupportMessageFromJson(Map<String, dynamic> json) {
  return _SupportMessage.fromJson(json);
}

/// @nodoc
mixin _$SupportMessage {
  @JsonKey(fromJson: _supportMessageIdToString)
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String? get userId => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String get type =>
      throw _privateConstructorUsedError; // 'suggestion', 'bug', 'question'
  String get message => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // 'new', 'answered', 'closed'
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at', fromJson: _dateTimeFromJson)
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'has_unread_replies')
  bool get hasUnreadReplies => throw _privateConstructorUsedError;
  @JsonKey(name: 'replies_count')
  int get repliesCount => throw _privateConstructorUsedError;

  /// Serializes this SupportMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SupportMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SupportMessageCopyWith<SupportMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SupportMessageCopyWith<$Res> {
  factory $SupportMessageCopyWith(
    SupportMessage value,
    $Res Function(SupportMessage) then,
  ) = _$SupportMessageCopyWithImpl<$Res, SupportMessage>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _supportMessageIdToString) String id,
    @JsonKey(name: 'user_id') String? userId,
    String? name,
    String? email,
    String type,
    String message,
    String status,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    DateTime createdAt,
    @JsonKey(name: 'updated_at', fromJson: _dateTimeFromJson)
    DateTime updatedAt,
    @JsonKey(name: 'has_unread_replies') bool hasUnreadReplies,
    @JsonKey(name: 'replies_count') int repliesCount,
  });
}

/// @nodoc
class _$SupportMessageCopyWithImpl<$Res, $Val extends SupportMessage>
    implements $SupportMessageCopyWith<$Res> {
  _$SupportMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SupportMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = freezed,
    Object? name = freezed,
    Object? email = freezed,
    Object? type = null,
    Object? message = null,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? hasUnreadReplies = null,
    Object? repliesCount = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: freezed == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String?,
            name: freezed == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String?,
            email: freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String?,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            hasUnreadReplies: null == hasUnreadReplies
                ? _value.hasUnreadReplies
                : hasUnreadReplies // ignore: cast_nullable_to_non_nullable
                      as bool,
            repliesCount: null == repliesCount
                ? _value.repliesCount
                : repliesCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SupportMessageImplCopyWith<$Res>
    implements $SupportMessageCopyWith<$Res> {
  factory _$$SupportMessageImplCopyWith(
    _$SupportMessageImpl value,
    $Res Function(_$SupportMessageImpl) then,
  ) = __$$SupportMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _supportMessageIdToString) String id,
    @JsonKey(name: 'user_id') String? userId,
    String? name,
    String? email,
    String type,
    String message,
    String status,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    DateTime createdAt,
    @JsonKey(name: 'updated_at', fromJson: _dateTimeFromJson)
    DateTime updatedAt,
    @JsonKey(name: 'has_unread_replies') bool hasUnreadReplies,
    @JsonKey(name: 'replies_count') int repliesCount,
  });
}

/// @nodoc
class __$$SupportMessageImplCopyWithImpl<$Res>
    extends _$SupportMessageCopyWithImpl<$Res, _$SupportMessageImpl>
    implements _$$SupportMessageImplCopyWith<$Res> {
  __$$SupportMessageImplCopyWithImpl(
    _$SupportMessageImpl _value,
    $Res Function(_$SupportMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SupportMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = freezed,
    Object? name = freezed,
    Object? email = freezed,
    Object? type = null,
    Object? message = null,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? hasUnreadReplies = null,
    Object? repliesCount = null,
  }) {
    return _then(
      _$SupportMessageImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: freezed == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String?,
        name: freezed == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        email: freezed == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String?,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        hasUnreadReplies: null == hasUnreadReplies
            ? _value.hasUnreadReplies
            : hasUnreadReplies // ignore: cast_nullable_to_non_nullable
                  as bool,
        repliesCount: null == repliesCount
            ? _value.repliesCount
            : repliesCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SupportMessageImpl implements _SupportMessage {
  const _$SupportMessageImpl({
    @JsonKey(fromJson: _supportMessageIdToString) required this.id,
    @JsonKey(name: 'user_id') this.userId,
    this.name,
    this.email,
    required this.type,
    required this.message,
    required this.status,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    required this.createdAt,
    @JsonKey(name: 'updated_at', fromJson: _dateTimeFromJson)
    required this.updatedAt,
    @JsonKey(name: 'has_unread_replies') this.hasUnreadReplies = false,
    @JsonKey(name: 'replies_count') this.repliesCount = 0,
  });

  factory _$SupportMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$SupportMessageImplFromJson(json);

  @override
  @JsonKey(fromJson: _supportMessageIdToString)
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String? userId;
  @override
  final String? name;
  @override
  final String? email;
  @override
  final String type;
  // 'suggestion', 'bug', 'question'
  @override
  final String message;
  @override
  final String status;
  // 'new', 'answered', 'closed'
  @override
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at', fromJson: _dateTimeFromJson)
  final DateTime updatedAt;
  @override
  @JsonKey(name: 'has_unread_replies')
  final bool hasUnreadReplies;
  @override
  @JsonKey(name: 'replies_count')
  final int repliesCount;

  @override
  String toString() {
    return 'SupportMessage(id: $id, userId: $userId, name: $name, email: $email, type: $type, message: $message, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, hasUnreadReplies: $hasUnreadReplies, repliesCount: $repliesCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupportMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.hasUnreadReplies, hasUnreadReplies) ||
                other.hasUnreadReplies == hasUnreadReplies) &&
            (identical(other.repliesCount, repliesCount) ||
                other.repliesCount == repliesCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    name,
    email,
    type,
    message,
    status,
    createdAt,
    updatedAt,
    hasUnreadReplies,
    repliesCount,
  );

  /// Create a copy of SupportMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SupportMessageImplCopyWith<_$SupportMessageImpl> get copyWith =>
      __$$SupportMessageImplCopyWithImpl<_$SupportMessageImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SupportMessageImplToJson(this);
  }
}

abstract class _SupportMessage implements SupportMessage {
  const factory _SupportMessage({
    @JsonKey(fromJson: _supportMessageIdToString) required final String id,
    @JsonKey(name: 'user_id') final String? userId,
    final String? name,
    final String? email,
    required final String type,
    required final String message,
    required final String status,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    required final DateTime createdAt,
    @JsonKey(name: 'updated_at', fromJson: _dateTimeFromJson)
    required final DateTime updatedAt,
    @JsonKey(name: 'has_unread_replies') final bool hasUnreadReplies,
    @JsonKey(name: 'replies_count') final int repliesCount,
  }) = _$SupportMessageImpl;

  factory _SupportMessage.fromJson(Map<String, dynamic> json) =
      _$SupportMessageImpl.fromJson;

  @override
  @JsonKey(fromJson: _supportMessageIdToString)
  String get id;
  @override
  @JsonKey(name: 'user_id')
  String? get userId;
  @override
  String? get name;
  @override
  String? get email;
  @override
  String get type; // 'suggestion', 'bug', 'question'
  @override
  String get message;
  @override
  String get status; // 'new', 'answered', 'closed'
  @override
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at', fromJson: _dateTimeFromJson)
  DateTime get updatedAt;
  @override
  @JsonKey(name: 'has_unread_replies')
  bool get hasUnreadReplies;
  @override
  @JsonKey(name: 'replies_count')
  int get repliesCount;

  /// Create a copy of SupportMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SupportMessageImplCopyWith<_$SupportMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
