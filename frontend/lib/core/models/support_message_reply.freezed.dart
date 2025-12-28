// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'support_message_reply.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SupportMessageReply _$SupportMessageReplyFromJson(Map<String, dynamic> json) {
  return _SupportMessageReply.fromJson(json);
}

/// @nodoc
mixin _$SupportMessageReply {
  @JsonKey(fromJson: _supportMessageReplyIdToString)
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'message_id', fromJson: _messageIdToString)
  String get messageId => throw _privateConstructorUsedError;
  @JsonKey(name: 'reply_text')
  String get replyText => throw _privateConstructorUsedError;
  @JsonKey(name: 'replied_by')
  String get repliedBy => throw _privateConstructorUsedError; // 'telegram', 'admin_user_id', 'user_{user_id}'
  @JsonKey(name: 'is_read')
  bool get isRead => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this SupportMessageReply to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SupportMessageReply
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SupportMessageReplyCopyWith<SupportMessageReply> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SupportMessageReplyCopyWith<$Res> {
  factory $SupportMessageReplyCopyWith(
    SupportMessageReply value,
    $Res Function(SupportMessageReply) then,
  ) = _$SupportMessageReplyCopyWithImpl<$Res, SupportMessageReply>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _supportMessageReplyIdToString) String id,
    @JsonKey(name: 'message_id', fromJson: _messageIdToString) String messageId,
    @JsonKey(name: 'reply_text') String replyText,
    @JsonKey(name: 'replied_by') String repliedBy,
    @JsonKey(name: 'is_read') bool isRead,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    DateTime createdAt,
  });
}

/// @nodoc
class _$SupportMessageReplyCopyWithImpl<$Res, $Val extends SupportMessageReply>
    implements $SupportMessageReplyCopyWith<$Res> {
  _$SupportMessageReplyCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SupportMessageReply
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? messageId = null,
    Object? replyText = null,
    Object? repliedBy = null,
    Object? isRead = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            messageId: null == messageId
                ? _value.messageId
                : messageId // ignore: cast_nullable_to_non_nullable
                      as String,
            replyText: null == replyText
                ? _value.replyText
                : replyText // ignore: cast_nullable_to_non_nullable
                      as String,
            repliedBy: null == repliedBy
                ? _value.repliedBy
                : repliedBy // ignore: cast_nullable_to_non_nullable
                      as String,
            isRead: null == isRead
                ? _value.isRead
                : isRead // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SupportMessageReplyImplCopyWith<$Res>
    implements $SupportMessageReplyCopyWith<$Res> {
  factory _$$SupportMessageReplyImplCopyWith(
    _$SupportMessageReplyImpl value,
    $Res Function(_$SupportMessageReplyImpl) then,
  ) = __$$SupportMessageReplyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _supportMessageReplyIdToString) String id,
    @JsonKey(name: 'message_id', fromJson: _messageIdToString) String messageId,
    @JsonKey(name: 'reply_text') String replyText,
    @JsonKey(name: 'replied_by') String repliedBy,
    @JsonKey(name: 'is_read') bool isRead,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    DateTime createdAt,
  });
}

/// @nodoc
class __$$SupportMessageReplyImplCopyWithImpl<$Res>
    extends _$SupportMessageReplyCopyWithImpl<$Res, _$SupportMessageReplyImpl>
    implements _$$SupportMessageReplyImplCopyWith<$Res> {
  __$$SupportMessageReplyImplCopyWithImpl(
    _$SupportMessageReplyImpl _value,
    $Res Function(_$SupportMessageReplyImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SupportMessageReply
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? messageId = null,
    Object? replyText = null,
    Object? repliedBy = null,
    Object? isRead = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$SupportMessageReplyImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        messageId: null == messageId
            ? _value.messageId
            : messageId // ignore: cast_nullable_to_non_nullable
                  as String,
        replyText: null == replyText
            ? _value.replyText
            : replyText // ignore: cast_nullable_to_non_nullable
                  as String,
        repliedBy: null == repliedBy
            ? _value.repliedBy
            : repliedBy // ignore: cast_nullable_to_non_nullable
                  as String,
        isRead: null == isRead
            ? _value.isRead
            : isRead // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SupportMessageReplyImpl implements _SupportMessageReply {
  const _$SupportMessageReplyImpl({
    @JsonKey(fromJson: _supportMessageReplyIdToString) required this.id,
    @JsonKey(name: 'message_id', fromJson: _messageIdToString)
    required this.messageId,
    @JsonKey(name: 'reply_text') required this.replyText,
    @JsonKey(name: 'replied_by') required this.repliedBy,
    @JsonKey(name: 'is_read') this.isRead = false,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    required this.createdAt,
  });

  factory _$SupportMessageReplyImpl.fromJson(Map<String, dynamic> json) =>
      _$$SupportMessageReplyImplFromJson(json);

  @override
  @JsonKey(fromJson: _supportMessageReplyIdToString)
  final String id;
  @override
  @JsonKey(name: 'message_id', fromJson: _messageIdToString)
  final String messageId;
  @override
  @JsonKey(name: 'reply_text')
  final String replyText;
  @override
  @JsonKey(name: 'replied_by')
  final String repliedBy;
  // 'telegram', 'admin_user_id', 'user_{user_id}'
  @override
  @JsonKey(name: 'is_read')
  final bool isRead;
  @override
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  final DateTime createdAt;

  @override
  String toString() {
    return 'SupportMessageReply(id: $id, messageId: $messageId, replyText: $replyText, repliedBy: $repliedBy, isRead: $isRead, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupportMessageReplyImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.messageId, messageId) ||
                other.messageId == messageId) &&
            (identical(other.replyText, replyText) ||
                other.replyText == replyText) &&
            (identical(other.repliedBy, repliedBy) ||
                other.repliedBy == repliedBy) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    messageId,
    replyText,
    repliedBy,
    isRead,
    createdAt,
  );

  /// Create a copy of SupportMessageReply
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SupportMessageReplyImplCopyWith<_$SupportMessageReplyImpl> get copyWith =>
      __$$SupportMessageReplyImplCopyWithImpl<_$SupportMessageReplyImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SupportMessageReplyImplToJson(this);
  }
}

abstract class _SupportMessageReply implements SupportMessageReply {
  const factory _SupportMessageReply({
    @JsonKey(fromJson: _supportMessageReplyIdToString) required final String id,
    @JsonKey(name: 'message_id', fromJson: _messageIdToString)
    required final String messageId,
    @JsonKey(name: 'reply_text') required final String replyText,
    @JsonKey(name: 'replied_by') required final String repliedBy,
    @JsonKey(name: 'is_read') final bool isRead,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    required final DateTime createdAt,
  }) = _$SupportMessageReplyImpl;

  factory _SupportMessageReply.fromJson(Map<String, dynamic> json) =
      _$SupportMessageReplyImpl.fromJson;

  @override
  @JsonKey(fromJson: _supportMessageReplyIdToString)
  String get id;
  @override
  @JsonKey(name: 'message_id', fromJson: _messageIdToString)
  String get messageId;
  @override
  @JsonKey(name: 'reply_text')
  String get replyText;
  @override
  @JsonKey(name: 'replied_by')
  String get repliedBy; // 'telegram', 'admin_user_id', 'user_{user_id}'
  @override
  @JsonKey(name: 'is_read')
  bool get isRead;
  @override
  @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
  DateTime get createdAt;

  /// Create a copy of SupportMessageReply
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SupportMessageReplyImplCopyWith<_$SupportMessageReplyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
