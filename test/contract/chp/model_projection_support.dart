import 'package:codewalk_core/codewalk_core.dart';

// Deliberately test-only projections for the domain values used by parity
// checks. These are not production codecs or a complete Harness DTO mapper.
Map<String, Object?> projectOwner(DomainOwner owner) => switch (owner) {
  SessionOwner() => {
    'type': 'session',
    'session': owner.session.toJson(),
    if (owner.origin != null) 'origin': owner.origin!.toJson(),
  },
  ProjectOwner() => {
    'type': 'project',
    'project': owner.project.toJson(),
    if (owner.harness != null) 'harness': owner.harness!.toJson(),
  },
  HostOwner() => {
    'type': 'host',
    'host': owner.host.toJson(),
    if (owner.harness != null) 'harness': owner.harness!.toJson(),
  },
  GlobalOwner() => {'type': 'global', 'harness': owner.harness.toJson()},
  UnknownOwner() => {
    'type': 'unknown',
    'reason': owner.reason,
    if (owner.raw != null) 'raw': owner.raw!.toJson(),
  },
};

Map<String, Object?> projectSource(SourceProvenance source) => {
  'harness': source.harness.toJson(),
  'version': source.version,
  'nativeType': source.nativeType,
  'durability': source.durability.toJson(),
  if (source.nativeEventId != null) 'nativeEventId': source.nativeEventId,
  if (source.nativeCursor != null) 'nativeCursor': source.nativeCursor,
  if (source.aggregateId != null) 'aggregateId': source.aggregateId,
  if (source.aggregateSeq != null)
    'aggregateSeq': source.aggregateSeq!.toString(),
  if (source.extra != null) 'extra': source.extra!.toJson(),
};

Map<String, Object?> projectEventMeta(EventMeta meta) => {
  'owner': projectOwner(meta.owner),
  'position': meta.position.toJson(),
  'receivedAt': meta.receivedAt.toUtc().toIso8601String(),
  'source': projectSource(meta.source),
};

Map<String, Object?> projectUnknownEvent(UnknownEvent event) => {
  'type': 'unknownEvent',
  'meta': projectEventMeta(event.meta),
  'rawType': event.rawType,
  'raw': event.raw.toJson(),
};

Map<String, Object?> projectItemMeta(ItemMeta meta) => {
  'id': meta.id.toJson(),
  'generation': meta.generation,
  'status': meta.status.toJson(),
  'source': projectSource(meta.source),
  if (meta.turnId != null) 'turnId': meta.turnId!.toJson(),
  if (meta.ordinal != null) 'ordinal': meta.ordinal,
};

Map<String, Object?> projectTimelineItem(TimelineItem item) => switch (item) {
  AssistantText() => {
    'type': 'assistantText',
    'meta': projectItemMeta(item.meta),
    'text': item.text,
    'complete': item.complete,
    'prefixMissing': item.prefixMissing,
  },
  Reasoning() => {
    'type': 'reasoning',
    'meta': projectItemMeta(item.meta),
    'text': item.text,
    'complete': item.complete,
    'prefixMissing': item.prefixMissing,
  },
  UnknownItem() => {
    'type': 'unknownItem',
    'meta': projectItemMeta(item.meta),
    'rawType': item.rawType,
    'raw': item.raw.toJson(),
    if (item.fallbackText != null) 'fallbackText': item.fallbackText,
  },
  _ => throw UnsupportedError('This test projection covers three item kinds'),
};

Map<String, Object?> projectBoundary(SnapshotBoundary boundary) => {
  'owner': projectOwner(boundary.owner),
  'hydrationGeneration': boundary.hydrationGeneration,
  'readStart': boundary.readStart.toJson(),
  'readStartedAt': boundary.readStartedAt.toUtc().toIso8601String(),
  'authority': boundary.authority.toJson(),
  if (boundary.readCompletedAt != null)
    'readCompletedAt': boundary.readCompletedAt!.toUtc().toIso8601String(),
  if (boundary.source != null) 'source': projectSource(boundary.source!),
};

Map<String, Object?> projectTimelineCollection(
  SnapshotCollection<TimelineItem> collection,
) => {
  'values': collection.values.map(projectTimelineItem).toList(),
  'boundary': projectBoundary(collection.boundary),
  'complete': collection.complete,
};

Map<String, Object?> projectPendingInput(PendingInput input) => {
  'id': input.id.toJson(),
  'text': input.text,
  'delivery': input.delivery.toJson(),
  if (input.commandId != null) 'commandId': input.commandId!.toJson(),
};

Map<String, Object?> projectPendingCollection(
  SnapshotCollection<PendingInput> collection,
) => {
  'values': collection.values.map(projectPendingInput).toList(),
  'boundary': projectBoundary(collection.boundary),
  'complete': collection.complete,
};

Map<String, Object?> projectInfo(SessionInfo info) => {
  'ref': info.ref.toJson(),
  'title': info.title,
  'ownership': info.ownership.toJson(),
  'lineage': info.lineage.toJson(),
  if (info.project != null) 'project': info.project!.toJson(),
  if (info.metadata != null) 'metadata': info.metadata!.toJson(),
};

// The parity fixtures contain only info, timeline and pending observations.
Map<String, Object?> projectSnapshot(SessionSnapshot snapshot) => {
  'ref': snapshot.ref.toJson(),
  'hydrationGeneration': snapshot.hydrationGeneration,
  'hasMoreHistory': snapshot.hasMoreHistory,
  if (snapshot.info != null)
    'info': {
      'value': projectInfo(snapshot.info!.value),
      'boundary': projectBoundary(snapshot.info!.boundary),
    },
  if (snapshot.timeline != null)
    'timeline': projectTimelineCollection(snapshot.timeline!),
  if (snapshot.pending != null)
    'pending': projectPendingCollection(snapshot.pending!),
  if (snapshot.nextHistoryCursor != null)
    'nextHistoryCursor': snapshot.nextHistoryCursor!.value,
};

Map<String, Object?> projectCapability(Capability capability) => {
  'support': capability.support.toJson(),
  'verified': capability.verified,
  'constraints': capability.constraints.toJson(),
  if (capability.reason != null) 'reason': capability.reason,
  if (capability.semantics != null) 'semantics': capability.semantics,
};

Map<String, Object?> projectError(ErrorInfo error) => {
  'kind': error.kind.toJson(),
  'rawType': error.rawType,
  'rawMessage': error.rawMessage,
  'retryable': error.retryable,
  if (error.retryAt != null)
    'retryAt': error.retryAt!.toUtc().toIso8601String(),
  if (error.action != null) 'action': error.action!.toJson(),
  if (error.details != null) 'details': error.details!.toJson(),
};

Map<String, Object?> projectReceipt(CommandReceipt receipt) => {
  'id': receipt.id.toJson(),
  'owner': projectOwner(receipt.owner),
  'state': receipt.state.toJson(),
  'admissionKnown': receipt.admissionKnown,
  if (receipt.nativeRef != null) 'nativeRef': receipt.nativeRef,
  if (receipt.error != null) 'error': projectError(receipt.error!),
  if (receipt.unavailable != null)
    'unavailable': {
      'capability': receipt.unavailable!.capability,
      'reason': receipt.unavailable!.reason,
    },
  if (receipt.reason != null) 'reason': receipt.reason,
  if (receipt.details != null) 'details': receipt.details!.toJson(),
};

Map<String, Object?> projectCreateResult(CreateResult result) => {
  'receipt': projectReceipt(result.receipt),
  if (result.handle != null) 'handleRef': result.handle!.ref.toJson(),
};

Map<String, Object?> projectChoice(ApprovalChoice choice) => {
  'id': choice.id,
  'label': choice.label,
  'allows': choice.allows,
  'scope': choice.scope.toJson(),
  'resolutionScope': choice.resolutionScope.toJson(),
  'acceptsNote': choice.acceptsNote,
  if (choice.scopePreview != null)
    'scopePreview': choice.scopePreview!.toJson(),
};

Map<String, Object?> projectFormCondition(FormCondition condition) =>
    switch (condition) {
      NotEqualsCondition() => {
        'type': 'notEquals',
        'key': condition.key,
        'value': condition.value.toJson(),
      },
      IncludesCondition() => {
        'type': 'includes',
        'key': condition.key,
        'value': condition.value,
      },
      UnknownCondition() => {
        'type': 'unknown',
        'rawType': condition.rawType,
        'raw': condition.raw.toJson(),
      },
      _ => throw UnsupportedError('Not needed by these test fixtures'),
    };

Map<String, Object?> projectForm(FormSpec form) => {
  'fields': [
    for (final field in form.fields)
      {
        'key': field.key,
        'kind': field.kind.toJson(),
        'required': field.required,
        'hidden': field.hidden,
        'acceptsCustom': field.acceptsCustom,
        'options': [
          for (final option in field.options)
            {
              'value': option.value,
              'label': option.label,
              if (option.description != null) 'description': option.description,
            },
        ],
        if (field.title != null) 'title': field.title,
        if (field.description != null) 'description': field.description,
        if (field.condition != null)
          'condition': projectFormCondition(field.condition!),
        if (field.defaultAnswer != null)
          'defaultAnswer': field.defaultAnswer!.toJson(),
        if (field.metadata != null) 'metadata': field.metadata!.toJson(),
        if (field.constraints != null)
          'constraints': field.constraints!.toJson(),
        if (field.externalUrl != null) 'externalUrl': field.externalUrl,
      },
  ],
  if (form.metadata != null) 'metadata': form.metadata!.toJson(),
};

Map<String, Object?> projectInteraction(InteractionRequest request) => {
  'id': request.id.toJson(),
  'owner': projectOwner(request.owner),
  'kind': request.kind.toJson(),
  'title': request.title,
  'choices': request.choices.map(projectChoice).toList(),
  'requiresInput': request.requiresInput,
  'autoApprovable': request.autoApprovable,
  if (request.form != null) 'form': projectForm(request.form!),
  if (request.subject != null) 'subject': request.subject!.toJson(),
};
