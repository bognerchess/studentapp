// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DraftsTable extends Drafts with TableInfo<$DraftsTable, Draft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerSubMeta = const VerificationMeta(
    'ownerSub',
  );
  @override
  late final GeneratedColumn<String> ownerSub = GeneratedColumn<String>(
    'owner_sub',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pgnMeta = const VerificationMeta('pgn');
  @override
  late final GeneratedColumn<String> pgn = GeneratedColumn<String>(
    'pgn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metaJsonMeta = const VerificationMeta(
    'metaJson',
  );
  @override
  late final GeneratedColumn<String> metaJson = GeneratedColumn<String>(
    'meta_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DraftState, String> state =
      GeneratedColumn<String>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DraftState>($DraftsTable.$converterstate);
  static const VerificationMeta _clientGameIdMeta = const VerificationMeta(
    'clientGameId',
  );
  @override
  late final GeneratedColumn<String> clientGameId = GeneratedColumn<String>(
    'client_game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _wantsAnalysisMeta = const VerificationMeta(
    'wantsAnalysis',
  );
  @override
  late final GeneratedColumn<bool> wantsAnalysis = GeneratedColumn<bool>(
    'wants_analysis',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("wants_analysis" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _serverGameIdMeta = const VerificationMeta(
    'serverGameId',
  );
  @override
  late final GeneratedColumn<String> serverGameId = GeneratedColumn<String>(
    'server_game_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerSub,
    pgn,
    metaJson,
    state,
    clientGameId,
    wantsAnalysis,
    serverGameId,
    attempts,
    lastError,
    nextAttemptAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Draft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_sub')) {
      context.handle(
        _ownerSubMeta,
        ownerSub.isAcceptableOrUnknown(data['owner_sub']!, _ownerSubMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerSubMeta);
    }
    if (data.containsKey('pgn')) {
      context.handle(
        _pgnMeta,
        pgn.isAcceptableOrUnknown(data['pgn']!, _pgnMeta),
      );
    } else if (isInserting) {
      context.missing(_pgnMeta);
    }
    if (data.containsKey('meta_json')) {
      context.handle(
        _metaJsonMeta,
        metaJson.isAcceptableOrUnknown(data['meta_json']!, _metaJsonMeta),
      );
    }
    if (data.containsKey('client_game_id')) {
      context.handle(
        _clientGameIdMeta,
        clientGameId.isAcceptableOrUnknown(
          data['client_game_id']!,
          _clientGameIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientGameIdMeta);
    }
    if (data.containsKey('wants_analysis')) {
      context.handle(
        _wantsAnalysisMeta,
        wantsAnalysis.isAcceptableOrUnknown(
          data['wants_analysis']!,
          _wantsAnalysisMeta,
        ),
      );
    }
    if (data.containsKey('server_game_id')) {
      context.handle(
        _serverGameIdMeta,
        serverGameId.isAcceptableOrUnknown(
          data['server_game_id']!,
          _serverGameIdMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Draft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Draft(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerSub: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_sub'],
      )!,
      pgn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pgn'],
      )!,
      metaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_json'],
      )!,
      state: $DraftsTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}state'],
        )!,
      ),
      clientGameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_game_id'],
      )!,
      wantsAnalysis: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}wants_analysis'],
      )!,
      serverGameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_game_id'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DraftState, String, String> $converterstate =
      const EnumNameConverter<DraftState>(DraftState.values);
}

class Draft extends DataClass implements Insertable<Draft> {
  /// UUID v4, created on the device.
  final String id;

  /// `sub` claim of the account the draft belongs to.
  final String ownerSub;
  final String pgn;

  /// Opaque JSON owned by the entry feature (players, date, result, ...).
  final String metaJson;
  final DraftState state;

  /// Idempotency key for `createGame`. Never changes once the draft exists.
  final String clientGameId;
  final bool wantsAnalysis;

  /// Set as soon as `createGame` succeeded, even if the analysis request is
  /// still open, so a retry does not create the game again.
  final String? serverGameId;
  final int attempts;
  final String? lastError;

  /// Back-off: the submit queue leaves the draft alone until this moment.
  final DateTime? nextAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Draft({
    required this.id,
    required this.ownerSub,
    required this.pgn,
    required this.metaJson,
    required this.state,
    required this.clientGameId,
    required this.wantsAnalysis,
    this.serverGameId,
    required this.attempts,
    this.lastError,
    this.nextAttemptAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_sub'] = Variable<String>(ownerSub);
    map['pgn'] = Variable<String>(pgn);
    map['meta_json'] = Variable<String>(metaJson);
    {
      map['state'] = Variable<String>(
        $DraftsTable.$converterstate.toSql(state),
      );
    }
    map['client_game_id'] = Variable<String>(clientGameId);
    map['wants_analysis'] = Variable<bool>(wantsAnalysis);
    if (!nullToAbsent || serverGameId != null) {
      map['server_game_id'] = Variable<String>(serverGameId);
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      id: Value(id),
      ownerSub: Value(ownerSub),
      pgn: Value(pgn),
      metaJson: Value(metaJson),
      state: Value(state),
      clientGameId: Value(clientGameId),
      wantsAnalysis: Value(wantsAnalysis),
      serverGameId: serverGameId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverGameId),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Draft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Draft(
      id: serializer.fromJson<String>(json['id']),
      ownerSub: serializer.fromJson<String>(json['ownerSub']),
      pgn: serializer.fromJson<String>(json['pgn']),
      metaJson: serializer.fromJson<String>(json['metaJson']),
      state: $DraftsTable.$converterstate.fromJson(
        serializer.fromJson<String>(json['state']),
      ),
      clientGameId: serializer.fromJson<String>(json['clientGameId']),
      wantsAnalysis: serializer.fromJson<bool>(json['wantsAnalysis']),
      serverGameId: serializer.fromJson<String?>(json['serverGameId']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerSub': serializer.toJson<String>(ownerSub),
      'pgn': serializer.toJson<String>(pgn),
      'metaJson': serializer.toJson<String>(metaJson),
      'state': serializer.toJson<String>(
        $DraftsTable.$converterstate.toJson(state),
      ),
      'clientGameId': serializer.toJson<String>(clientGameId),
      'wantsAnalysis': serializer.toJson<bool>(wantsAnalysis),
      'serverGameId': serializer.toJson<String?>(serverGameId),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Draft copyWith({
    String? id,
    String? ownerSub,
    String? pgn,
    String? metaJson,
    DraftState? state,
    String? clientGameId,
    bool? wantsAnalysis,
    Value<String?> serverGameId = const Value.absent(),
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Draft(
    id: id ?? this.id,
    ownerSub: ownerSub ?? this.ownerSub,
    pgn: pgn ?? this.pgn,
    metaJson: metaJson ?? this.metaJson,
    state: state ?? this.state,
    clientGameId: clientGameId ?? this.clientGameId,
    wantsAnalysis: wantsAnalysis ?? this.wantsAnalysis,
    serverGameId: serverGameId.present ? serverGameId.value : this.serverGameId,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Draft copyWithCompanion(DraftsCompanion data) {
    return Draft(
      id: data.id.present ? data.id.value : this.id,
      ownerSub: data.ownerSub.present ? data.ownerSub.value : this.ownerSub,
      pgn: data.pgn.present ? data.pgn.value : this.pgn,
      metaJson: data.metaJson.present ? data.metaJson.value : this.metaJson,
      state: data.state.present ? data.state.value : this.state,
      clientGameId: data.clientGameId.present
          ? data.clientGameId.value
          : this.clientGameId,
      wantsAnalysis: data.wantsAnalysis.present
          ? data.wantsAnalysis.value
          : this.wantsAnalysis,
      serverGameId: data.serverGameId.present
          ? data.serverGameId.value
          : this.serverGameId,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Draft(')
          ..write('id: $id, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('pgn: $pgn, ')
          ..write('metaJson: $metaJson, ')
          ..write('state: $state, ')
          ..write('clientGameId: $clientGameId, ')
          ..write('wantsAnalysis: $wantsAnalysis, ')
          ..write('serverGameId: $serverGameId, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerSub,
    pgn,
    metaJson,
    state,
    clientGameId,
    wantsAnalysis,
    serverGameId,
    attempts,
    lastError,
    nextAttemptAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Draft &&
          other.id == this.id &&
          other.ownerSub == this.ownerSub &&
          other.pgn == this.pgn &&
          other.metaJson == this.metaJson &&
          other.state == this.state &&
          other.clientGameId == this.clientGameId &&
          other.wantsAnalysis == this.wantsAnalysis &&
          other.serverGameId == this.serverGameId &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DraftsCompanion extends UpdateCompanion<Draft> {
  final Value<String> id;
  final Value<String> ownerSub;
  final Value<String> pgn;
  final Value<String> metaJson;
  final Value<DraftState> state;
  final Value<String> clientGameId;
  final Value<bool> wantsAnalysis;
  final Value<String?> serverGameId;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime?> nextAttemptAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DraftsCompanion({
    this.id = const Value.absent(),
    this.ownerSub = const Value.absent(),
    this.pgn = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.state = const Value.absent(),
    this.clientGameId = const Value.absent(),
    this.wantsAnalysis = const Value.absent(),
    this.serverGameId = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String id,
    required String ownerSub,
    required String pgn,
    this.metaJson = const Value.absent(),
    required DraftState state,
    required String clientGameId,
    this.wantsAnalysis = const Value.absent(),
    this.serverGameId = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerSub = Value(ownerSub),
       pgn = Value(pgn),
       state = Value(state),
       clientGameId = Value(clientGameId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Draft> custom({
    Expression<String>? id,
    Expression<String>? ownerSub,
    Expression<String>? pgn,
    Expression<String>? metaJson,
    Expression<String>? state,
    Expression<String>? clientGameId,
    Expression<bool>? wantsAnalysis,
    Expression<String>? serverGameId,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? nextAttemptAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerSub != null) 'owner_sub': ownerSub,
      if (pgn != null) 'pgn': pgn,
      if (metaJson != null) 'meta_json': metaJson,
      if (state != null) 'state': state,
      if (clientGameId != null) 'client_game_id': clientGameId,
      if (wantsAnalysis != null) 'wants_analysis': wantsAnalysis,
      if (serverGameId != null) 'server_game_id': serverGameId,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerSub,
    Value<String>? pgn,
    Value<String>? metaJson,
    Value<DraftState>? state,
    Value<String>? clientGameId,
    Value<bool>? wantsAnalysis,
    Value<String?>? serverGameId,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime?>? nextAttemptAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DraftsCompanion(
      id: id ?? this.id,
      ownerSub: ownerSub ?? this.ownerSub,
      pgn: pgn ?? this.pgn,
      metaJson: metaJson ?? this.metaJson,
      state: state ?? this.state,
      clientGameId: clientGameId ?? this.clientGameId,
      wantsAnalysis: wantsAnalysis ?? this.wantsAnalysis,
      serverGameId: serverGameId ?? this.serverGameId,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
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
    if (ownerSub.present) {
      map['owner_sub'] = Variable<String>(ownerSub.value);
    }
    if (pgn.present) {
      map['pgn'] = Variable<String>(pgn.value);
    }
    if (metaJson.present) {
      map['meta_json'] = Variable<String>(metaJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(
        $DraftsTable.$converterstate.toSql(state.value),
      );
    }
    if (clientGameId.present) {
      map['client_game_id'] = Variable<String>(clientGameId.value);
    }
    if (wantsAnalysis.present) {
      map['wants_analysis'] = Variable<bool>(wantsAnalysis.value);
    }
    if (serverGameId.present) {
      map['server_game_id'] = Variable<String>(serverGameId.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
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
    return (StringBuffer('DraftsCompanion(')
          ..write('id: $id, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('pgn: $pgn, ')
          ..write('metaJson: $metaJson, ')
          ..write('state: $state, ')
          ..write('clientGameId: $clientGameId, ')
          ..write('wantsAnalysis: $wantsAnalysis, ')
          ..write('serverGameId: $serverGameId, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedGamesTable extends CachedGames
    with TableInfo<$CachedGamesTable, CachedGame> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedGamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerSubMeta = const VerificationMeta(
    'ownerSub',
  );
  @override
  late final GeneratedColumn<String> ownerSub = GeneratedColumn<String>(
    'owner_sub',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> playedDate =
      GeneratedColumn<String>(
        'played_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($CachedGamesTable.$converterplayedDaten);
  static const VerificationMeta _opponentNameMeta = const VerificationMeta(
    'opponentName',
  );
  @override
  late final GeneratedColumn<String> opponentName = GeneratedColumn<String>(
    'opponent_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _opponentSearchMeta = const VerificationMeta(
    'opponentSearch',
  );
  @override
  late final GeneratedColumn<String> opponentSearch = GeneratedColumn<String>(
    'opponent_search',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gameId,
    ownerSub,
    summaryJson,
    playedDate,
    opponentName,
    opponentSearch,
    updatedAt,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_games';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedGame> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('owner_sub')) {
      context.handle(
        _ownerSubMeta,
        ownerSub.isAcceptableOrUnknown(data['owner_sub']!, _ownerSubMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerSubMeta);
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryJsonMeta);
    }
    if (data.containsKey('opponent_name')) {
      context.handle(
        _opponentNameMeta,
        opponentName.isAcceptableOrUnknown(
          data['opponent_name']!,
          _opponentNameMeta,
        ),
      );
    }
    if (data.containsKey('opponent_search')) {
      context.handle(
        _opponentSearchMeta,
        opponentSearch.isAcceptableOrUnknown(
          data['opponent_search']!,
          _opponentSearchMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gameId};
  @override
  CachedGame map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedGame(
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      ownerSub: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_sub'],
      )!,
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      )!,
      playedDate: $CachedGamesTable.$converterplayedDaten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}played_date'],
        ),
      ),
      opponentName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opponent_name'],
      ),
      opponentSearch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opponent_search'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CachedGamesTable createAlias(String alias) {
    return $CachedGamesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterplayedDate =
      const DateOnlyConverter();
  static TypeConverter<DateTime?, String?> $converterplayedDaten =
      NullAwareTypeConverter.wrap($converterplayedDate);
}

class CachedGame extends DataClass implements Insertable<CachedGame> {
  /// Server id of the game.
  final String gameId;
  final String ownerSub;

  /// The list item as JSON, owned by the library feature.
  final String summaryJson;

  /// Calendar date without a time zone, stored as `YYYY-MM-DD`.
  final DateTime? playedDate;
  final String? opponentName;

  /// `opponentName` in lower case, written by the DAO. SQLite folds case for
  /// ASCII only, which is not enough for "Müller".
  final String? opponentSearch;

  /// Server-side modification time.
  final DateTime updatedAt;
  final DateTime fetchedAt;
  const CachedGame({
    required this.gameId,
    required this.ownerSub,
    required this.summaryJson,
    this.playedDate,
    this.opponentName,
    this.opponentSearch,
    required this.updatedAt,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['game_id'] = Variable<String>(gameId);
    map['owner_sub'] = Variable<String>(ownerSub);
    map['summary_json'] = Variable<String>(summaryJson);
    if (!nullToAbsent || playedDate != null) {
      map['played_date'] = Variable<String>(
        $CachedGamesTable.$converterplayedDaten.toSql(playedDate),
      );
    }
    if (!nullToAbsent || opponentName != null) {
      map['opponent_name'] = Variable<String>(opponentName);
    }
    if (!nullToAbsent || opponentSearch != null) {
      map['opponent_search'] = Variable<String>(opponentSearch);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedGamesCompanion toCompanion(bool nullToAbsent) {
    return CachedGamesCompanion(
      gameId: Value(gameId),
      ownerSub: Value(ownerSub),
      summaryJson: Value(summaryJson),
      playedDate: playedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(playedDate),
      opponentName: opponentName == null && nullToAbsent
          ? const Value.absent()
          : Value(opponentName),
      opponentSearch: opponentSearch == null && nullToAbsent
          ? const Value.absent()
          : Value(opponentSearch),
      updatedAt: Value(updatedAt),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedGame.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedGame(
      gameId: serializer.fromJson<String>(json['gameId']),
      ownerSub: serializer.fromJson<String>(json['ownerSub']),
      summaryJson: serializer.fromJson<String>(json['summaryJson']),
      playedDate: serializer.fromJson<DateTime?>(json['playedDate']),
      opponentName: serializer.fromJson<String?>(json['opponentName']),
      opponentSearch: serializer.fromJson<String?>(json['opponentSearch']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gameId': serializer.toJson<String>(gameId),
      'ownerSub': serializer.toJson<String>(ownerSub),
      'summaryJson': serializer.toJson<String>(summaryJson),
      'playedDate': serializer.toJson<DateTime?>(playedDate),
      'opponentName': serializer.toJson<String?>(opponentName),
      'opponentSearch': serializer.toJson<String?>(opponentSearch),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedGame copyWith({
    String? gameId,
    String? ownerSub,
    String? summaryJson,
    Value<DateTime?> playedDate = const Value.absent(),
    Value<String?> opponentName = const Value.absent(),
    Value<String?> opponentSearch = const Value.absent(),
    DateTime? updatedAt,
    DateTime? fetchedAt,
  }) => CachedGame(
    gameId: gameId ?? this.gameId,
    ownerSub: ownerSub ?? this.ownerSub,
    summaryJson: summaryJson ?? this.summaryJson,
    playedDate: playedDate.present ? playedDate.value : this.playedDate,
    opponentName: opponentName.present ? opponentName.value : this.opponentName,
    opponentSearch: opponentSearch.present
        ? opponentSearch.value
        : this.opponentSearch,
    updatedAt: updatedAt ?? this.updatedAt,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CachedGame copyWithCompanion(CachedGamesCompanion data) {
    return CachedGame(
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      ownerSub: data.ownerSub.present ? data.ownerSub.value : this.ownerSub,
      summaryJson: data.summaryJson.present
          ? data.summaryJson.value
          : this.summaryJson,
      playedDate: data.playedDate.present
          ? data.playedDate.value
          : this.playedDate,
      opponentName: data.opponentName.present
          ? data.opponentName.value
          : this.opponentName,
      opponentSearch: data.opponentSearch.present
          ? data.opponentSearch.value
          : this.opponentSearch,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedGame(')
          ..write('gameId: $gameId, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('playedDate: $playedDate, ')
          ..write('opponentName: $opponentName, ')
          ..write('opponentSearch: $opponentSearch, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    gameId,
    ownerSub,
    summaryJson,
    playedDate,
    opponentName,
    opponentSearch,
    updatedAt,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedGame &&
          other.gameId == this.gameId &&
          other.ownerSub == this.ownerSub &&
          other.summaryJson == this.summaryJson &&
          other.playedDate == this.playedDate &&
          other.opponentName == this.opponentName &&
          other.opponentSearch == this.opponentSearch &&
          other.updatedAt == this.updatedAt &&
          other.fetchedAt == this.fetchedAt);
}

class CachedGamesCompanion extends UpdateCompanion<CachedGame> {
  final Value<String> gameId;
  final Value<String> ownerSub;
  final Value<String> summaryJson;
  final Value<DateTime?> playedDate;
  final Value<String?> opponentName;
  final Value<String?> opponentSearch;
  final Value<DateTime> updatedAt;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedGamesCompanion({
    this.gameId = const Value.absent(),
    this.ownerSub = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.playedDate = const Value.absent(),
    this.opponentName = const Value.absent(),
    this.opponentSearch = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedGamesCompanion.insert({
    required String gameId,
    required String ownerSub,
    required String summaryJson,
    this.playedDate = const Value.absent(),
    this.opponentName = const Value.absent(),
    this.opponentSearch = const Value.absent(),
    required DateTime updatedAt,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : gameId = Value(gameId),
       ownerSub = Value(ownerSub),
       summaryJson = Value(summaryJson),
       updatedAt = Value(updatedAt),
       fetchedAt = Value(fetchedAt);
  static Insertable<CachedGame> custom({
    Expression<String>? gameId,
    Expression<String>? ownerSub,
    Expression<String>? summaryJson,
    Expression<String>? playedDate,
    Expression<String>? opponentName,
    Expression<String>? opponentSearch,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gameId != null) 'game_id': gameId,
      if (ownerSub != null) 'owner_sub': ownerSub,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (playedDate != null) 'played_date': playedDate,
      if (opponentName != null) 'opponent_name': opponentName,
      if (opponentSearch != null) 'opponent_search': opponentSearch,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedGamesCompanion copyWith({
    Value<String>? gameId,
    Value<String>? ownerSub,
    Value<String>? summaryJson,
    Value<DateTime?>? playedDate,
    Value<String?>? opponentName,
    Value<String?>? opponentSearch,
    Value<DateTime>? updatedAt,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return CachedGamesCompanion(
      gameId: gameId ?? this.gameId,
      ownerSub: ownerSub ?? this.ownerSub,
      summaryJson: summaryJson ?? this.summaryJson,
      playedDate: playedDate ?? this.playedDate,
      opponentName: opponentName ?? this.opponentName,
      opponentSearch: opponentSearch ?? this.opponentSearch,
      updatedAt: updatedAt ?? this.updatedAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (ownerSub.present) {
      map['owner_sub'] = Variable<String>(ownerSub.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (playedDate.present) {
      map['played_date'] = Variable<String>(
        $CachedGamesTable.$converterplayedDaten.toSql(playedDate.value),
      );
    }
    if (opponentName.present) {
      map['opponent_name'] = Variable<String>(opponentName.value);
    }
    if (opponentSearch.present) {
      map['opponent_search'] = Variable<String>(opponentSearch.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedGamesCompanion(')
          ..write('gameId: $gameId, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('playedDate: $playedDate, ')
          ..write('opponentName: $opponentName, ')
          ..write('opponentSearch: $opponentSearch, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedAnalysesTable extends CachedAnalyses
    with TableInfo<$CachedAnalysesTable, CachedAnalysis> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedAnalysesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerSubMeta = const VerificationMeta(
    'ownerSub',
  );
  @override
  late final GeneratedColumn<String> ownerSub = GeneratedColumn<String>(
    'owner_sub',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaMinorMeta = const VerificationMeta(
    'schemaMinor',
  );
  @override
  late final GeneratedColumn<int> schemaMinor = GeneratedColumn<int>(
    'schema_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gameId,
    ownerSub,
    schemaVersion,
    schemaMinor,
    payload,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_analyses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedAnalysis> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('owner_sub')) {
      context.handle(
        _ownerSubMeta,
        ownerSub.isAcceptableOrUnknown(data['owner_sub']!, _ownerSubMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerSubMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('schema_minor')) {
      context.handle(
        _schemaMinorMeta,
        schemaMinor.isAcceptableOrUnknown(
          data['schema_minor']!,
          _schemaMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaMinorMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gameId};
  @override
  CachedAnalysis map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedAnalysis(
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      ownerSub: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_sub'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      schemaMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_minor'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CachedAnalysesTable createAlias(String alias) {
    return $CachedAnalysesTable(attachedDatabase, alias);
  }
}

class CachedAnalysis extends DataClass implements Insertable<CachedAnalysis> {
  final String gameId;
  final String ownerSub;
  final int schemaVersion;
  final int schemaMinor;

  /// The raw JSON document. Parsing and version checks belong to the reader.
  final String payload;
  final DateTime fetchedAt;
  const CachedAnalysis({
    required this.gameId,
    required this.ownerSub,
    required this.schemaVersion,
    required this.schemaMinor,
    required this.payload,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['game_id'] = Variable<String>(gameId);
    map['owner_sub'] = Variable<String>(ownerSub);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['schema_minor'] = Variable<int>(schemaMinor);
    map['payload'] = Variable<String>(payload);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedAnalysesCompanion toCompanion(bool nullToAbsent) {
    return CachedAnalysesCompanion(
      gameId: Value(gameId),
      ownerSub: Value(ownerSub),
      schemaVersion: Value(schemaVersion),
      schemaMinor: Value(schemaMinor),
      payload: Value(payload),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedAnalysis.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedAnalysis(
      gameId: serializer.fromJson<String>(json['gameId']),
      ownerSub: serializer.fromJson<String>(json['ownerSub']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      schemaMinor: serializer.fromJson<int>(json['schemaMinor']),
      payload: serializer.fromJson<String>(json['payload']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gameId': serializer.toJson<String>(gameId),
      'ownerSub': serializer.toJson<String>(ownerSub),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'schemaMinor': serializer.toJson<int>(schemaMinor),
      'payload': serializer.toJson<String>(payload),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedAnalysis copyWith({
    String? gameId,
    String? ownerSub,
    int? schemaVersion,
    int? schemaMinor,
    String? payload,
    DateTime? fetchedAt,
  }) => CachedAnalysis(
    gameId: gameId ?? this.gameId,
    ownerSub: ownerSub ?? this.ownerSub,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    schemaMinor: schemaMinor ?? this.schemaMinor,
    payload: payload ?? this.payload,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CachedAnalysis copyWithCompanion(CachedAnalysesCompanion data) {
    return CachedAnalysis(
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      ownerSub: data.ownerSub.present ? data.ownerSub.value : this.ownerSub,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      schemaMinor: data.schemaMinor.present
          ? data.schemaMinor.value
          : this.schemaMinor,
      payload: data.payload.present ? data.payload.value : this.payload,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedAnalysis(')
          ..write('gameId: $gameId, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('schemaMinor: $schemaMinor, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    gameId,
    ownerSub,
    schemaVersion,
    schemaMinor,
    payload,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedAnalysis &&
          other.gameId == this.gameId &&
          other.ownerSub == this.ownerSub &&
          other.schemaVersion == this.schemaVersion &&
          other.schemaMinor == this.schemaMinor &&
          other.payload == this.payload &&
          other.fetchedAt == this.fetchedAt);
}

class CachedAnalysesCompanion extends UpdateCompanion<CachedAnalysis> {
  final Value<String> gameId;
  final Value<String> ownerSub;
  final Value<int> schemaVersion;
  final Value<int> schemaMinor;
  final Value<String> payload;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedAnalysesCompanion({
    this.gameId = const Value.absent(),
    this.ownerSub = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.schemaMinor = const Value.absent(),
    this.payload = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedAnalysesCompanion.insert({
    required String gameId,
    required String ownerSub,
    required int schemaVersion,
    required int schemaMinor,
    required String payload,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : gameId = Value(gameId),
       ownerSub = Value(ownerSub),
       schemaVersion = Value(schemaVersion),
       schemaMinor = Value(schemaMinor),
       payload = Value(payload),
       fetchedAt = Value(fetchedAt);
  static Insertable<CachedAnalysis> custom({
    Expression<String>? gameId,
    Expression<String>? ownerSub,
    Expression<int>? schemaVersion,
    Expression<int>? schemaMinor,
    Expression<String>? payload,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gameId != null) 'game_id': gameId,
      if (ownerSub != null) 'owner_sub': ownerSub,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (schemaMinor != null) 'schema_minor': schemaMinor,
      if (payload != null) 'payload': payload,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedAnalysesCompanion copyWith({
    Value<String>? gameId,
    Value<String>? ownerSub,
    Value<int>? schemaVersion,
    Value<int>? schemaMinor,
    Value<String>? payload,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return CachedAnalysesCompanion(
      gameId: gameId ?? this.gameId,
      ownerSub: ownerSub ?? this.ownerSub,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      schemaMinor: schemaMinor ?? this.schemaMinor,
      payload: payload ?? this.payload,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (ownerSub.present) {
      map['owner_sub'] = Variable<String>(ownerSub.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (schemaMinor.present) {
      map['schema_minor'] = Variable<int>(schemaMinor.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedAnalysesCompanion(')
          ..write('gameId: $gameId, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('schemaMinor: $schemaMinor, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingJobsTable extends PendingJobs
    with TableInfo<$PendingJobsTable, PendingJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerSubMeta = const VerificationMeta(
    'ownerSub',
  );
  @override
  late final GeneratedColumn<String> ownerSub = GeneratedColumn<String>(
    'owner_sub',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<JobState, String> state =
      GeneratedColumn<String>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<JobState>($PendingJobsTable.$converterstate);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPolledAtMeta = const VerificationMeta(
    'lastPolledAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPolledAt = GeneratedColumn<DateTime>(
    'last_polled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    jobId,
    gameId,
    ownerSub,
    state,
    createdAt,
    lastPolledAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('job_id')) {
      context.handle(
        _jobIdMeta,
        jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('owner_sub')) {
      context.handle(
        _ownerSubMeta,
        ownerSub.isAcceptableOrUnknown(data['owner_sub']!, _ownerSubMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerSubMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_polled_at')) {
      context.handle(
        _lastPolledAtMeta,
        lastPolledAt.isAcceptableOrUnknown(
          data['last_polled_at']!,
          _lastPolledAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jobId};
  @override
  PendingJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingJob(
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      ownerSub: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_sub'],
      )!,
      state: $PendingJobsTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}state'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastPolledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_polled_at'],
      ),
    );
  }

  @override
  $PendingJobsTable createAlias(String alias) {
    return $PendingJobsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<JobState, String, String> $converterstate =
      const EnumNameConverter<JobState>(JobState.values);
}

class PendingJob extends DataClass implements Insertable<PendingJob> {
  final String jobId;
  final String gameId;
  final String ownerSub;
  final JobState state;
  final DateTime createdAt;
  final DateTime? lastPolledAt;
  const PendingJob({
    required this.jobId,
    required this.gameId,
    required this.ownerSub,
    required this.state,
    required this.createdAt,
    this.lastPolledAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['job_id'] = Variable<String>(jobId);
    map['game_id'] = Variable<String>(gameId);
    map['owner_sub'] = Variable<String>(ownerSub);
    {
      map['state'] = Variable<String>(
        $PendingJobsTable.$converterstate.toSql(state),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastPolledAt != null) {
      map['last_polled_at'] = Variable<DateTime>(lastPolledAt);
    }
    return map;
  }

  PendingJobsCompanion toCompanion(bool nullToAbsent) {
    return PendingJobsCompanion(
      jobId: Value(jobId),
      gameId: Value(gameId),
      ownerSub: Value(ownerSub),
      state: Value(state),
      createdAt: Value(createdAt),
      lastPolledAt: lastPolledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPolledAt),
    );
  }

  factory PendingJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingJob(
      jobId: serializer.fromJson<String>(json['jobId']),
      gameId: serializer.fromJson<String>(json['gameId']),
      ownerSub: serializer.fromJson<String>(json['ownerSub']),
      state: $PendingJobsTable.$converterstate.fromJson(
        serializer.fromJson<String>(json['state']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastPolledAt: serializer.fromJson<DateTime?>(json['lastPolledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'jobId': serializer.toJson<String>(jobId),
      'gameId': serializer.toJson<String>(gameId),
      'ownerSub': serializer.toJson<String>(ownerSub),
      'state': serializer.toJson<String>(
        $PendingJobsTable.$converterstate.toJson(state),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastPolledAt': serializer.toJson<DateTime?>(lastPolledAt),
    };
  }

  PendingJob copyWith({
    String? jobId,
    String? gameId,
    String? ownerSub,
    JobState? state,
    DateTime? createdAt,
    Value<DateTime?> lastPolledAt = const Value.absent(),
  }) => PendingJob(
    jobId: jobId ?? this.jobId,
    gameId: gameId ?? this.gameId,
    ownerSub: ownerSub ?? this.ownerSub,
    state: state ?? this.state,
    createdAt: createdAt ?? this.createdAt,
    lastPolledAt: lastPolledAt.present ? lastPolledAt.value : this.lastPolledAt,
  );
  PendingJob copyWithCompanion(PendingJobsCompanion data) {
    return PendingJob(
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      ownerSub: data.ownerSub.present ? data.ownerSub.value : this.ownerSub,
      state: data.state.present ? data.state.value : this.state,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastPolledAt: data.lastPolledAt.present
          ? data.lastPolledAt.value
          : this.lastPolledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingJob(')
          ..write('jobId: $jobId, ')
          ..write('gameId: $gameId, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastPolledAt: $lastPolledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(jobId, gameId, ownerSub, state, createdAt, lastPolledAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingJob &&
          other.jobId == this.jobId &&
          other.gameId == this.gameId &&
          other.ownerSub == this.ownerSub &&
          other.state == this.state &&
          other.createdAt == this.createdAt &&
          other.lastPolledAt == this.lastPolledAt);
}

class PendingJobsCompanion extends UpdateCompanion<PendingJob> {
  final Value<String> jobId;
  final Value<String> gameId;
  final Value<String> ownerSub;
  final Value<JobState> state;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastPolledAt;
  final Value<int> rowid;
  const PendingJobsCompanion({
    this.jobId = const Value.absent(),
    this.gameId = const Value.absent(),
    this.ownerSub = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastPolledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingJobsCompanion.insert({
    required String jobId,
    required String gameId,
    required String ownerSub,
    required JobState state,
    required DateTime createdAt,
    this.lastPolledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : jobId = Value(jobId),
       gameId = Value(gameId),
       ownerSub = Value(ownerSub),
       state = Value(state),
       createdAt = Value(createdAt);
  static Insertable<PendingJob> custom({
    Expression<String>? jobId,
    Expression<String>? gameId,
    Expression<String>? ownerSub,
    Expression<String>? state,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastPolledAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jobId != null) 'job_id': jobId,
      if (gameId != null) 'game_id': gameId,
      if (ownerSub != null) 'owner_sub': ownerSub,
      if (state != null) 'state': state,
      if (createdAt != null) 'created_at': createdAt,
      if (lastPolledAt != null) 'last_polled_at': lastPolledAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingJobsCompanion copyWith({
    Value<String>? jobId,
    Value<String>? gameId,
    Value<String>? ownerSub,
    Value<JobState>? state,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastPolledAt,
    Value<int>? rowid,
  }) {
    return PendingJobsCompanion(
      jobId: jobId ?? this.jobId,
      gameId: gameId ?? this.gameId,
      ownerSub: ownerSub ?? this.ownerSub,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      lastPolledAt: lastPolledAt ?? this.lastPolledAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (ownerSub.present) {
      map['owner_sub'] = Variable<String>(ownerSub.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(
        $PendingJobsTable.$converterstate.toSql(state.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastPolledAt.present) {
      map['last_polled_at'] = Variable<DateTime>(lastPolledAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingJobsCompanion(')
          ..write('jobId: $jobId, ')
          ..write('gameId: $gameId, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastPolledAt: $lastPolledAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventOutboxTable extends EventOutbox
    with TableInfo<$EventOutboxTable, OutboxEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ownerSubMeta = const VerificationMeta(
    'ownerSub',
  );
  @override
  late final GeneratedColumn<String> ownerSub = GeneratedColumn<String>(
    'owner_sub',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _propsJsonMeta = const VerificationMeta(
    'propsJson',
  );
  @override
  late final GeneratedColumn<String> propsJson = GeneratedColumn<String>(
    'props_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerSub,
    deviceId,
    sessionId,
    name,
    occurredAt,
    propsJson,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('owner_sub')) {
      context.handle(
        _ownerSubMeta,
        ownerSub.isAcceptableOrUnknown(data['owner_sub']!, _ownerSubMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('props_json')) {
      context.handle(
        _propsJsonMeta,
        propsJson.isAcceptableOrUnknown(data['props_json']!, _propsJsonMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ownerSub: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_sub'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      propsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}props_json'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $EventOutboxTable createAlias(String alias) {
    return $EventOutboxTable(attachedDatabase, alias);
  }
}

class OutboxEvent extends DataClass implements Insertable<OutboxEvent> {
  final int id;
  final String? ownerSub;
  final String deviceId;
  final String sessionId;
  final String name;
  final DateTime occurredAt;
  final String propsJson;
  final int attempts;
  const OutboxEvent({
    required this.id,
    this.ownerSub,
    required this.deviceId,
    required this.sessionId,
    required this.name,
    required this.occurredAt,
    required this.propsJson,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || ownerSub != null) {
      map['owner_sub'] = Variable<String>(ownerSub);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['session_id'] = Variable<String>(sessionId);
    map['name'] = Variable<String>(name);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['props_json'] = Variable<String>(propsJson);
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  EventOutboxCompanion toCompanion(bool nullToAbsent) {
    return EventOutboxCompanion(
      id: Value(id),
      ownerSub: ownerSub == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerSub),
      deviceId: Value(deviceId),
      sessionId: Value(sessionId),
      name: Value(name),
      occurredAt: Value(occurredAt),
      propsJson: Value(propsJson),
      attempts: Value(attempts),
    );
  }

  factory OutboxEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEvent(
      id: serializer.fromJson<int>(json['id']),
      ownerSub: serializer.fromJson<String?>(json['ownerSub']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      name: serializer.fromJson<String>(json['name']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      propsJson: serializer.fromJson<String>(json['propsJson']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ownerSub': serializer.toJson<String?>(ownerSub),
      'deviceId': serializer.toJson<String>(deviceId),
      'sessionId': serializer.toJson<String>(sessionId),
      'name': serializer.toJson<String>(name),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'propsJson': serializer.toJson<String>(propsJson),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  OutboxEvent copyWith({
    int? id,
    Value<String?> ownerSub = const Value.absent(),
    String? deviceId,
    String? sessionId,
    String? name,
    DateTime? occurredAt,
    String? propsJson,
    int? attempts,
  }) => OutboxEvent(
    id: id ?? this.id,
    ownerSub: ownerSub.present ? ownerSub.value : this.ownerSub,
    deviceId: deviceId ?? this.deviceId,
    sessionId: sessionId ?? this.sessionId,
    name: name ?? this.name,
    occurredAt: occurredAt ?? this.occurredAt,
    propsJson: propsJson ?? this.propsJson,
    attempts: attempts ?? this.attempts,
  );
  OutboxEvent copyWithCompanion(EventOutboxCompanion data) {
    return OutboxEvent(
      id: data.id.present ? data.id.value : this.id,
      ownerSub: data.ownerSub.present ? data.ownerSub.value : this.ownerSub,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      name: data.name.present ? data.name.value : this.name,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      propsJson: data.propsJson.present ? data.propsJson.value : this.propsJson,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEvent(')
          ..write('id: $id, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('deviceId: $deviceId, ')
          ..write('sessionId: $sessionId, ')
          ..write('name: $name, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('propsJson: $propsJson, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerSub,
    deviceId,
    sessionId,
    name,
    occurredAt,
    propsJson,
    attempts,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEvent &&
          other.id == this.id &&
          other.ownerSub == this.ownerSub &&
          other.deviceId == this.deviceId &&
          other.sessionId == this.sessionId &&
          other.name == this.name &&
          other.occurredAt == this.occurredAt &&
          other.propsJson == this.propsJson &&
          other.attempts == this.attempts);
}

class EventOutboxCompanion extends UpdateCompanion<OutboxEvent> {
  final Value<int> id;
  final Value<String?> ownerSub;
  final Value<String> deviceId;
  final Value<String> sessionId;
  final Value<String> name;
  final Value<DateTime> occurredAt;
  final Value<String> propsJson;
  final Value<int> attempts;
  const EventOutboxCompanion({
    this.id = const Value.absent(),
    this.ownerSub = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.name = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.propsJson = const Value.absent(),
    this.attempts = const Value.absent(),
  });
  EventOutboxCompanion.insert({
    this.id = const Value.absent(),
    this.ownerSub = const Value.absent(),
    required String deviceId,
    required String sessionId,
    required String name,
    required DateTime occurredAt,
    this.propsJson = const Value.absent(),
    this.attempts = const Value.absent(),
  }) : deviceId = Value(deviceId),
       sessionId = Value(sessionId),
       name = Value(name),
       occurredAt = Value(occurredAt);
  static Insertable<OutboxEvent> custom({
    Expression<int>? id,
    Expression<String>? ownerSub,
    Expression<String>? deviceId,
    Expression<String>? sessionId,
    Expression<String>? name,
    Expression<DateTime>? occurredAt,
    Expression<String>? propsJson,
    Expression<int>? attempts,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerSub != null) 'owner_sub': ownerSub,
      if (deviceId != null) 'device_id': deviceId,
      if (sessionId != null) 'session_id': sessionId,
      if (name != null) 'name': name,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (propsJson != null) 'props_json': propsJson,
      if (attempts != null) 'attempts': attempts,
    });
  }

  EventOutboxCompanion copyWith({
    Value<int>? id,
    Value<String?>? ownerSub,
    Value<String>? deviceId,
    Value<String>? sessionId,
    Value<String>? name,
    Value<DateTime>? occurredAt,
    Value<String>? propsJson,
    Value<int>? attempts,
  }) {
    return EventOutboxCompanion(
      id: id ?? this.id,
      ownerSub: ownerSub ?? this.ownerSub,
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
      name: name ?? this.name,
      occurredAt: occurredAt ?? this.occurredAt,
      propsJson: propsJson ?? this.propsJson,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ownerSub.present) {
      map['owner_sub'] = Variable<String>(ownerSub.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (propsJson.present) {
      map['props_json'] = Variable<String>(propsJson.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventOutboxCompanion(')
          ..write('id: $id, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('deviceId: $deviceId, ')
          ..write('sessionId: $sessionId, ')
          ..write('name: $name, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('propsJson: $propsJson, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }
}

class $FeedbackOutboxTable extends FeedbackOutbox
    with TableInfo<$FeedbackOutboxTable, OutboxFeedback> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedbackOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ownerSubMeta = const VerificationMeta(
    'ownerSub',
  );
  @override
  late final GeneratedColumn<String> ownerSub = GeneratedColumn<String>(
    'owner_sub',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commentIdMeta = const VerificationMeta(
    'commentId',
  );
  @override
  late final GeneratedColumn<String> commentId = GeneratedColumn<String>(
    'comment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FeedbackRating, String> rating =
      GeneratedColumn<String>(
        'rating',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FeedbackRating>($FeedbackOutboxTable.$converterrating);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerSub,
    commentId,
    rating,
    createdAt,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feedback_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxFeedback> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('owner_sub')) {
      context.handle(
        _ownerSubMeta,
        ownerSub.isAcceptableOrUnknown(data['owner_sub']!, _ownerSubMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerSubMeta);
    }
    if (data.containsKey('comment_id')) {
      context.handle(
        _commentIdMeta,
        commentId.isAcceptableOrUnknown(data['comment_id']!, _commentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commentIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {ownerSub, commentId},
  ];
  @override
  OutboxFeedback map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxFeedback(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ownerSub: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_sub'],
      )!,
      commentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment_id'],
      )!,
      rating: $FeedbackOutboxTable.$converterrating.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}rating'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $FeedbackOutboxTable createAlias(String alias) {
    return $FeedbackOutboxTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FeedbackRating, String, String> $converterrating =
      const EnumNameConverter<FeedbackRating>(FeedbackRating.values);
}

class OutboxFeedback extends DataClass implements Insertable<OutboxFeedback> {
  final int id;
  final String ownerSub;
  final String commentId;
  final FeedbackRating rating;
  final DateTime createdAt;
  final int attempts;
  const OutboxFeedback({
    required this.id,
    required this.ownerSub,
    required this.commentId,
    required this.rating,
    required this.createdAt,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['owner_sub'] = Variable<String>(ownerSub);
    map['comment_id'] = Variable<String>(commentId);
    {
      map['rating'] = Variable<String>(
        $FeedbackOutboxTable.$converterrating.toSql(rating),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  FeedbackOutboxCompanion toCompanion(bool nullToAbsent) {
    return FeedbackOutboxCompanion(
      id: Value(id),
      ownerSub: Value(ownerSub),
      commentId: Value(commentId),
      rating: Value(rating),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
    );
  }

  factory OutboxFeedback.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxFeedback(
      id: serializer.fromJson<int>(json['id']),
      ownerSub: serializer.fromJson<String>(json['ownerSub']),
      commentId: serializer.fromJson<String>(json['commentId']),
      rating: $FeedbackOutboxTable.$converterrating.fromJson(
        serializer.fromJson<String>(json['rating']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ownerSub': serializer.toJson<String>(ownerSub),
      'commentId': serializer.toJson<String>(commentId),
      'rating': serializer.toJson<String>(
        $FeedbackOutboxTable.$converterrating.toJson(rating),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  OutboxFeedback copyWith({
    int? id,
    String? ownerSub,
    String? commentId,
    FeedbackRating? rating,
    DateTime? createdAt,
    int? attempts,
  }) => OutboxFeedback(
    id: id ?? this.id,
    ownerSub: ownerSub ?? this.ownerSub,
    commentId: commentId ?? this.commentId,
    rating: rating ?? this.rating,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
  );
  OutboxFeedback copyWithCompanion(FeedbackOutboxCompanion data) {
    return OutboxFeedback(
      id: data.id.present ? data.id.value : this.id,
      ownerSub: data.ownerSub.present ? data.ownerSub.value : this.ownerSub,
      commentId: data.commentId.present ? data.commentId.value : this.commentId,
      rating: data.rating.present ? data.rating.value : this.rating,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxFeedback(')
          ..write('id: $id, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('commentId: $commentId, ')
          ..write('rating: $rating, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, ownerSub, commentId, rating, createdAt, attempts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxFeedback &&
          other.id == this.id &&
          other.ownerSub == this.ownerSub &&
          other.commentId == this.commentId &&
          other.rating == this.rating &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts);
}

class FeedbackOutboxCompanion extends UpdateCompanion<OutboxFeedback> {
  final Value<int> id;
  final Value<String> ownerSub;
  final Value<String> commentId;
  final Value<FeedbackRating> rating;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  const FeedbackOutboxCompanion({
    this.id = const Value.absent(),
    this.ownerSub = const Value.absent(),
    this.commentId = const Value.absent(),
    this.rating = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
  });
  FeedbackOutboxCompanion.insert({
    this.id = const Value.absent(),
    required String ownerSub,
    required String commentId,
    required FeedbackRating rating,
    required DateTime createdAt,
    this.attempts = const Value.absent(),
  }) : ownerSub = Value(ownerSub),
       commentId = Value(commentId),
       rating = Value(rating),
       createdAt = Value(createdAt);
  static Insertable<OutboxFeedback> custom({
    Expression<int>? id,
    Expression<String>? ownerSub,
    Expression<String>? commentId,
    Expression<String>? rating,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerSub != null) 'owner_sub': ownerSub,
      if (commentId != null) 'comment_id': commentId,
      if (rating != null) 'rating': rating,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
    });
  }

  FeedbackOutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? ownerSub,
    Value<String>? commentId,
    Value<FeedbackRating>? rating,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
  }) {
    return FeedbackOutboxCompanion(
      id: id ?? this.id,
      ownerSub: ownerSub ?? this.ownerSub,
      commentId: commentId ?? this.commentId,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ownerSub.present) {
      map['owner_sub'] = Variable<String>(ownerSub.value);
    }
    if (commentId.present) {
      map['comment_id'] = Variable<String>(commentId.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(
        $FeedbackOutboxTable.$converterrating.toSql(rating.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedbackOutboxCompanion(')
          ..write('id: $id, ')
          ..write('ownerSub: $ownerSub, ')
          ..write('commentId: $commentId, ')
          ..write('rating: $rating, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }
}

class $KvTable extends Kv with TableInfo<$KvTable, KvEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<KvEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KvEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KvTable createAlias(String alias) {
    return $KvTable(attachedDatabase, alias);
  }
}

class KvEntry extends DataClass implements Insertable<KvEntry> {
  final String key;
  final String value;
  const KvEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KvCompanion toCompanion(bool nullToAbsent) {
    return KvCompanion(key: Value(key), value: Value(value));
  }

  factory KvEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KvEntry copyWith({String? key, String? value}) =>
      KvEntry(key: key ?? this.key, value: value ?? this.value);
  KvEntry copyWithCompanion(KvCompanion data) {
    return KvEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvEntry && other.key == this.key && other.value == this.value);
}

class KvCompanion extends UpdateCompanion<KvEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KvCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KvEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KvCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  late final $CachedGamesTable cachedGames = $CachedGamesTable(this);
  late final $CachedAnalysesTable cachedAnalyses = $CachedAnalysesTable(this);
  late final $PendingJobsTable pendingJobs = $PendingJobsTable(this);
  late final $EventOutboxTable eventOutbox = $EventOutboxTable(this);
  late final $FeedbackOutboxTable feedbackOutbox = $FeedbackOutboxTable(this);
  late final $KvTable kv = $KvTable(this);
  late final Index draftsOwnerStateUpdated = Index(
    'drafts_owner_state_updated',
    'CREATE INDEX drafts_owner_state_updated ON drafts (owner_sub, state, updated_at)',
  );
  late final Index cachedGamesOwnerPlayed = Index(
    'cached_games_owner_played',
    'CREATE INDEX cached_games_owner_played ON cached_games (owner_sub, played_date)',
  );
  late final Index pendingJobsOwnerState = Index(
    'pending_jobs_owner_state',
    'CREATE INDEX pending_jobs_owner_state ON pending_jobs (owner_sub, state)',
  );
  late final DraftsDao draftsDao = DraftsDao(this as AppDatabase);
  late final GamesCacheDao gamesCacheDao = GamesCacheDao(this as AppDatabase);
  late final AnalysisCacheDao analysisCacheDao = AnalysisCacheDao(
    this as AppDatabase,
  );
  late final PendingJobsDao pendingJobsDao = PendingJobsDao(
    this as AppDatabase,
  );
  late final EventOutboxDao eventOutboxDao = EventOutboxDao(
    this as AppDatabase,
  );
  late final FeedbackOutboxDao feedbackOutboxDao = FeedbackOutboxDao(
    this as AppDatabase,
  );
  late final KvDao kvDao = KvDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    drafts,
    cachedGames,
    cachedAnalyses,
    pendingJobs,
    eventOutbox,
    feedbackOutbox,
    kv,
    draftsOwnerStateUpdated,
    cachedGamesOwnerPlayed,
    pendingJobsOwnerState,
  ];
}

typedef $$DraftsTableCreateCompanionBuilder = DraftsCompanion Function({
  required String id,
  required String ownerSub,
  required String pgn,
  Value<String> metaJson,
  required DraftState state,
  required String clientGameId,
  Value<bool> wantsAnalysis,
  Value<String?> serverGameId,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime?> nextAttemptAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$DraftsTableUpdateCompanionBuilder = DraftsCompanion Function({
  Value<String> id,
  Value<String> ownerSub,
  Value<String> pgn,
  Value<String> metaJson,
  Value<DraftState> state,
  Value<String> clientGameId,
  Value<bool> wantsAnalysis,
  Value<String?> serverGameId,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime?> nextAttemptAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$DraftsTableFilterComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pgn => $composableBuilder(
    column: $table.pgn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DraftState, DraftState, String> get state =>
      $composableBuilder(
        column: $table.state,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get clientGameId => $composableBuilder(
    column: $table.clientGameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wantsAnalysis => $composableBuilder(
    column: $table.wantsAnalysis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverGameId => $composableBuilder(
    column: $table.serverGameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pgn => $composableBuilder(
    column: $table.pgn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientGameId => $composableBuilder(
    column: $table.clientGameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wantsAnalysis => $composableBuilder(
    column: $table.wantsAnalysis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverGameId => $composableBuilder(
    column: $table.serverGameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerSub =>
      $composableBuilder(column: $table.ownerSub, builder: (column) => column);

  GeneratedColumn<String> get pgn =>
      $composableBuilder(column: $table.pgn, builder: (column) => column);

  GeneratedColumn<String> get metaJson =>
      $composableBuilder(column: $table.metaJson, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DraftState, String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get clientGameId => $composableBuilder(
    column: $table.clientGameId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get wantsAnalysis => $composableBuilder(
    column: $table.wantsAnalysis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverGameId => $composableBuilder(
    column: $table.serverGameId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftsTable,
          Draft,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (Draft, BaseReferences<_$AppDatabase, $DraftsTable, Draft>),
          Draft,
          PrefetchHooks Function()
        > {
  $$DraftsTableTableManager(_$AppDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerSub = const Value.absent(),
                Value<String> pgn = const Value.absent(),
                Value<String> metaJson = const Value.absent(),
                Value<DraftState> state = const Value.absent(),
                Value<String> clientGameId = const Value.absent(),
                Value<bool> wantsAnalysis = const Value.absent(),
                Value<String?> serverGameId = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion(
                id: id,
                ownerSub: ownerSub,
                pgn: pgn,
                metaJson: metaJson,
                state: state,
                clientGameId: clientGameId,
                wantsAnalysis: wantsAnalysis,
                serverGameId: serverGameId,
                attempts: attempts,
                lastError: lastError,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerSub,
                required String pgn,
                Value<String> metaJson = const Value.absent(),
                required DraftState state,
                required String clientGameId,
                Value<bool> wantsAnalysis = const Value.absent(),
                Value<String?> serverGameId = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion.insert(
                id: id,
                ownerSub: ownerSub,
                pgn: pgn,
                metaJson: metaJson,
                state: state,
                clientGameId: clientGameId,
                wantsAnalysis: wantsAnalysis,
                serverGameId: serverGameId,
                attempts: attempts,
                lastError: lastError,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DraftsTable, Draft>(table),
                  BaseReferences<_$AppDatabase, $DraftsTable, Draft>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftsTable,
      Draft,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (Draft, BaseReferences<_$AppDatabase, $DraftsTable, Draft>),
      Draft,
      PrefetchHooks Function()
    >;
typedef $$CachedGamesTableCreateCompanionBuilder =
    CachedGamesCompanion Function({
      required String gameId,
      required String ownerSub,
      required String summaryJson,
      Value<DateTime?> playedDate,
      Value<String?> opponentName,
      Value<String?> opponentSearch,
      required DateTime updatedAt,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$CachedGamesTableUpdateCompanionBuilder =
    CachedGamesCompanion Function({
      Value<String> gameId,
      Value<String> ownerSub,
      Value<String> summaryJson,
      Value<DateTime?> playedDate,
      Value<String?> opponentName,
      Value<String?> opponentSearch,
      Value<DateTime> updatedAt,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$CachedGamesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedGamesTable> {
  $$CachedGamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get playedDate =>
      $composableBuilder(
        column: $table.playedDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get opponentName => $composableBuilder(
    column: $table.opponentName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opponentSearch => $composableBuilder(
    column: $table.opponentSearch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedGamesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedGamesTable> {
  $$CachedGamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playedDate => $composableBuilder(
    column: $table.playedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opponentName => $composableBuilder(
    column: $table.opponentName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opponentSearch => $composableBuilder(
    column: $table.opponentSearch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedGamesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedGamesTable> {
  $$CachedGamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get ownerSub =>
      $composableBuilder(column: $table.ownerSub, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, String> get playedDate =>
      $composableBuilder(
        column: $table.playedDate,
        builder: (column) => column,
      );

  GeneratedColumn<String> get opponentName => $composableBuilder(
    column: $table.opponentName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get opponentSearch => $composableBuilder(
    column: $table.opponentSearch,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedGamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedGamesTable,
          CachedGame,
          $$CachedGamesTableFilterComposer,
          $$CachedGamesTableOrderingComposer,
          $$CachedGamesTableAnnotationComposer,
          $$CachedGamesTableCreateCompanionBuilder,
          $$CachedGamesTableUpdateCompanionBuilder,
          (
            CachedGame,
            BaseReferences<_$AppDatabase, $CachedGamesTable, CachedGame>,
          ),
          CachedGame,
          PrefetchHooks Function()
        > {
  $$CachedGamesTableTableManager(_$AppDatabase db, $CachedGamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedGamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedGamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedGamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> gameId = const Value.absent(),
                Value<String> ownerSub = const Value.absent(),
                Value<String> summaryJson = const Value.absent(),
                Value<DateTime?> playedDate = const Value.absent(),
                Value<String?> opponentName = const Value.absent(),
                Value<String?> opponentSearch = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedGamesCompanion(
                gameId: gameId,
                ownerSub: ownerSub,
                summaryJson: summaryJson,
                playedDate: playedDate,
                opponentName: opponentName,
                opponentSearch: opponentSearch,
                updatedAt: updatedAt,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String gameId,
                required String ownerSub,
                required String summaryJson,
                Value<DateTime?> playedDate = const Value.absent(),
                Value<String?> opponentName = const Value.absent(),
                Value<String?> opponentSearch = const Value.absent(),
                required DateTime updatedAt,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedGamesCompanion.insert(
                gameId: gameId,
                ownerSub: ownerSub,
                summaryJson: summaryJson,
                playedDate: playedDate,
                opponentName: opponentName,
                opponentSearch: opponentSearch,
                updatedAt: updatedAt,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedGamesTable, CachedGame>(table),
                  BaseReferences<_$AppDatabase, $CachedGamesTable, CachedGame>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedGamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedGamesTable,
      CachedGame,
      $$CachedGamesTableFilterComposer,
      $$CachedGamesTableOrderingComposer,
      $$CachedGamesTableAnnotationComposer,
      $$CachedGamesTableCreateCompanionBuilder,
      $$CachedGamesTableUpdateCompanionBuilder,
      (
        CachedGame,
        BaseReferences<_$AppDatabase, $CachedGamesTable, CachedGame>,
      ),
      CachedGame,
      PrefetchHooks Function()
    >;
typedef $$CachedAnalysesTableCreateCompanionBuilder =
    CachedAnalysesCompanion Function({
      required String gameId,
      required String ownerSub,
      required int schemaVersion,
      required int schemaMinor,
      required String payload,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$CachedAnalysesTableUpdateCompanionBuilder =
    CachedAnalysesCompanion Function({
      Value<String> gameId,
      Value<String> ownerSub,
      Value<int> schemaVersion,
      Value<int> schemaMinor,
      Value<String> payload,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$CachedAnalysesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedAnalysesTable> {
  $$CachedAnalysesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaMinor => $composableBuilder(
    column: $table.schemaMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedAnalysesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedAnalysesTable> {
  $$CachedAnalysesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaMinor => $composableBuilder(
    column: $table.schemaMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedAnalysesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedAnalysesTable> {
  $$CachedAnalysesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get ownerSub =>
      $composableBuilder(column: $table.ownerSub, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaMinor => $composableBuilder(
    column: $table.schemaMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedAnalysesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedAnalysesTable,
          CachedAnalysis,
          $$CachedAnalysesTableFilterComposer,
          $$CachedAnalysesTableOrderingComposer,
          $$CachedAnalysesTableAnnotationComposer,
          $$CachedAnalysesTableCreateCompanionBuilder,
          $$CachedAnalysesTableUpdateCompanionBuilder,
          (
            CachedAnalysis,
            BaseReferences<_$AppDatabase, $CachedAnalysesTable, CachedAnalysis>,
          ),
          CachedAnalysis,
          PrefetchHooks Function()
        > {
  $$CachedAnalysesTableTableManager(
    _$AppDatabase db,
    $CachedAnalysesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedAnalysesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedAnalysesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedAnalysesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> gameId = const Value.absent(),
                Value<String> ownerSub = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<int> schemaMinor = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedAnalysesCompanion(
                gameId: gameId,
                ownerSub: ownerSub,
                schemaVersion: schemaVersion,
                schemaMinor: schemaMinor,
                payload: payload,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String gameId,
                required String ownerSub,
                required int schemaVersion,
                required int schemaMinor,
                required String payload,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedAnalysesCompanion.insert(
                gameId: gameId,
                ownerSub: ownerSub,
                schemaVersion: schemaVersion,
                schemaMinor: schemaMinor,
                payload: payload,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedAnalysesTable, CachedAnalysis>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedAnalysesTable,
                    CachedAnalysis
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedAnalysesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedAnalysesTable,
      CachedAnalysis,
      $$CachedAnalysesTableFilterComposer,
      $$CachedAnalysesTableOrderingComposer,
      $$CachedAnalysesTableAnnotationComposer,
      $$CachedAnalysesTableCreateCompanionBuilder,
      $$CachedAnalysesTableUpdateCompanionBuilder,
      (
        CachedAnalysis,
        BaseReferences<_$AppDatabase, $CachedAnalysesTable, CachedAnalysis>,
      ),
      CachedAnalysis,
      PrefetchHooks Function()
    >;
typedef $$PendingJobsTableCreateCompanionBuilder =
    PendingJobsCompanion Function({
      required String jobId,
      required String gameId,
      required String ownerSub,
      required JobState state,
      required DateTime createdAt,
      Value<DateTime?> lastPolledAt,
      Value<int> rowid,
    });
typedef $$PendingJobsTableUpdateCompanionBuilder =
    PendingJobsCompanion Function({
      Value<String> jobId,
      Value<String> gameId,
      Value<String> ownerSub,
      Value<JobState> state,
      Value<DateTime> createdAt,
      Value<DateTime?> lastPolledAt,
      Value<int> rowid,
    });

class $$PendingJobsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingJobsTable> {
  $$PendingJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<JobState, JobState, String> get state =>
      $composableBuilder(
        column: $table.state,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPolledAt => $composableBuilder(
    column: $table.lastPolledAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingJobsTable> {
  $$PendingJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPolledAt => $composableBuilder(
    column: $table.lastPolledAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingJobsTable> {
  $$PendingJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get ownerSub =>
      $composableBuilder(column: $table.ownerSub, builder: (column) => column);

  GeneratedColumnWithTypeConverter<JobState, String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPolledAt => $composableBuilder(
    column: $table.lastPolledAt,
    builder: (column) => column,
  );
}

class $$PendingJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingJobsTable,
          PendingJob,
          $$PendingJobsTableFilterComposer,
          $$PendingJobsTableOrderingComposer,
          $$PendingJobsTableAnnotationComposer,
          $$PendingJobsTableCreateCompanionBuilder,
          $$PendingJobsTableUpdateCompanionBuilder,
          (
            PendingJob,
            BaseReferences<_$AppDatabase, $PendingJobsTable, PendingJob>,
          ),
          PendingJob,
          PrefetchHooks Function()
        > {
  $$PendingJobsTableTableManager(_$AppDatabase db, $PendingJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> jobId = const Value.absent(),
                Value<String> gameId = const Value.absent(),
                Value<String> ownerSub = const Value.absent(),
                Value<JobState> state = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastPolledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingJobsCompanion(
                jobId: jobId,
                gameId: gameId,
                ownerSub: ownerSub,
                state: state,
                createdAt: createdAt,
                lastPolledAt: lastPolledAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String jobId,
                required String gameId,
                required String ownerSub,
                required JobState state,
                required DateTime createdAt,
                Value<DateTime?> lastPolledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingJobsCompanion.insert(
                jobId: jobId,
                gameId: gameId,
                ownerSub: ownerSub,
                state: state,
                createdAt: createdAt,
                lastPolledAt: lastPolledAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingJobsTable, PendingJob>(table),
                  BaseReferences<_$AppDatabase, $PendingJobsTable, PendingJob>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingJobsTable,
      PendingJob,
      $$PendingJobsTableFilterComposer,
      $$PendingJobsTableOrderingComposer,
      $$PendingJobsTableAnnotationComposer,
      $$PendingJobsTableCreateCompanionBuilder,
      $$PendingJobsTableUpdateCompanionBuilder,
      (
        PendingJob,
        BaseReferences<_$AppDatabase, $PendingJobsTable, PendingJob>,
      ),
      PendingJob,
      PrefetchHooks Function()
    >;
typedef $$EventOutboxTableCreateCompanionBuilder =
    EventOutboxCompanion Function({
      Value<int> id,
      Value<String?> ownerSub,
      required String deviceId,
      required String sessionId,
      required String name,
      required DateTime occurredAt,
      Value<String> propsJson,
      Value<int> attempts,
    });
typedef $$EventOutboxTableUpdateCompanionBuilder =
    EventOutboxCompanion Function({
      Value<int> id,
      Value<String?> ownerSub,
      Value<String> deviceId,
      Value<String> sessionId,
      Value<String> name,
      Value<DateTime> occurredAt,
      Value<String> propsJson,
      Value<int> attempts,
    });

class $$EventOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $EventOutboxTable> {
  $$EventOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get propsJson => $composableBuilder(
    column: $table.propsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $EventOutboxTable> {
  $$EventOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get propsJson => $composableBuilder(
    column: $table.propsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventOutboxTable> {
  $$EventOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerSub =>
      $composableBuilder(column: $table.ownerSub, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get propsJson =>
      $composableBuilder(column: $table.propsJson, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $$EventOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventOutboxTable,
          OutboxEvent,
          $$EventOutboxTableFilterComposer,
          $$EventOutboxTableOrderingComposer,
          $$EventOutboxTableAnnotationComposer,
          $$EventOutboxTableCreateCompanionBuilder,
          $$EventOutboxTableUpdateCompanionBuilder,
          (
            OutboxEvent,
            BaseReferences<_$AppDatabase, $EventOutboxTable, OutboxEvent>,
          ),
          OutboxEvent,
          PrefetchHooks Function()
        > {
  $$EventOutboxTableTableManager(_$AppDatabase db, $EventOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> ownerSub = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> propsJson = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => EventOutboxCompanion(
                id: id,
                ownerSub: ownerSub,
                deviceId: deviceId,
                sessionId: sessionId,
                name: name,
                occurredAt: occurredAt,
                propsJson: propsJson,
                attempts: attempts,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> ownerSub = const Value.absent(),
                required String deviceId,
                required String sessionId,
                required String name,
                required DateTime occurredAt,
                Value<String> propsJson = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => EventOutboxCompanion.insert(
                id: id,
                ownerSub: ownerSub,
                deviceId: deviceId,
                sessionId: sessionId,
                name: name,
                occurredAt: occurredAt,
                propsJson: propsJson,
                attempts: attempts,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventOutboxTable, OutboxEvent>(table),
                  BaseReferences<_$AppDatabase, $EventOutboxTable, OutboxEvent>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventOutboxTable,
      OutboxEvent,
      $$EventOutboxTableFilterComposer,
      $$EventOutboxTableOrderingComposer,
      $$EventOutboxTableAnnotationComposer,
      $$EventOutboxTableCreateCompanionBuilder,
      $$EventOutboxTableUpdateCompanionBuilder,
      (
        OutboxEvent,
        BaseReferences<_$AppDatabase, $EventOutboxTable, OutboxEvent>,
      ),
      OutboxEvent,
      PrefetchHooks Function()
    >;
typedef $$FeedbackOutboxTableCreateCompanionBuilder =
    FeedbackOutboxCompanion Function({
      Value<int> id,
      required String ownerSub,
      required String commentId,
      required FeedbackRating rating,
      required DateTime createdAt,
      Value<int> attempts,
    });
typedef $$FeedbackOutboxTableUpdateCompanionBuilder =
    FeedbackOutboxCompanion Function({
      Value<int> id,
      Value<String> ownerSub,
      Value<String> commentId,
      Value<FeedbackRating> rating,
      Value<DateTime> createdAt,
      Value<int> attempts,
    });

class $$FeedbackOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $FeedbackOutboxTable> {
  $$FeedbackOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commentId => $composableBuilder(
    column: $table.commentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FeedbackRating, FeedbackRating, String>
  get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FeedbackOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $FeedbackOutboxTable> {
  $$FeedbackOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerSub => $composableBuilder(
    column: $table.ownerSub,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commentId => $composableBuilder(
    column: $table.commentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FeedbackOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeedbackOutboxTable> {
  $$FeedbackOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerSub =>
      $composableBuilder(column: $table.ownerSub, builder: (column) => column);

  GeneratedColumn<String> get commentId =>
      $composableBuilder(column: $table.commentId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FeedbackRating, String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $$FeedbackOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FeedbackOutboxTable,
          OutboxFeedback,
          $$FeedbackOutboxTableFilterComposer,
          $$FeedbackOutboxTableOrderingComposer,
          $$FeedbackOutboxTableAnnotationComposer,
          $$FeedbackOutboxTableCreateCompanionBuilder,
          $$FeedbackOutboxTableUpdateCompanionBuilder,
          (
            OutboxFeedback,
            BaseReferences<_$AppDatabase, $FeedbackOutboxTable, OutboxFeedback>,
          ),
          OutboxFeedback,
          PrefetchHooks Function()
        > {
  $$FeedbackOutboxTableTableManager(
    _$AppDatabase db,
    $FeedbackOutboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedbackOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedbackOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedbackOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> ownerSub = const Value.absent(),
                Value<String> commentId = const Value.absent(),
                Value<FeedbackRating> rating = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => FeedbackOutboxCompanion(
                id: id,
                ownerSub: ownerSub,
                commentId: commentId,
                rating: rating,
                createdAt: createdAt,
                attempts: attempts,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String ownerSub,
                required String commentId,
                required FeedbackRating rating,
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
              }) => FeedbackOutboxCompanion.insert(
                id: id,
                ownerSub: ownerSub,
                commentId: commentId,
                rating: rating,
                createdAt: createdAt,
                attempts: attempts,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FeedbackOutboxTable, OutboxFeedback>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FeedbackOutboxTable,
                    OutboxFeedback
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FeedbackOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FeedbackOutboxTable,
      OutboxFeedback,
      $$FeedbackOutboxTableFilterComposer,
      $$FeedbackOutboxTableOrderingComposer,
      $$FeedbackOutboxTableAnnotationComposer,
      $$FeedbackOutboxTableCreateCompanionBuilder,
      $$FeedbackOutboxTableUpdateCompanionBuilder,
      (
        OutboxFeedback,
        BaseReferences<_$AppDatabase, $FeedbackOutboxTable, OutboxFeedback>,
      ),
      OutboxFeedback,
      PrefetchHooks Function()
    >;
typedef $$KvTableCreateCompanionBuilder = KvCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$KvTableUpdateCompanionBuilder = KvCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$KvTableFilterComposer extends Composer<_$AppDatabase, $KvTable> {
  $$KvTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KvTableOrderingComposer extends Composer<_$AppDatabase, $KvTable> {
  $$KvTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KvTableAnnotationComposer extends Composer<_$AppDatabase, $KvTable> {
  $$KvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KvTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KvTable,
          KvEntry,
          $$KvTableFilterComposer,
          $$KvTableOrderingComposer,
          $$KvTableAnnotationComposer,
          $$KvTableCreateCompanionBuilder,
          $$KvTableUpdateCompanionBuilder,
          (KvEntry, BaseReferences<_$AppDatabase, $KvTable, KvEntry>),
          KvEntry,
          PrefetchHooks Function()
        > {
  $$KvTableTableManager(_$AppDatabase db, $KvTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => KvCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => KvCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KvTable, KvEntry>(table),
                  BaseReferences<_$AppDatabase, $KvTable, KvEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KvTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KvTable,
      KvEntry,
      $$KvTableFilterComposer,
      $$KvTableOrderingComposer,
      $$KvTableAnnotationComposer,
      $$KvTableCreateCompanionBuilder,
      $$KvTableUpdateCompanionBuilder,
      (KvEntry, BaseReferences<_$AppDatabase, $KvTable, KvEntry>),
      KvEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
  $$CachedGamesTableTableManager get cachedGames =>
      $$CachedGamesTableTableManager(_db, _db.cachedGames);
  $$CachedAnalysesTableTableManager get cachedAnalyses =>
      $$CachedAnalysesTableTableManager(_db, _db.cachedAnalyses);
  $$PendingJobsTableTableManager get pendingJobs =>
      $$PendingJobsTableTableManager(_db, _db.pendingJobs);
  $$EventOutboxTableTableManager get eventOutbox =>
      $$EventOutboxTableTableManager(_db, _db.eventOutbox);
  $$FeedbackOutboxTableTableManager get feedbackOutbox =>
      $$FeedbackOutboxTableTableManager(_db, _db.feedbackOutbox);
  $$KvTableTableManager get kv => $$KvTableTableManager(_db, _db.kv);
}
