// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isArchivedMeta =
      const VerificationMeta('isArchived');
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
      'is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, projectId, description, timestamp, createdAt, updatedAt, isArchived];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<SessionEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
          _isArchivedMeta,
          isArchived.isAcceptableOrUnknown(
              data['is_archived']!, _isArchivedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      isArchived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionEntity extends DataClass implements Insertable<SessionEntity> {
  /// Unique identifier for the session
  final String id;

  /// Foreign key to the project this session belongs to
  final String projectId;

  /// Description or title of the session
  final String description;

  /// Timestamp when the session was created/started
  final DateTime timestamp;

  /// Timestamp when the session was created
  final DateTime createdAt;

  /// Timestamp when the session was last updated
  final DateTime updatedAt;

  /// Whether the session is archived
  final bool isArchived;
  const SessionEntity(
      {required this.id,
      required this.projectId,
      required this.description,
      required this.timestamp,
      required this.createdAt,
      required this.updatedAt,
      required this.isArchived});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['description'] = Variable<String>(description);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  SessionEntityCompanion toCompanion(bool nullToAbsent) {
    return SessionEntityCompanion(
      id: Value(id),
      projectId: Value(projectId),
      description: Value(description),
      timestamp: Value(timestamp),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isArchived: Value(isArchived),
    );
  }

  factory SessionEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionEntity(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      description: serializer.fromJson<String>(json['description']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'description': serializer.toJson<String>(description),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isArchived': serializer.toJson<bool>(isArchived),
    };
  }

  SessionEntity copyWith(
          {String? id,
          String? projectId,
          String? description,
          DateTime? timestamp,
          DateTime? createdAt,
          DateTime? updatedAt,
          bool? isArchived}) =>
      SessionEntity(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        description: description ?? this.description,
        timestamp: timestamp ?? this.timestamp,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isArchived: isArchived ?? this.isArchived,
      );
  SessionEntity copyWithCompanion(SessionEntityCompanion data) {
    return SessionEntity(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      description:
          data.description.present ? data.description.value : this.description,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isArchived:
          data.isArchived.present ? data.isArchived.value : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionEntity(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('description: $description, ')
          ..write('timestamp: $timestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, projectId, description, timestamp, createdAt, updatedAt, isArchived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionEntity &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.description == this.description &&
          other.timestamp == this.timestamp &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isArchived == this.isArchived);
}

class SessionEntityCompanion extends UpdateCompanion<SessionEntity> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> description;
  final Value<DateTime> timestamp;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isArchived;
  final Value<int> rowid;
  const SessionEntityCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.description = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionEntityCompanion.insert({
    required String id,
    required String projectId,
    required String description,
    required DateTime timestamp,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        description = Value(description),
        timestamp = Value(timestamp),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<SessionEntity> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? description,
    Expression<DateTime>? timestamp,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isArchived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (description != null) 'description': description,
      if (timestamp != null) 'timestamp': timestamp,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isArchived != null) 'is_archived': isArchived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionEntityCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? description,
      Value<DateTime>? timestamp,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<bool>? isArchived,
      Value<int>? rowid}) {
    return SessionEntityCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionEntityCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('description: $description, ')
          ..write('timestamp: $timestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userNameMeta =
      const VerificationMeta('userName');
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
      'user_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _editedAtMeta =
      const VerificationMeta('editedAt');
  @override
  late final GeneratedColumn<DateTime> editedAt = GeneratedColumn<DateTime>(
      'edited_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isStreamingMeta =
      const VerificationMeta('isStreaming');
  @override
  late final GeneratedColumn<bool> isStreaming = GeneratedColumn<bool>(
      'is_streaming', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_streaming" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isVisibleToLlmMeta =
      const VerificationMeta('isVisibleToLlm');
  @override
  late final GeneratedColumn<bool> isVisibleToLlm = GeneratedColumn<bool>(
      'is_visible_to_llm', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_visible_to_llm" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  late final GeneratedColumnWithTypeConverter<MessageKind, int> messageKind =
      GeneratedColumn<int>('message_kind', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(0))
          .withConverter<MessageKind>($MessagesTable.$convertermessageKind);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<List<ToolCall>?, String>
      toolCallsJson = GeneratedColumn<String>(
              'tool_calls_json', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<List<ToolCall>?>(
              $MessagesTable.$convertertoolCallsJson);
  @override
  late final GeneratedColumnWithTypeConverter<List<ToolCall>?, String>
      toolResultsJson = GeneratedColumn<String>(
              'tool_results_json', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<List<ToolCall>?>(
              $MessagesTable.$convertertoolResultsJson);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        userId,
        userName,
        content,
        timestamp,
        createdAt,
        editedAt,
        isStreaming,
        isVisibleToLlm,
        messageKind,
        imageUrl,
        toolCallsJson,
        toolResultsJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<MessageEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('user_name')) {
      context.handle(_userNameMeta,
          userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta));
    } else if (isInserting) {
      context.missing(_userNameMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('edited_at')) {
      context.handle(_editedAtMeta,
          editedAt.isAcceptableOrUnknown(data['edited_at']!, _editedAtMeta));
    }
    if (data.containsKey('is_streaming')) {
      context.handle(
          _isStreamingMeta,
          isStreaming.isAcceptableOrUnknown(
              data['is_streaming']!, _isStreamingMeta));
    }
    if (data.containsKey('is_visible_to_llm')) {
      context.handle(
          _isVisibleToLlmMeta,
          isVisibleToLlm.isAcceptableOrUnknown(
              data['is_visible_to_llm']!, _isVisibleToLlmMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      userName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_name'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      editedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}edited_at']),
      isStreaming: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_streaming'])!,
      isVisibleToLlm: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_visible_to_llm'])!,
      messageKind: $MessagesTable.$convertermessageKind.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}message_kind'])!),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      toolCallsJson: $MessagesTable.$convertertoolCallsJson.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}tool_calls_json'])),
      toolResultsJson: $MessagesTable.$convertertoolResultsJson.fromSql(
          attachedDatabase.typeMapping.read(DriftSqlType.string,
              data['${effectivePrefix}tool_results_json'])),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MessageKind, int, int> $convertermessageKind =
      const EnumIndexConverter<MessageKind>(MessageKind.values);
  static JsonTypeConverter2<List<ToolCall>?, String?, Object?>
      $convertertoolCallsJson = const ToolCallListConverter();
  static JsonTypeConverter2<List<ToolCall>?, String?, Object?>
      $convertertoolResultsJson = const ToolCallListConverter();
}

class MessageEntity extends DataClass implements Insertable<MessageEntity> {
  /// Unique identifier for the message
  final String id;

  /// Foreign key to the session this message belongs to
  final String sessionId;

  /// User ID (e.g., 'user' or 'ai')
  final String userId;

  /// User name for display
  final String userName;

  /// Message content/text
  final String content;

  /// Timestamp when the message was sent
  final DateTime timestamp;

  /// Timestamp when the message was created
  final DateTime createdAt;

  /// Timestamp when the message was last edited (null if never edited)
  final DateTime? editedAt;

  /// Whether the message is currently streaming
  final bool isStreaming;

  /// Whether the message should be visible to the LLM (included in conversation history)
  final bool isVisibleToLlm;

  /// Discriminator: what kind of message is this?
  final MessageKind messageKind;

  /// Image URL (only populated when messageKind = imageUrl)
  final String? imageUrl;
  final List<ToolCall>? toolCallsJson;
  final List<ToolCall>? toolResultsJson;
  const MessageEntity(
      {required this.id,
      required this.sessionId,
      required this.userId,
      required this.userName,
      required this.content,
      required this.timestamp,
      required this.createdAt,
      this.editedAt,
      required this.isStreaming,
      required this.isVisibleToLlm,
      required this.messageKind,
      this.imageUrl,
      this.toolCallsJson,
      this.toolResultsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['user_id'] = Variable<String>(userId);
    map['user_name'] = Variable<String>(userName);
    map['content'] = Variable<String>(content);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || editedAt != null) {
      map['edited_at'] = Variable<DateTime>(editedAt);
    }
    map['is_streaming'] = Variable<bool>(isStreaming);
    map['is_visible_to_llm'] = Variable<bool>(isVisibleToLlm);
    {
      map['message_kind'] = Variable<int>(
          $MessagesTable.$convertermessageKind.toSql(messageKind));
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || toolCallsJson != null) {
      map['tool_calls_json'] = Variable<String>(
          $MessagesTable.$convertertoolCallsJson.toSql(toolCallsJson));
    }
    if (!nullToAbsent || toolResultsJson != null) {
      map['tool_results_json'] = Variable<String>(
          $MessagesTable.$convertertoolResultsJson.toSql(toolResultsJson));
    }
    return map;
  }

  MessageEntityCompanion toCompanion(bool nullToAbsent) {
    return MessageEntityCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      userId: Value(userId),
      userName: Value(userName),
      content: Value(content),
      timestamp: Value(timestamp),
      createdAt: Value(createdAt),
      editedAt: editedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(editedAt),
      isStreaming: Value(isStreaming),
      isVisibleToLlm: Value(isVisibleToLlm),
      messageKind: Value(messageKind),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      toolCallsJson: toolCallsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(toolCallsJson),
      toolResultsJson: toolResultsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(toolResultsJson),
    );
  }

  factory MessageEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageEntity(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      userId: serializer.fromJson<String>(json['userId']),
      userName: serializer.fromJson<String>(json['userName']),
      content: serializer.fromJson<String>(json['content']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      editedAt: serializer.fromJson<DateTime?>(json['editedAt']),
      isStreaming: serializer.fromJson<bool>(json['isStreaming']),
      isVisibleToLlm: serializer.fromJson<bool>(json['isVisibleToLlm']),
      messageKind: $MessagesTable.$convertermessageKind
          .fromJson(serializer.fromJson<int>(json['messageKind'])),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      toolCallsJson: $MessagesTable.$convertertoolCallsJson
          .fromJson(serializer.fromJson<Object?>(json['toolCallsJson'])),
      toolResultsJson: $MessagesTable.$convertertoolResultsJson
          .fromJson(serializer.fromJson<Object?>(json['toolResultsJson'])),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'userId': serializer.toJson<String>(userId),
      'userName': serializer.toJson<String>(userName),
      'content': serializer.toJson<String>(content),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'editedAt': serializer.toJson<DateTime?>(editedAt),
      'isStreaming': serializer.toJson<bool>(isStreaming),
      'isVisibleToLlm': serializer.toJson<bool>(isVisibleToLlm),
      'messageKind': serializer.toJson<int>(
          $MessagesTable.$convertermessageKind.toJson(messageKind)),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'toolCallsJson': serializer.toJson<Object?>(
          $MessagesTable.$convertertoolCallsJson.toJson(toolCallsJson)),
      'toolResultsJson': serializer.toJson<Object?>(
          $MessagesTable.$convertertoolResultsJson.toJson(toolResultsJson)),
    };
  }

  MessageEntity copyWith(
          {String? id,
          String? sessionId,
          String? userId,
          String? userName,
          String? content,
          DateTime? timestamp,
          DateTime? createdAt,
          Value<DateTime?> editedAt = const Value.absent(),
          bool? isStreaming,
          bool? isVisibleToLlm,
          MessageKind? messageKind,
          Value<String?> imageUrl = const Value.absent(),
          Value<List<ToolCall>?> toolCallsJson = const Value.absent(),
          Value<List<ToolCall>?> toolResultsJson = const Value.absent()}) =>
      MessageEntity(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        content: content ?? this.content,
        timestamp: timestamp ?? this.timestamp,
        createdAt: createdAt ?? this.createdAt,
        editedAt: editedAt.present ? editedAt.value : this.editedAt,
        isStreaming: isStreaming ?? this.isStreaming,
        isVisibleToLlm: isVisibleToLlm ?? this.isVisibleToLlm,
        messageKind: messageKind ?? this.messageKind,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        toolCallsJson:
            toolCallsJson.present ? toolCallsJson.value : this.toolCallsJson,
        toolResultsJson: toolResultsJson.present
            ? toolResultsJson.value
            : this.toolResultsJson,
      );
  MessageEntity copyWithCompanion(MessageEntityCompanion data) {
    return MessageEntity(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      userId: data.userId.present ? data.userId.value : this.userId,
      userName: data.userName.present ? data.userName.value : this.userName,
      content: data.content.present ? data.content.value : this.content,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      editedAt: data.editedAt.present ? data.editedAt.value : this.editedAt,
      isStreaming:
          data.isStreaming.present ? data.isStreaming.value : this.isStreaming,
      isVisibleToLlm: data.isVisibleToLlm.present
          ? data.isVisibleToLlm.value
          : this.isVisibleToLlm,
      messageKind:
          data.messageKind.present ? data.messageKind.value : this.messageKind,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      toolCallsJson: data.toolCallsJson.present
          ? data.toolCallsJson.value
          : this.toolCallsJson,
      toolResultsJson: data.toolResultsJson.present
          ? data.toolResultsJson.value
          : this.toolResultsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageEntity(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('userId: $userId, ')
          ..write('userName: $userName, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('isStreaming: $isStreaming, ')
          ..write('isVisibleToLlm: $isVisibleToLlm, ')
          ..write('messageKind: $messageKind, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('toolCallsJson: $toolCallsJson, ')
          ..write('toolResultsJson: $toolResultsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      sessionId,
      userId,
      userName,
      content,
      timestamp,
      createdAt,
      editedAt,
      isStreaming,
      isVisibleToLlm,
      messageKind,
      imageUrl,
      toolCallsJson,
      toolResultsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageEntity &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.userId == this.userId &&
          other.userName == this.userName &&
          other.content == this.content &&
          other.timestamp == this.timestamp &&
          other.createdAt == this.createdAt &&
          other.editedAt == this.editedAt &&
          other.isStreaming == this.isStreaming &&
          other.isVisibleToLlm == this.isVisibleToLlm &&
          other.messageKind == this.messageKind &&
          other.imageUrl == this.imageUrl &&
          other.toolCallsJson == this.toolCallsJson &&
          other.toolResultsJson == this.toolResultsJson);
}

class MessageEntityCompanion extends UpdateCompanion<MessageEntity> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> userId;
  final Value<String> userName;
  final Value<String> content;
  final Value<DateTime> timestamp;
  final Value<DateTime> createdAt;
  final Value<DateTime?> editedAt;
  final Value<bool> isStreaming;
  final Value<bool> isVisibleToLlm;
  final Value<MessageKind> messageKind;
  final Value<String?> imageUrl;
  final Value<List<ToolCall>?> toolCallsJson;
  final Value<List<ToolCall>?> toolResultsJson;
  final Value<int> rowid;
  const MessageEntityCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.userId = const Value.absent(),
    this.userName = const Value.absent(),
    this.content = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.isStreaming = const Value.absent(),
    this.isVisibleToLlm = const Value.absent(),
    this.messageKind = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.toolCallsJson = const Value.absent(),
    this.toolResultsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageEntityCompanion.insert({
    required String id,
    required String sessionId,
    required String userId,
    required String userName,
    required String content,
    required DateTime timestamp,
    required DateTime createdAt,
    this.editedAt = const Value.absent(),
    this.isStreaming = const Value.absent(),
    this.isVisibleToLlm = const Value.absent(),
    this.messageKind = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.toolCallsJson = const Value.absent(),
    this.toolResultsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        userId = Value(userId),
        userName = Value(userName),
        content = Value(content),
        timestamp = Value(timestamp),
        createdAt = Value(createdAt);
  static Insertable<MessageEntity> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? userId,
    Expression<String>? userName,
    Expression<String>? content,
    Expression<DateTime>? timestamp,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? editedAt,
    Expression<bool>? isStreaming,
    Expression<bool>? isVisibleToLlm,
    Expression<int>? messageKind,
    Expression<String>? imageUrl,
    Expression<String>? toolCallsJson,
    Expression<String>? toolResultsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (userId != null) 'user_id': userId,
      if (userName != null) 'user_name': userName,
      if (content != null) 'content': content,
      if (timestamp != null) 'timestamp': timestamp,
      if (createdAt != null) 'created_at': createdAt,
      if (editedAt != null) 'edited_at': editedAt,
      if (isStreaming != null) 'is_streaming': isStreaming,
      if (isVisibleToLlm != null) 'is_visible_to_llm': isVisibleToLlm,
      if (messageKind != null) 'message_kind': messageKind,
      if (imageUrl != null) 'image_url': imageUrl,
      if (toolCallsJson != null) 'tool_calls_json': toolCallsJson,
      if (toolResultsJson != null) 'tool_results_json': toolResultsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageEntityCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? userId,
      Value<String>? userName,
      Value<String>? content,
      Value<DateTime>? timestamp,
      Value<DateTime>? createdAt,
      Value<DateTime?>? editedAt,
      Value<bool>? isStreaming,
      Value<bool>? isVisibleToLlm,
      Value<MessageKind>? messageKind,
      Value<String?>? imageUrl,
      Value<List<ToolCall>?>? toolCallsJson,
      Value<List<ToolCall>?>? toolResultsJson,
      Value<int>? rowid}) {
    return MessageEntityCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      isStreaming: isStreaming ?? this.isStreaming,
      isVisibleToLlm: isVisibleToLlm ?? this.isVisibleToLlm,
      messageKind: messageKind ?? this.messageKind,
      imageUrl: imageUrl ?? this.imageUrl,
      toolCallsJson: toolCallsJson ?? this.toolCallsJson,
      toolResultsJson: toolResultsJson ?? this.toolResultsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (userName.present) {
      map['user_name'] = Variable<String>(userName.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (editedAt.present) {
      map['edited_at'] = Variable<DateTime>(editedAt.value);
    }
    if (isStreaming.present) {
      map['is_streaming'] = Variable<bool>(isStreaming.value);
    }
    if (isVisibleToLlm.present) {
      map['is_visible_to_llm'] = Variable<bool>(isVisibleToLlm.value);
    }
    if (messageKind.present) {
      map['message_kind'] = Variable<int>(
          $MessagesTable.$convertermessageKind.toSql(messageKind.value));
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (toolCallsJson.present) {
      map['tool_calls_json'] = Variable<String>(
          $MessagesTable.$convertertoolCallsJson.toSql(toolCallsJson.value));
    }
    if (toolResultsJson.present) {
      map['tool_results_json'] = Variable<String>($MessagesTable
          .$convertertoolResultsJson
          .toSql(toolResultsJson.value));
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageEntityCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('userId: $userId, ')
          ..write('userName: $userName, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('isStreaming: $isStreaming, ')
          ..write('isVisibleToLlm: $isVisibleToLlm, ')
          ..write('messageKind: $messageKind, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('toolCallsJson: $toolCallsJson, ')
          ..write('toolResultsJson: $toolResultsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectSnippetsTable extends ProjectSnippets
    with TableInfo<$ProjectSnippetsTable, ProjectSnippet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectSnippetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isVisibleToLlmMeta =
      const VerificationMeta('isVisibleToLlm');
  @override
  late final GeneratedColumn<bool> isVisibleToLlm = GeneratedColumn<bool>(
      'is_visible_to_llm', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_visible_to_llm" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        name,
        content,
        description,
        tags,
        position,
        isVisibleToLlm,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snippets';
  @override
  VerificationContext validateIntegrity(Insertable<ProjectSnippet> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('is_visible_to_llm')) {
      context.handle(
          _isVisibleToLlmMeta,
          isVisibleToLlm.isAcceptableOrUnknown(
              data['is_visible_to_llm']!, _isVisibleToLlmMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectSnippet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectSnippet(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      isVisibleToLlm: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_visible_to_llm'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ProjectSnippetsTable createAlias(String alias) {
    return $ProjectSnippetsTable(attachedDatabase, alias);
  }
}

class ProjectSnippet extends DataClass implements Insertable<ProjectSnippet> {
  /// Unique identifier for the snippet
  final String id;

  /// Optional foreign key to project (null for global snippets)
  final String? projectId;

  /// Snippet name
  final String name;

  /// Snippet content (code or command)
  final String content;

  /// Optional description
  final String? description;

  /// Tags as comma-separated string
  final String tags;

  /// Position for ordering snippets (lower = higher in list)
  final int position;

  /// Whether the snippet should be visible to the LLM (included in system prompt/context)
  final bool isVisibleToLlm;

  /// Timestamp when the snippet was created
  final DateTime createdAt;

  /// Timestamp when the snippet was last updated
  final DateTime updatedAt;
  const ProjectSnippet(
      {required this.id,
      this.projectId,
      required this.name,
      required this.content,
      this.description,
      required this.tags,
      required this.position,
      required this.isVisibleToLlm,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['name'] = Variable<String>(name);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['tags'] = Variable<String>(tags);
    map['position'] = Variable<int>(position);
    map['is_visible_to_llm'] = Variable<bool>(isVisibleToLlm);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProjectSnippetCompanion toCompanion(bool nullToAbsent) {
    return ProjectSnippetCompanion(
      id: Value(id),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      name: Value(name),
      content: Value(content),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      tags: Value(tags),
      position: Value(position),
      isVisibleToLlm: Value(isVisibleToLlm),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProjectSnippet.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectSnippet(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      content: serializer.fromJson<String>(json['content']),
      description: serializer.fromJson<String?>(json['description']),
      tags: serializer.fromJson<String>(json['tags']),
      position: serializer.fromJson<int>(json['position']),
      isVisibleToLlm: serializer.fromJson<bool>(json['isVisibleToLlm']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String?>(projectId),
      'name': serializer.toJson<String>(name),
      'content': serializer.toJson<String>(content),
      'description': serializer.toJson<String?>(description),
      'tags': serializer.toJson<String>(tags),
      'position': serializer.toJson<int>(position),
      'isVisibleToLlm': serializer.toJson<bool>(isVisibleToLlm),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProjectSnippet copyWith(
          {String? id,
          Value<String?> projectId = const Value.absent(),
          String? name,
          String? content,
          Value<String?> description = const Value.absent(),
          String? tags,
          int? position,
          bool? isVisibleToLlm,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ProjectSnippet(
        id: id ?? this.id,
        projectId: projectId.present ? projectId.value : this.projectId,
        name: name ?? this.name,
        content: content ?? this.content,
        description: description.present ? description.value : this.description,
        tags: tags ?? this.tags,
        position: position ?? this.position,
        isVisibleToLlm: isVisibleToLlm ?? this.isVisibleToLlm,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ProjectSnippet copyWithCompanion(ProjectSnippetCompanion data) {
    return ProjectSnippet(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      content: data.content.present ? data.content.value : this.content,
      description:
          data.description.present ? data.description.value : this.description,
      tags: data.tags.present ? data.tags.value : this.tags,
      position: data.position.present ? data.position.value : this.position,
      isVisibleToLlm: data.isVisibleToLlm.present
          ? data.isVisibleToLlm.value
          : this.isVisibleToLlm,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSnippet(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('content: $content, ')
          ..write('description: $description, ')
          ..write('tags: $tags, ')
          ..write('position: $position, ')
          ..write('isVisibleToLlm: $isVisibleToLlm, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, name, content, description,
      tags, position, isVisibleToLlm, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectSnippet &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.content == this.content &&
          other.description == this.description &&
          other.tags == this.tags &&
          other.position == this.position &&
          other.isVisibleToLlm == this.isVisibleToLlm &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProjectSnippetCompanion extends UpdateCompanion<ProjectSnippet> {
  final Value<String> id;
  final Value<String?> projectId;
  final Value<String> name;
  final Value<String> content;
  final Value<String?> description;
  final Value<String> tags;
  final Value<int> position;
  final Value<bool> isVisibleToLlm;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProjectSnippetCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.content = const Value.absent(),
    this.description = const Value.absent(),
    this.tags = const Value.absent(),
    this.position = const Value.absent(),
    this.isVisibleToLlm = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectSnippetCompanion.insert({
    required String id,
    this.projectId = const Value.absent(),
    required String name,
    required String content,
    this.description = const Value.absent(),
    this.tags = const Value.absent(),
    this.position = const Value.absent(),
    this.isVisibleToLlm = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        content = Value(content),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ProjectSnippet> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<String>? content,
    Expression<String>? description,
    Expression<String>? tags,
    Expression<int>? position,
    Expression<bool>? isVisibleToLlm,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (content != null) 'content': content,
      if (description != null) 'description': description,
      if (tags != null) 'tags': tags,
      if (position != null) 'position': position,
      if (isVisibleToLlm != null) 'is_visible_to_llm': isVisibleToLlm,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectSnippetCompanion copyWith(
      {Value<String>? id,
      Value<String?>? projectId,
      Value<String>? name,
      Value<String>? content,
      Value<String?>? description,
      Value<String>? tags,
      Value<int>? position,
      Value<bool>? isVisibleToLlm,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ProjectSnippetCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      content: content ?? this.content,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      position: position ?? this.position,
      isVisibleToLlm: isVisibleToLlm ?? this.isVisibleToLlm,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (isVisibleToLlm.present) {
      map['is_visible_to_llm'] = Variable<bool>(isVisibleToLlm.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSnippetCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('content: $content, ')
          ..write('description: $description, ')
          ..write('tags: $tags, ')
          ..write('position: $position, ')
          ..write('isVisibleToLlm: $isVisibleToLlm, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectSavedPromptsTable extends ProjectSavedPrompts
    with TableInfo<$ProjectSavedPromptsTable, ProjectSavedPrompt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectSavedPromptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastUsedAtMeta =
      const VerificationMeta('lastUsedAt');
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
      'last_used_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        content,
        description,
        tags,
        createdAt,
        updatedAt,
        lastUsedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_prompts';
  @override
  VerificationContext validateIntegrity(Insertable<ProjectSavedPrompt> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
          _lastUsedAtMeta,
          lastUsedAt.isAcceptableOrUnknown(
              data['last_used_at']!, _lastUsedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectSavedPrompt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectSavedPrompt(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id']),
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      lastUsedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_used_at']),
    );
  }

  @override
  $ProjectSavedPromptsTable createAlias(String alias) {
    return $ProjectSavedPromptsTable(attachedDatabase, alias);
  }
}

class ProjectSavedPrompt extends DataClass
    implements Insertable<ProjectSavedPrompt> {
  /// Unique identifier for the saved prompt
  final String id;

  /// Optional foreign key to project (null for global saved prompts)
  final String? projectId;

  /// Prompt content
  final String content;

  /// Optional description
  final String? description;

  /// Tags as comma-separated string
  final String tags;

  /// Timestamp when the saved prompt was created
  final DateTime createdAt;

  /// Timestamp when the saved prompt was last updated
  final DateTime updatedAt;

  /// Timestamp when the saved prompt was last used
  final DateTime? lastUsedAt;
  const ProjectSavedPrompt(
      {required this.id,
      this.projectId,
      required this.content,
      this.description,
      required this.tags,
      required this.createdAt,
      required this.updatedAt,
      this.lastUsedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['tags'] = Variable<String>(tags);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    return map;
  }

  ProjectSavedPromptCompanion toCompanion(bool nullToAbsent) {
    return ProjectSavedPromptCompanion(
      id: Value(id),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      content: Value(content),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      tags: Value(tags),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
    );
  }

  factory ProjectSavedPrompt.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectSavedPrompt(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      content: serializer.fromJson<String>(json['content']),
      description: serializer.fromJson<String?>(json['description']),
      tags: serializer.fromJson<String>(json['tags']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String?>(projectId),
      'content': serializer.toJson<String>(content),
      'description': serializer.toJson<String?>(description),
      'tags': serializer.toJson<String>(tags),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
    };
  }

  ProjectSavedPrompt copyWith(
          {String? id,
          Value<String?> projectId = const Value.absent(),
          String? content,
          Value<String?> description = const Value.absent(),
          String? tags,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> lastUsedAt = const Value.absent()}) =>
      ProjectSavedPrompt(
        id: id ?? this.id,
        projectId: projectId.present ? projectId.value : this.projectId,
        content: content ?? this.content,
        description: description.present ? description.value : this.description,
        tags: tags ?? this.tags,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
      );
  ProjectSavedPrompt copyWithCompanion(ProjectSavedPromptCompanion data) {
    return ProjectSavedPrompt(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      content: data.content.present ? data.content.value : this.content,
      description:
          data.description.present ? data.description.value : this.description,
      tags: data.tags.present ? data.tags.value : this.tags,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastUsedAt:
          data.lastUsedAt.present ? data.lastUsedAt.value : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSavedPrompt(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('content: $content, ')
          ..write('description: $description, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, content, description, tags,
      createdAt, updatedAt, lastUsedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectSavedPrompt &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.content == this.content &&
          other.description == this.description &&
          other.tags == this.tags &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastUsedAt == this.lastUsedAt);
}

class ProjectSavedPromptCompanion extends UpdateCompanion<ProjectSavedPrompt> {
  final Value<String> id;
  final Value<String?> projectId;
  final Value<String> content;
  final Value<String?> description;
  final Value<String> tags;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastUsedAt;
  final Value<int> rowid;
  const ProjectSavedPromptCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.content = const Value.absent(),
    this.description = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectSavedPromptCompanion.insert({
    required String id,
    this.projectId = const Value.absent(),
    required String content,
    this.description = const Value.absent(),
    this.tags = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        content = Value(content),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ProjectSavedPrompt> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? content,
    Expression<String>? description,
    Expression<String>? tags,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (content != null) 'content': content,
      if (description != null) 'description': description,
      if (tags != null) 'tags': tags,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectSavedPromptCompanion copyWith(
      {Value<String>? id,
      Value<String?>? projectId,
      Value<String>? content,
      Value<String?>? description,
      Value<String>? tags,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? lastUsedAt,
      Value<int>? rowid}) {
    return ProjectSavedPromptCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      content: content ?? this.content,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSavedPromptCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('content: $content, ')
          ..write('description: $description, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionMutexesTable extends SessionMutexes
    with TableInfo<$SessionMutexesTable, SessionMutexEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionMutexesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_mutexes';
  @override
  VerificationContext validateIntegrity(Insertable<SessionMutexEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionMutexEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionMutexEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $SessionMutexesTable createAlias(String alias) {
    return $SessionMutexesTable(attachedDatabase, alias);
  }
}

class SessionMutexEntity extends DataClass
    implements Insertable<SessionMutexEntity> {
  /// Unique identifier for the session (or mutex key)
  final String id;

  /// Timestamp when the lock was acquired or refreshed
  final DateTime timestamp;
  const SessionMutexEntity({required this.id, required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  SessionMutexEntityCompanion toCompanion(bool nullToAbsent) {
    return SessionMutexEntityCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
    );
  }

  factory SessionMutexEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionMutexEntity(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  SessionMutexEntity copyWith({String? id, DateTime? timestamp}) =>
      SessionMutexEntity(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
      );
  SessionMutexEntity copyWithCompanion(SessionMutexEntityCompanion data) {
    return SessionMutexEntity(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionMutexEntity(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMutexEntity &&
          other.id == this.id &&
          other.timestamp == this.timestamp);
}

class SessionMutexEntityCompanion extends UpdateCompanion<SessionMutexEntity> {
  final Value<String> id;
  final Value<DateTime> timestamp;
  final Value<int> rowid;
  const SessionMutexEntityCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionMutexEntityCompanion.insert({
    required String id,
    required DateTime timestamp,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        timestamp = Value(timestamp);
  static Insertable<SessionMutexEntity> custom({
    Expression<String>? id,
    Expression<DateTime>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionMutexEntityCompanion copyWith(
      {Value<String>? id, Value<DateTime>? timestamp, Value<int>? rowid}) {
    return SessionMutexEntityCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionMutexEntityCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ProjectDatabase extends GeneratedDatabase {
  _$ProjectDatabase(QueryExecutor e) : super(e);
  $ProjectDatabaseManager get managers => $ProjectDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $ProjectSnippetsTable projectSnippets =
      $ProjectSnippetsTable(this);
  late final $ProjectSavedPromptsTable projectSavedPrompts =
      $ProjectSavedPromptsTable(this);
  late final $SessionMutexesTable sessionMutexes = $SessionMutexesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        sessions,
        messages,
        projectSnippets,
        projectSavedPrompts,
        sessionMutexes
      ];
}

typedef $$SessionsTableCreateCompanionBuilder = SessionEntityCompanion
    Function({
  required String id,
  required String projectId,
  required String description,
  required DateTime timestamp,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool> isArchived,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionEntityCompanion
    Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> description,
  Value<DateTime> timestamp,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> isArchived,
  Value<int> rowid,
});

class $$SessionsTableFilterComposer
    extends Composer<_$ProjectDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnFilters(column));
}

class $$SessionsTableOrderingComposer
    extends Composer<_$ProjectDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnOrderings(column));
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$ProjectDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => column);
}

class $$SessionsTableTableManager extends RootTableManager<
    _$ProjectDatabase,
    $SessionsTable,
    SessionEntity,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (
      SessionEntity,
      BaseReferences<_$ProjectDatabase, $SessionsTable, SessionEntity>
    ),
    SessionEntity,
    PrefetchHooks Function()> {
  $$SessionsTableTableManager(_$ProjectDatabase db, $SessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionEntityCompanion(
            id: id,
            projectId: projectId,
            description: description,
            timestamp: timestamp,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isArchived: isArchived,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String description,
            required DateTime timestamp,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<bool> isArchived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionEntityCompanion.insert(
            id: id,
            projectId: projectId,
            description: description,
            timestamp: timestamp,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isArchived: isArchived,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SessionsTableProcessedTableManager = ProcessedTableManager<
    _$ProjectDatabase,
    $SessionsTable,
    SessionEntity,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (
      SessionEntity,
      BaseReferences<_$ProjectDatabase, $SessionsTable, SessionEntity>
    ),
    SessionEntity,
    PrefetchHooks Function()>;
typedef $$MessagesTableCreateCompanionBuilder = MessageEntityCompanion
    Function({
  required String id,
  required String sessionId,
  required String userId,
  required String userName,
  required String content,
  required DateTime timestamp,
  required DateTime createdAt,
  Value<DateTime?> editedAt,
  Value<bool> isStreaming,
  Value<bool> isVisibleToLlm,
  Value<MessageKind> messageKind,
  Value<String?> imageUrl,
  Value<List<ToolCall>?> toolCallsJson,
  Value<List<ToolCall>?> toolResultsJson,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessageEntityCompanion
    Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> userId,
  Value<String> userName,
  Value<String> content,
  Value<DateTime> timestamp,
  Value<DateTime> createdAt,
  Value<DateTime?> editedAt,
  Value<bool> isStreaming,
  Value<bool> isVisibleToLlm,
  Value<MessageKind> messageKind,
  Value<String?> imageUrl,
  Value<List<ToolCall>?> toolCallsJson,
  Value<List<ToolCall>?> toolResultsJson,
  Value<int> rowid,
});

class $$MessagesTableFilterComposer
    extends Composer<_$ProjectDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userName => $composableBuilder(
      column: $table.userName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get editedAt => $composableBuilder(
      column: $table.editedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isStreaming => $composableBuilder(
      column: $table.isStreaming, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVisibleToLlm => $composableBuilder(
      column: $table.isVisibleToLlm,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<MessageKind, MessageKind, int>
      get messageKind => $composableBuilder(
          column: $table.messageKind,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<ToolCall>?, List<ToolCall>, String>
      get toolCallsJson => $composableBuilder(
          column: $table.toolCallsJson,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<List<ToolCall>?, List<ToolCall>, String>
      get toolResultsJson => $composableBuilder(
          column: $table.toolResultsJson,
          builder: (column) => ColumnWithTypeConverterFilters(column));
}

class $$MessagesTableOrderingComposer
    extends Composer<_$ProjectDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userName => $composableBuilder(
      column: $table.userName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get editedAt => $composableBuilder(
      column: $table.editedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isStreaming => $composableBuilder(
      column: $table.isStreaming, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVisibleToLlm => $composableBuilder(
      column: $table.isVisibleToLlm,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get messageKind => $composableBuilder(
      column: $table.messageKind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toolCallsJson => $composableBuilder(
      column: $table.toolCallsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toolResultsJson => $composableBuilder(
      column: $table.toolResultsJson,
      builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$ProjectDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get userName =>
      $composableBuilder(column: $table.userName, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get editedAt =>
      $composableBuilder(column: $table.editedAt, builder: (column) => column);

  GeneratedColumn<bool> get isStreaming => $composableBuilder(
      column: $table.isStreaming, builder: (column) => column);

  GeneratedColumn<bool> get isVisibleToLlm => $composableBuilder(
      column: $table.isVisibleToLlm, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageKind, int> get messageKind =>
      $composableBuilder(
          column: $table.messageKind, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<ToolCall>?, String> get toolCallsJson =>
      $composableBuilder(
          column: $table.toolCallsJson, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<ToolCall>?, String>
      get toolResultsJson => $composableBuilder(
          column: $table.toolResultsJson, builder: (column) => column);
}

class $$MessagesTableTableManager extends RootTableManager<
    _$ProjectDatabase,
    $MessagesTable,
    MessageEntity,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (
      MessageEntity,
      BaseReferences<_$ProjectDatabase, $MessagesTable, MessageEntity>
    ),
    MessageEntity,
    PrefetchHooks Function()> {
  $$MessagesTableTableManager(_$ProjectDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> userName = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> editedAt = const Value.absent(),
            Value<bool> isStreaming = const Value.absent(),
            Value<bool> isVisibleToLlm = const Value.absent(),
            Value<MessageKind> messageKind = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<List<ToolCall>?> toolCallsJson = const Value.absent(),
            Value<List<ToolCall>?> toolResultsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessageEntityCompanion(
            id: id,
            sessionId: sessionId,
            userId: userId,
            userName: userName,
            content: content,
            timestamp: timestamp,
            createdAt: createdAt,
            editedAt: editedAt,
            isStreaming: isStreaming,
            isVisibleToLlm: isVisibleToLlm,
            messageKind: messageKind,
            imageUrl: imageUrl,
            toolCallsJson: toolCallsJson,
            toolResultsJson: toolResultsJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required String userId,
            required String userName,
            required String content,
            required DateTime timestamp,
            required DateTime createdAt,
            Value<DateTime?> editedAt = const Value.absent(),
            Value<bool> isStreaming = const Value.absent(),
            Value<bool> isVisibleToLlm = const Value.absent(),
            Value<MessageKind> messageKind = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<List<ToolCall>?> toolCallsJson = const Value.absent(),
            Value<List<ToolCall>?> toolResultsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessageEntityCompanion.insert(
            id: id,
            sessionId: sessionId,
            userId: userId,
            userName: userName,
            content: content,
            timestamp: timestamp,
            createdAt: createdAt,
            editedAt: editedAt,
            isStreaming: isStreaming,
            isVisibleToLlm: isVisibleToLlm,
            messageKind: messageKind,
            imageUrl: imageUrl,
            toolCallsJson: toolCallsJson,
            toolResultsJson: toolResultsJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$ProjectDatabase,
    $MessagesTable,
    MessageEntity,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (
      MessageEntity,
      BaseReferences<_$ProjectDatabase, $MessagesTable, MessageEntity>
    ),
    MessageEntity,
    PrefetchHooks Function()>;
typedef $$ProjectSnippetsTableCreateCompanionBuilder = ProjectSnippetCompanion
    Function({
  required String id,
  Value<String?> projectId,
  required String name,
  required String content,
  Value<String?> description,
  Value<String> tags,
  Value<int> position,
  Value<bool> isVisibleToLlm,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ProjectSnippetsTableUpdateCompanionBuilder = ProjectSnippetCompanion
    Function({
  Value<String> id,
  Value<String?> projectId,
  Value<String> name,
  Value<String> content,
  Value<String?> description,
  Value<String> tags,
  Value<int> position,
  Value<bool> isVisibleToLlm,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ProjectSnippetsTableFilterComposer
    extends Composer<_$ProjectDatabase, $ProjectSnippetsTable> {
  $$ProjectSnippetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVisibleToLlm => $composableBuilder(
      column: $table.isVisibleToLlm,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ProjectSnippetsTableOrderingComposer
    extends Composer<_$ProjectDatabase, $ProjectSnippetsTable> {
  $$ProjectSnippetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVisibleToLlm => $composableBuilder(
      column: $table.isVisibleToLlm,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ProjectSnippetsTableAnnotationComposer
    extends Composer<_$ProjectDatabase, $ProjectSnippetsTable> {
  $$ProjectSnippetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get isVisibleToLlm => $composableBuilder(
      column: $table.isVisibleToLlm, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProjectSnippetsTableTableManager extends RootTableManager<
    _$ProjectDatabase,
    $ProjectSnippetsTable,
    ProjectSnippet,
    $$ProjectSnippetsTableFilterComposer,
    $$ProjectSnippetsTableOrderingComposer,
    $$ProjectSnippetsTableAnnotationComposer,
    $$ProjectSnippetsTableCreateCompanionBuilder,
    $$ProjectSnippetsTableUpdateCompanionBuilder,
    (
      ProjectSnippet,
      BaseReferences<_$ProjectDatabase, $ProjectSnippetsTable, ProjectSnippet>
    ),
    ProjectSnippet,
    PrefetchHooks Function()> {
  $$ProjectSnippetsTableTableManager(
      _$ProjectDatabase db, $ProjectSnippetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectSnippetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectSnippetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectSnippetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> projectId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<bool> isVisibleToLlm = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectSnippetCompanion(
            id: id,
            projectId: projectId,
            name: name,
            content: content,
            description: description,
            tags: tags,
            position: position,
            isVisibleToLlm: isVisibleToLlm,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> projectId = const Value.absent(),
            required String name,
            required String content,
            Value<String?> description = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<bool> isVisibleToLlm = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectSnippetCompanion.insert(
            id: id,
            projectId: projectId,
            name: name,
            content: content,
            description: description,
            tags: tags,
            position: position,
            isVisibleToLlm: isVisibleToLlm,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProjectSnippetsTableProcessedTableManager = ProcessedTableManager<
    _$ProjectDatabase,
    $ProjectSnippetsTable,
    ProjectSnippet,
    $$ProjectSnippetsTableFilterComposer,
    $$ProjectSnippetsTableOrderingComposer,
    $$ProjectSnippetsTableAnnotationComposer,
    $$ProjectSnippetsTableCreateCompanionBuilder,
    $$ProjectSnippetsTableUpdateCompanionBuilder,
    (
      ProjectSnippet,
      BaseReferences<_$ProjectDatabase, $ProjectSnippetsTable, ProjectSnippet>
    ),
    ProjectSnippet,
    PrefetchHooks Function()>;
typedef $$ProjectSavedPromptsTableCreateCompanionBuilder
    = ProjectSavedPromptCompanion Function({
  required String id,
  Value<String?> projectId,
  required String content,
  Value<String?> description,
  Value<String> tags,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> lastUsedAt,
  Value<int> rowid,
});
typedef $$ProjectSavedPromptsTableUpdateCompanionBuilder
    = ProjectSavedPromptCompanion Function({
  Value<String> id,
  Value<String?> projectId,
  Value<String> content,
  Value<String?> description,
  Value<String> tags,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> lastUsedAt,
  Value<int> rowid,
});

class $$ProjectSavedPromptsTableFilterComposer
    extends Composer<_$ProjectDatabase, $ProjectSavedPromptsTable> {
  $$ProjectSavedPromptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => ColumnFilters(column));
}

class $$ProjectSavedPromptsTableOrderingComposer
    extends Composer<_$ProjectDatabase, $ProjectSavedPromptsTable> {
  $$ProjectSavedPromptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => ColumnOrderings(column));
}

class $$ProjectSavedPromptsTableAnnotationComposer
    extends Composer<_$ProjectDatabase, $ProjectSavedPromptsTable> {
  $$ProjectSavedPromptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => column);
}

class $$ProjectSavedPromptsTableTableManager extends RootTableManager<
    _$ProjectDatabase,
    $ProjectSavedPromptsTable,
    ProjectSavedPrompt,
    $$ProjectSavedPromptsTableFilterComposer,
    $$ProjectSavedPromptsTableOrderingComposer,
    $$ProjectSavedPromptsTableAnnotationComposer,
    $$ProjectSavedPromptsTableCreateCompanionBuilder,
    $$ProjectSavedPromptsTableUpdateCompanionBuilder,
    (
      ProjectSavedPrompt,
      BaseReferences<_$ProjectDatabase, $ProjectSavedPromptsTable,
          ProjectSavedPrompt>
    ),
    ProjectSavedPrompt,
    PrefetchHooks Function()> {
  $$ProjectSavedPromptsTableTableManager(
      _$ProjectDatabase db, $ProjectSavedPromptsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectSavedPromptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectSavedPromptsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectSavedPromptsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> projectId = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> lastUsedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectSavedPromptCompanion(
            id: id,
            projectId: projectId,
            content: content,
            description: description,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastUsedAt: lastUsedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> projectId = const Value.absent(),
            required String content,
            Value<String?> description = const Value.absent(),
            Value<String> tags = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> lastUsedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectSavedPromptCompanion.insert(
            id: id,
            projectId: projectId,
            content: content,
            description: description,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastUsedAt: lastUsedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProjectSavedPromptsTableProcessedTableManager = ProcessedTableManager<
    _$ProjectDatabase,
    $ProjectSavedPromptsTable,
    ProjectSavedPrompt,
    $$ProjectSavedPromptsTableFilterComposer,
    $$ProjectSavedPromptsTableOrderingComposer,
    $$ProjectSavedPromptsTableAnnotationComposer,
    $$ProjectSavedPromptsTableCreateCompanionBuilder,
    $$ProjectSavedPromptsTableUpdateCompanionBuilder,
    (
      ProjectSavedPrompt,
      BaseReferences<_$ProjectDatabase, $ProjectSavedPromptsTable,
          ProjectSavedPrompt>
    ),
    ProjectSavedPrompt,
    PrefetchHooks Function()>;
typedef $$SessionMutexesTableCreateCompanionBuilder
    = SessionMutexEntityCompanion Function({
  required String id,
  required DateTime timestamp,
  Value<int> rowid,
});
typedef $$SessionMutexesTableUpdateCompanionBuilder
    = SessionMutexEntityCompanion Function({
  Value<String> id,
  Value<DateTime> timestamp,
  Value<int> rowid,
});

class $$SessionMutexesTableFilterComposer
    extends Composer<_$ProjectDatabase, $SessionMutexesTable> {
  $$SessionMutexesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$SessionMutexesTableOrderingComposer
    extends Composer<_$ProjectDatabase, $SessionMutexesTable> {
  $$SessionMutexesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$SessionMutexesTableAnnotationComposer
    extends Composer<_$ProjectDatabase, $SessionMutexesTable> {
  $$SessionMutexesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$SessionMutexesTableTableManager extends RootTableManager<
    _$ProjectDatabase,
    $SessionMutexesTable,
    SessionMutexEntity,
    $$SessionMutexesTableFilterComposer,
    $$SessionMutexesTableOrderingComposer,
    $$SessionMutexesTableAnnotationComposer,
    $$SessionMutexesTableCreateCompanionBuilder,
    $$SessionMutexesTableUpdateCompanionBuilder,
    (
      SessionMutexEntity,
      BaseReferences<_$ProjectDatabase, $SessionMutexesTable,
          SessionMutexEntity>
    ),
    SessionMutexEntity,
    PrefetchHooks Function()> {
  $$SessionMutexesTableTableManager(
      _$ProjectDatabase db, $SessionMutexesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionMutexesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionMutexesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionMutexesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionMutexEntityCompanion(
            id: id,
            timestamp: timestamp,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime timestamp,
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionMutexEntityCompanion.insert(
            id: id,
            timestamp: timestamp,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SessionMutexesTableProcessedTableManager = ProcessedTableManager<
    _$ProjectDatabase,
    $SessionMutexesTable,
    SessionMutexEntity,
    $$SessionMutexesTableFilterComposer,
    $$SessionMutexesTableOrderingComposer,
    $$SessionMutexesTableAnnotationComposer,
    $$SessionMutexesTableCreateCompanionBuilder,
    $$SessionMutexesTableUpdateCompanionBuilder,
    (
      SessionMutexEntity,
      BaseReferences<_$ProjectDatabase, $SessionMutexesTable,
          SessionMutexEntity>
    ),
    SessionMutexEntity,
    PrefetchHooks Function()>;

class $ProjectDatabaseManager {
  final _$ProjectDatabase _db;
  $ProjectDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$ProjectSnippetsTableTableManager get projectSnippets =>
      $$ProjectSnippetsTableTableManager(_db, _db.projectSnippets);
  $$ProjectSavedPromptsTableTableManager get projectSavedPrompts =>
      $$ProjectSavedPromptsTableTableManager(_db, _db.projectSavedPrompts);
  $$SessionMutexesTableTableManager get sessionMutexes =>
      $$SessionMutexesTableTableManager(_db, _db.sessionMutexes);
}
