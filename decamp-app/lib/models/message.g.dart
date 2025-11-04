// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessageImpl _$$MessageImplFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(r'_$MessageImpl', json, ($checkedConvert) {
  final val = _$MessageImpl(
    id: $checkedConvert('id', (v) => v as String),
    sessionId: $checkedConvert('sessionId', (v) => v as String),
    userId: $checkedConvert('userId', (v) => v as String),
    userName: $checkedConvert('userName', (v) => v as String),
    content: $checkedConvert('content', (v) => v as String),
    timestamp: $checkedConvert('timestamp', (v) => DateTime.parse(v as String)),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    imageUrl: $checkedConvert('imageUrl', (v) => v as String?),
    metadata: $checkedConvert('metadata', (v) => v as Map<String, dynamic>?),
  );
  return val;
});

Map<String, dynamic> _$$MessageImplToJson(_$MessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionId': instance.sessionId,
      'userId': instance.userId,
      'userName': instance.userName,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'imageUrl': instance.imageUrl,
      'metadata': instance.metadata,
    };
