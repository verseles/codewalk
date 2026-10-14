import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'version_policy.dart';

enum OpenCodeInteractionProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
  interactionKindMismatch,
  unsupportedValue,
}

/// Contains a finite category, never native content or identifiers.
final class OpenCodeInteractionProjectionException implements Exception {
  const OpenCodeInteractionProjectionException(this.failure);

  final OpenCodeInteractionProjectionFailure failure;

  @override
  String toString() =>
      'OpenCodeInteractionProjectionException(${failure.name})';
}

const _idLimit = 4096;
const _listLimit = 4096;
const _manifestLimit = 64 * 1024;
// Total retained form text, like the siblings' selected-content budgets.
const _formLimit = 256 * 1024;
const _maxEpochMillis = 8640000000000000;
const _asked = 'permission.asked';
const _replied = 'permission.replied';
const _formCreated = 'form.created';
const _formReplied = 'form.replied';
const _formCancelled = 'form.cancelled';
const _types = {_asked, _replied, _formCreated, _formReplied, _formCancelled};
const _replies = {'once', 'always', 'reject'};
const _globalSession = 'global';

/// Projects the five ephemeral 2.0.22 permission and form events without
/// owning a stream or clock.
///
/// Returns one [InteractionOpened] or [InteractionResolved], or null for
/// unrelated types, foreign sessions and an ask already resident under the
/// same identity. Interaction IDs are the native `per…`/`frm_` IDs; forms owned
/// by the `"global"` sentinel get a [GlobalOwner] for this harness.
///
/// Permission choices use the native reply literals: `once` (request scope),
/// `always` only when the ask carries `save` patterns (persisted per project,
/// shown as the scope preview) and `reject`, which settles the session's batch
/// and accepts a note through the reply route. The event never says who
/// replied, so replies resolve with an unknown origin; a form cancellation
/// resolves as cancelled. Form answers, request messages and native metadata
/// are validated but never copied, and the frame location is never read.
SessionEvent? projectOpenCodeInteractionEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) _fail(OpenCodeInteractionProjectionFailure.malformed);
  if (!_types.contains(type)) return null;
  final data = _object(frame['data']);
  final permission = type == _asked || type == _replied;
  final form = type == _formCreated ? _object(data['form']) : null;
  final sessionText = _text((form ?? data)['sessionID'], nonempty: true);
  final ref = current.ref;
  final DomainOwner owner;
  if (!permission && sessionText == _globalSession) {
    owner = GlobalOwner(ref.harnessRef);
  } else {
    if (!sessionText.startsWith('ses')) {
      _fail(OpenCodeInteractionProjectionFailure.malformed);
    }
    if (sessionText != ref.nativeId) return null;
    owner = SessionOwner(ref);
  }
  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeInteractionProjectionFailure.unsupportedVersion);
  }
  for (final part in [
    ref.host.value,
    ref.harness.value,
    ref.nativeId,
    position.id,
    position.epoch,
  ]) {
    _text(part, nonempty: true);
  }
  final nativeId = _id(frame['id'], 'evt_');
  final created = frame['created'];
  if (created is! num ||
      !created.isFinite ||
      created < 0 ||
      created > _maxEpochMillis) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  // Ephemeral by the pinned schema, like the sibling ephemeral events.
  if (frame.containsKey('durable')) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }

  final notProjected = <String, Object?>{};
  final SessionEvent Function(EventMeta meta) build;
  switch (type) {
    case _asked:
      final request = _permissionRequest(data, owner, notProjected);
      if (_resident(current, request)) return null;
      build = (meta) => InteractionOpened(meta: meta, request: request);
    case _formCreated:
      final request = _formRequest(form!, owner, notProjected);
      if (_resident(current, request)) return null;
      build = (meta) => InteractionOpened(meta: meta, request: request);
    case _replied:
      final id = InteractionId(_id(data['requestID'], 'per'));
      final reply = _text(data['reply']);
      if (!_replies.contains(reply)) {
        _fail(OpenCodeInteractionProjectionFailure.unsupportedValue);
      }
      build = (meta) => InteractionResolved(
        meta: meta,
        resolution: InteractionResolution(
          id: id,
          owner: owner,
          kind: OpenValue<InteractionResolutionKind>.unknown(
            'replyOriginUnobserved',
          ),
          response: ApprovalResponse(reply),
          resolvedAt: _instant(created),
        ),
      );
    case _formReplied || _formCancelled:
      final id = InteractionId(_id(data['id'], 'frm_'));
      if (type == _formReplied) {
        _answer(data['answer']);
        notProjected['answerNotProjected'] = true;
      }
      build = (meta) => InteractionResolved(
        meta: meta,
        resolution: InteractionResolution(
          id: id,
          owner: owner,
          kind: type == _formReplied
              ? OpenValue<InteractionResolutionKind>.unknown(
                  'replyOriginUnobserved',
                )
              : const OpenValue.known(InteractionResolutionKind.cancelled),
          resolvedAt: _instant(created),
        ),
      );
    default:
      // Unreachable: `_types` filters every other type above.
      _fail(OpenCodeInteractionProjectionFailure.unsupportedValue);
  }

  return build(
    EventMeta(
      owner: SessionOwner(ref),
      position: position,
      receivedAt: receivedAt,
      source: SourceProvenance(
        harness: ref.harnessRef,
        version: sourceVersion,
        nativeType: type,
        nativeEventId: nativeId,
        durability: const OpenValue.known(Durability.ephemeral),
        extra: CanonicalValue({'nativeCreated': created, ...notProjected}),
      ),
    ),
  );
}

/// The request a native `Permission.Request` opens, shared by the live ask
/// and the session's pending-permission read.
InteractionRequest _permissionRequest(
  Map<String, Object?> data,
  DomainOwner owner,
  Map<String, Object?> notProjected,
) {
  final id = InteractionId(_id(data['id'], 'per'));
  final action = _text(data['action']);
  final resources = _strings(data['resources']);
  final save = data.containsKey('save') ? _strings(data['save']) : null;
  Map<String, Object?>? source;
  if (data.containsKey('source')) {
    final raw = _object(data['source']);
    if (_text(raw['type']) != 'tool') {
      _fail(OpenCodeInteractionProjectionFailure.unsupportedValue);
    }
    source = {
      'type': 'tool',
      'messageID': _text(raw['messageID']),
      'id': _text(raw['id']),
    };
  }
  if (data.containsKey('metadata')) {
    _object(data['metadata']);
    notProjected['metadataNotProjected'] = true;
  }
  if (data.containsKey('message')) {
    _text(data['message']);
    notProjected['messageNotProjected'] = true;
  }
  final subject = _manifest({
    'action': action,
    'resources': resources,
    'source': ?source,
  });
  final patterns = save == null || save.isEmpty
      ? null
      : _manifest({'patterns': save});
  return InteractionRequest(
    id: id,
    owner: owner,
    kind: const OpenValue.known(InteractionKind.permission),
    title: action,
    subject: subject,
    choices: [
      ApprovalChoice(
        id: 'once',
        label: 'once',
        allows: true,
        scope: const OpenValue.known(ApprovalScope.once),
        resolutionScope: const OpenValue.known(ResolutionScope.request),
      ),
      // Without save patterns the server treats `always` like `once`.
      if (patterns != null)
        ApprovalChoice(
          id: 'always',
          label: 'always',
          allows: true,
          scope: const OpenValue.known(ApprovalScope.persistentProject),
          resolutionScope: const OpenValue.known(ResolutionScope.project),
          scopePreview: patterns,
        ),
      // One rejection settles every pending request of the session.
      ApprovalChoice(
        id: 'reject',
        label: 'reject',
        allows: false,
        scope: const OpenValue.known(ApprovalScope.once),
        resolutionScope: const OpenValue.known(ResolutionScope.session),
        acceptsNote: true,
      ),
    ],
    // Eligibility only; the reply policy belongs to the reply flow.
    autoApprovable: true,
  );
}

/// The request a native `Form.Info` opens, shared by the live creation and
/// the session's pending-form read.
InteractionRequest _formRequest(
  Map<String, Object?> form,
  DomainOwner owner,
  Map<String, Object?> notProjected,
) {
  final id = InteractionId(_id(form['id'], 'frm_'));
  final title = _text(form['title']);
  if (form.containsKey('metadata')) {
    _object(form['metadata']);
    notProjected['metadataNotProjected'] = true;
  }
  return InteractionRequest(
    id: id,
    owner: owner,
    kind: const OpenValue.known(InteractionKind.form),
    title: title,
    form: _formSpec(form['fields']),
    requiresInput: true,
  );
}

/// The pending request of one row from `GET /api/session/{id}/permission`.
/// Session-scoped reads never carry another session or a global owner.
InteractionRequest openCodePendingPermission(Object? row, SessionRef ref) {
  final data = _object(row);
  if (_text(data['sessionID'], nonempty: true) != ref.nativeId) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  return _permissionRequest(data, SessionOwner(ref), {});
}

/// The pending request of one row from `GET /api/session/{id}/form`.
InteractionRequest openCodePendingForm(Object? row, SessionRef ref) {
  final form = _object(row);
  if (_text(form['sessionID'], nonempty: true) != ref.nativeId) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  return _formRequest(form, SessionOwner(ref), {});
}

/// True for a duplicate ask; a different resident kind is a conflict.
bool _resident(SessionState current, InteractionRequest request) {
  for (final resident in current.interactions) {
    if (resident.identityKey != request.identityKey) continue;
    if (resident.kind.value != request.kind.value) {
      _fail(OpenCodeInteractionProjectionFailure.interactionKindMismatch);
    }
    return true;
  }
  return false;
}

DateTime _instant(num created) =>
    DateTime.fromMillisecondsSinceEpoch(created.floor(), isUtc: true);

FormSpec _formSpec(Object? value) {
  if (value is! List<Object?>) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  if (value.isEmpty) _fail(OpenCodeInteractionProjectionFailure.malformed);
  if (value.length > _listLimit) {
    _fail(OpenCodeInteractionProjectionFailure.limitExceeded);
  }
  final budget = _Budget();
  final fields = [for (final field in value) _field(_object(field), budget)];
  try {
    return FormSpec(fields: fields);
  } on ArgumentError {
    // Duplicate keys or a condition on a later/unknown field.
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
}

FormField _field(Map<String, Object?> raw, _Budget budget) {
  budget.charge(raw);
  final key = _text(raw['key']);
  final type = _text(raw['type'], nonempty: true);
  final title = _optionalText(raw, 'title');
  final description = _optionalText(raw, 'description');
  if (type == 'external') {
    return _guard(
      () => FormField(
        key: key,
        kind: const OpenValue.known(FormFieldKind.externalLink),
        title: title,
        description: description,
        externalUrl: _text(raw['url']),
      ),
    );
  }
  final required = _optionalBool(raw, 'required') ?? false;
  final hidden = _optionalBool(raw, 'hidden') ?? false;
  final condition = raw.containsKey('when') ? _when(raw['when']) : null;
  final constraints = <String, Object?>{};
  void number(String name) {
    if (raw.containsKey(name)) constraints[name] = _number(raw[name]);
  }

  void count(String name) {
    if (raw.containsKey(name)) constraints[name] = _count(raw[name]);
  }

  FormFieldKind? kind;
  var options = const <FormOption>[];
  var custom = false;
  FormAnswer? defaultAnswer;
  switch (type) {
    case 'string':
      kind = FormFieldKind.string;
      if (raw.containsKey('format')) {
        final format = _text(raw['format']);
        if (!const {'email', 'uri', 'date', 'date-time'}.contains(format)) {
          _fail(OpenCodeInteractionProjectionFailure.unsupportedValue);
        }
        constraints['format'] = format;
      }
      count('minLength');
      count('maxLength');
      for (final name in ['pattern', 'placeholder']) {
        final text = _optionalText(raw, name);
        if (text != null) constraints[name] = text;
      }
      if (raw.containsKey('options')) options = _options(raw['options']);
      custom = _optionalBool(raw, 'custom') ?? false;
      if (raw.containsKey('default')) {
        defaultAnswer = StringAnswer(_text(raw['default']));
      }
    case 'number' || 'integer':
      kind = type == 'number' ? FormFieldKind.number : FormFieldKind.integer;
      number('minimum');
      number('maximum');
      if (raw.containsKey('default')) {
        final value = _number(raw['default']);
        if (type == 'integer') {
          if (value != value.truncate() || value.abs() > 9007199254740991) {
            _fail(OpenCodeInteractionProjectionFailure.malformed);
          }
          defaultAnswer = IntegerAnswer(value.toInt());
        } else {
          defaultAnswer = NumberAnswer(value);
        }
      }
    case 'boolean':
      kind = FormFieldKind.boolean;
      if (raw.containsKey('default')) {
        final value = raw['default'];
        if (value is! bool) {
          _fail(OpenCodeInteractionProjectionFailure.malformed);
        }
        defaultAnswer = BooleanAnswer(value);
      }
    case 'multiselect':
      kind = FormFieldKind.multiSelect;
      options = _options(raw['options']);
      count('minItems');
      count('maxItems');
      custom = _optionalBool(raw, 'custom') ?? false;
      if (raw.containsKey('default')) {
        defaultAnswer = MultiSelectAnswer(_strings(raw['default']));
      }
  }
  return _guard(
    () => FormField(
      key: key,
      // A future field type stays explicit and unanswerable, without content.
      kind: kind == null
          ? OpenValue<FormFieldKind>.unknown(type)
          : OpenValue.known(kind),
      title: title,
      description: description,
      required: required,
      hidden: hidden,
      acceptsCustom: custom,
      options: options,
      condition: condition,
      defaultAnswer: defaultAnswer,
      constraints: constraints.isEmpty ? null : _manifest(constraints),
    ),
  );
}

/// All native conditions must hold; multiselect membership is Core semantics.
FormCondition _when(Object? value) {
  if (value is! List<Object?>) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  if (value.length > _listLimit) {
    _fail(OpenCodeInteractionProjectionFailure.limitExceeded);
  }
  final conditions = <FormCondition>[];
  for (final entry in value) {
    final raw = _object(entry);
    final key = _text(raw['key']);
    final op = _text(raw['op']);
    final operand = raw['value'];
    if (operand is! String && operand is! bool) _number(operand);
    if (operand is String) _bytes(operand, _idLimit);
    conditions.add(switch (op) {
      'eq' => EqualsCondition(key, operand!),
      'neq' => NotEqualsCondition(key, operand!),
      _ => _fail(OpenCodeInteractionProjectionFailure.unsupportedValue),
    });
  }
  return conditions.length == 1 ? conditions.single : AllConditions(conditions);
}

List<FormOption> _options(Object? value) {
  if (value is! List<Object?>) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  if (value.length > _listLimit) {
    _fail(OpenCodeInteractionProjectionFailure.limitExceeded);
  }
  return [
    for (final entry in value)
      () {
        final raw = _object(entry);
        return FormOption(
          value: _text(raw['value']),
          label: _text(raw['label']),
          description: _optionalText(raw, 'description'),
        );
      }(),
  ];
}

/// Validates the native answer shape without retaining it.
void _answer(Object? value) {
  final answer = _object(value);
  if (answer.length > _listLimit) {
    _fail(OpenCodeInteractionProjectionFailure.limitExceeded);
  }
  for (final entry in answer.entries) {
    _bytes(entry.key, _idLimit);
    final v = entry.value;
    if (v is String) {
      _bytes(v, _manifestLimit);
    } else if (v is List<Object?>) {
      _strings(v);
    } else if (v is! bool) {
      _number(v);
    }
  }
}

/// Bounds the whole form by its native size, an upper bound on what is kept.
final class _Budget {
  var _bytes = 0;

  void charge(Map<String, Object?> field) {
    try {
      _bytes += utf8.encode(jsonEncode(field)).length;
    } on JsonUnsupportedObjectError {
      _fail(OpenCodeInteractionProjectionFailure.malformed);
    }
    if (_bytes > _formLimit) {
      _fail(OpenCodeInteractionProjectionFailure.limitExceeded);
    }
  }
}

T _guard<T>(T Function() build) {
  try {
    return build();
  } on ArgumentError {
    // Duplicate option values or a default of the wrong type.
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
}

CanonicalValue _manifest(Map<String, Object?> value) {
  if (utf8.encode(jsonEncode(value)).length > _manifestLimit) {
    _fail(OpenCodeInteractionProjectionFailure.limitExceeded);
  }
  return CanonicalValue(value);
}

List<String> _strings(Object? value) {
  if (value is! List<Object?>) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  if (value.length > _listLimit) {
    _fail(OpenCodeInteractionProjectionFailure.limitExceeded);
  }
  return [for (final entry in value) _text(entry)];
}

num _number(Object? value) {
  if (value is! num || !value.isFinite) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  return value;
}

int _count(Object? value) {
  final number = _number(value);
  if (number < 0 || number != number.truncate() || number > 9007199254740991) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  return number.toInt();
}

bool? _optionalBool(Map<String, Object?> raw, String key) {
  if (!raw.containsKey(key)) return null;
  final value = raw[key];
  if (value is! bool) _fail(OpenCodeInteractionProjectionFailure.malformed);
  return value;
}

String? _optionalText(Map<String, Object?> raw, String key) =>
    raw.containsKey(key) ? _text(raw[key]) : null;

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  return value;
}

String _id(Object? value, String prefix) {
  final result = _text(value, nonempty: true);
  if (!result.startsWith(prefix)) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  return result;
}

String _text(Object? value, {bool nonempty = false}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    _fail(OpenCodeInteractionProjectionFailure.malformed);
  }
  _bytes(value, _idLimit);
  return value;
}

void _bytes(String value, int cap) {
  if (value.length > cap) {
    _fail(OpenCodeInteractionProjectionFailure.limitExceeded);
  }
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        _fail(OpenCodeInteractionProjectionFailure.malformed);
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        _fail(OpenCodeInteractionProjectionFailure.malformed);
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      _fail(OpenCodeInteractionProjectionFailure.malformed);
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > cap) {
      _fail(OpenCodeInteractionProjectionFailure.limitExceeded);
    }
  }
}

Never _fail(OpenCodeInteractionProjectionFailure failure) =>
    throw OpenCodeInteractionProjectionException(failure);
