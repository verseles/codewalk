import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

// Synthetic port implementations validate signatures, not native behavior/G3.
const _host = HostId('host');
const _harness = HarnessRef(_host, HarnessInstanceId('installation'));
const _ref = SessionRef(_host, HarnessInstanceId('installation'), 'session');
const _owner = SessionOwner(_ref);
const _project = ProjectRef(_host, '/project');
final _now = DateTime.utc(2026, 10, 4);

SnapshotBoundary _boundary({
  int seq = 10,
  String generation = 'hydration',
  SessionRef ref = _ref,
}) => SnapshotBoundary(
  owner: SessionOwner(ref),
  hydrationGeneration: generation,
  readStart: StreamPosition(
    id: 'client-stream',
    epoch: 'observation-generation',
    seq: BigInt.from(seq),
  ),
  readStartedAt: _now,
  authority: const OpenValue.known(SnapshotAuthority.authoritative),
  source: SourceProvenance(
    harness: ref.harnessRef,
    version: 'test-version',
    nativeType: 'snapshot',
  ),
);

class _ReceiptProducer {
  _ReceiptProducer(this.owner);
  final DomainOwner owner;
  final List<CommandId> commands = [];
  Future<CommandReceipt> admit(CommandId id, {String? nativeRef}) async {
    commands.add(id);
    return CommandReceipt.accepted(id: id, owner: owner, nativeRef: nativeRef);
  }
}

final class _Queue extends _ReceiptProducer implements QueueFacet {
  _Queue(super.owner);
  @override
  Future<CommandReceipt> cancel(ItemId input, {required CommandId id}) =>
      admit(id);
  @override
  Future<CommandReceipt> edit(
    ItemId input,
    PromptDraft replacement, {
    required CommandId id,
  }) => admit(id);
  @override
  Future<CommandReceipt> reorder(
    List<ItemId> inputs, {
    required CommandId id,
  }) => admit(id);
}

final class _Undo extends _ReceiptProducer implements UndoFacet {
  _Undo(super.owner);
  @override
  Future<CommandReceipt> stage(
    RevertRequest request, {
    required CommandId id,
  }) => admit(id);
  @override
  Future<CommandReceipt> clear({required CommandId id}) => admit(id);
  @override
  Future<CommandReceipt> commit({required CommandId id}) => admit(id);
}

final class _Work extends _ReceiptProducer implements WorkFacet {
  _Work(super.owner);
  @override
  Future<List<WorkItem>> list() async => const [];
  @override
  Future<CommandReceipt> stop(WorkId work, {required CommandId id}) =>
      admit(id);
  @override
  Future<CommandReceipt> moveToBackground({required CommandId id}) => admit(id);
  @override
  Future<CommandReceipt> sendToChild(
    SessionRef child,
    PromptDraft draft, {
    required CommandId id,
  }) => admit(id);
}

final class _Lifecycle extends _ReceiptProducer implements LifecycleFacet {
  _Lifecycle(super.owner);
  @override
  Future<CommandReceipt> resume({required CommandId id}) => admit(id);
  @override
  Future<CreateResult> fork(ForkRequest request) async {
    final child = _Handle(
      const SessionRef(_host, HarnessInstanceId('installation'), 'fork'),
    );
    return CreateResult(
      receipt: await admit(request.id, nativeRef: child.ref.nativeId),
      handle: child,
    );
  }

  @override
  Future<CommandReceipt> archive({required CommandId id}) => admit(id);
  @override
  Future<CommandReceipt> delete({required CommandId id}) => admit(id);
}

final class _Interactions extends _ReceiptProducer implements InteractionFacet {
  _Interactions(super.owner);
  @override
  Future<Page<InteractionRequest>> pending(DomainOwner owner) async =>
      Page(items: const []);
  @override
  Future<CommandReceipt> respond(
    DomainOwner owner,
    InteractionId interaction,
    InteractionResponse response, {
    required CommandId id,
  }) => admit(id);
}

final class _Terminal extends _ReceiptProducer implements TerminalHandle {
  _Terminal(super.owner, {this.id = 'terminal'});
  @override
  final String id;
  int detachments = 0;
  @override
  Stream<OutputRef> get output => const Stream.empty();
  @override
  Future<CommandReceipt> input(String text, {required CommandId id}) =>
      admit(id);
  @override
  Future<CommandReceipt> resize(
    int columns,
    int rows, {
    required CommandId id,
  }) => admit(id);
  @override
  Future<CommandReceipt> close({required CommandId id}) => admit(id);
  @override
  Future<void> detach() async {
    detachments++;
  }
}

final class _Workspace extends _ReceiptProducer implements WorkspaceFacet {
  _Workspace(super.owner);
  @override
  Future<Page<FileEntry>> list(ProjectRef project, {String? cursor}) async =>
      Page(items: const []);
  @override
  Future<FileContent> read(FileRef file) async => FileContent(
    ref: file,
    output: OutputRef(id: 'file-content'),
  );
  @override
  Future<Page<SearchHit>> search(SearchQuery query) async =>
      Page(items: const []);
  @override
  Future<CommandReceipt> write(FileWrite request) => admit(request.id);
  @override
  Future<TerminalResult> openTerminal(TerminalRequest request) async =>
      TerminalResult(
        receipt: await admit(request.id, nativeRef: 'terminal'),
        handle: _Terminal(owner),
      );
}

final class _Catalog implements CatalogFacet {
  @override
  Future<List<ModelEntry>> models() async => [
    ModelEntry(
      id: 'model',
      providerId: 'provider',
      label: 'Model',
      inputModalities: {'image/png': true, 'application/pdf': null},
    ),
  ];
  @override
  Future<List<CatalogEntry>> entries(OpenValue<CatalogKind> kind) async =>
      const [];
}

final class _Handle extends _ReceiptProducer implements SessionHandle {
  _Handle(this.ref, {bool facets = false}) : super(SessionOwner(ref)) {
    if (facets) {
      queue = _Queue(owner);
      undo = _Undo(owner);
      work = _Work(owner);
      lifecycle = _Lifecycle(owner);
    }
  }
  @override
  final SessionRef ref;
  @override
  QueueFacet? queue;
  @override
  UndoFacet? undo;
  @override
  WorkFacet? work;
  @override
  LifecycleFacet? lifecycle;
  int detachments = 0;
  @override
  Stream<SessionEvent> get events => const Stream.empty();
  @override
  Future<SessionSnapshot> snapshot({
    HistoryCursor? before,
    int limit = 50,
  }) async => SessionSnapshot(ref: ref, hydrationGeneration: 'hydration');
  @override
  Future<CommandReceipt> send(
    PromptDraft draft, {
    required CommandId id,
    OpenValue<Delivery>? delivery,
  }) => admit(id);
  @override
  Future<CommandReceipt> interrupt(
    InterruptTarget target, {
    required CommandId id,
  }) => admit(id);
  @override
  Future<CommandReceipt> respond(
    InteractionId interaction,
    InteractionResponse response, {
    required CommandId id,
  }) => admit(id);
  @override
  Future<CommandReceipt> select(
    SelectionChange change, {
    required CommandId id,
  }) => admit(id);
  @override
  Future<void> detach() async {
    detachments++;
  }
}

final class _Adapter implements HarnessAdapter {
  final _handle = _Handle(_ref);
  final List<OpenIntent> observations = [];
  @override
  HarnessDescriptor get descriptor => HarnessDescriptor(
    ref: _harness,
    kind: 'synthetic',
    version: 'test-version',
    stability: const OpenValue.known(Stability.experimental),
    compatibility: const OpenValue.known(Compatibility.supported),
  );
  @override
  Stream<ConnectionState> get connection => const Stream.empty();
  @override
  Future<CapabilitySet> capabilities({DomainOwner? owner}) async =>
      CapabilitySet({}, harness: _harness, connectedVersion: 'test-version');
  @override
  Future<Page<SessionSummary>> listSessions(SessionQuery query) async =>
      Page(items: const []);
  @override
  Future<SessionHandle> open(SessionRef ref, OpenIntent intent) async {
    observations.add(intent);
    return _handle;
  }

  @override
  Future<CreateResult> create(CreateSession request) async => CreateResult(
    receipt: CommandReceipt.uncertain(
      id: request.id,
      owner: ProjectOwner(request.project, harness: request.harness),
      reason: 'lost admission response',
    ),
  );
  @override
  CatalogFacet get catalog => _Catalog();
  @override
  WorkspaceFacet? get workspace => null;
  @override
  InteractionFacet? get interactions => null;
}

void main() {
  group('non-atomic snapshot boundaries', () {
    test(
      'each collection keeps its own read-start and common hydration generation',
      () {
        final first = _boundary(seq: 10);
        final second = _boundary(seq: 20);
        final caller = <PendingInput>[
          const PendingInput(
            id: ItemId('input'),
            text: 'queued',
            delivery: OpenValue.known(Delivery.queue),
          ),
        ];
        final snapshot = SessionSnapshot(
          ref: _ref,
          hydrationGeneration: 'hydration',
          timeline: SnapshotCollection<TimelineItem>(
            values: const [],
            boundary: first,
          ),
          pending: SnapshotCollection(values: caller, boundary: second),
        );
        caller.clear();
        expect(snapshot.timeline!.boundary.readStart.seq, BigInt.from(10));
        expect(snapshot.pending!.boundary.readStart.seq, BigInt.from(20));
        expect(snapshot.pending!.values, hasLength(1));
        expect(() => snapshot.pending!.values.clear(), throwsUnsupportedError);
        expect(first.readStart.epoch, 'observation-generation');
        expect(first.hydrationGeneration, 'hydration');
      },
    );
    test('wrong session, hydration generation and source are rejected', () {
      expect(
        () => SessionSnapshot(
          ref: _ref,
          hydrationGeneration: 'new',
          pending: SnapshotCollection(values: const [], boundary: _boundary()),
        ),
        throwsArgumentError,
      );
      const other = SessionRef(_host, HarnessInstanceId('other'), 'session');
      expect(
        () => SessionSnapshot(
          ref: _ref,
          hydrationGeneration: 'hydration',
          pending: SnapshotCollection(
            values: const [],
            boundary: _boundary(ref: other),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => SnapshotBoundary(
          owner: _owner,
          hydrationGeneration: 'h',
          readStart: _boundary().readStart,
          readStartedAt: _now,
          source: SourceProvenance(
            harness: other.harnessRef,
            version: 'test',
            nativeType: 'snapshot',
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => SnapshotBoundary(
          owner: _owner,
          hydrationGeneration: 'h',
          readStart: _boundary().readStart,
          readStartedAt: _now,
          readCompletedAt: _now.subtract(const Duration(seconds: 1)),
        ),
        throwsArgumentError,
      );
    });
    test(
      'unknown authority is distinct from authoritative or derived empty data',
      () {
        final unknown = SnapshotBoundary(
          owner: _owner,
          hydrationGeneration: 'h',
          readStart: _boundary().readStart,
          readStartedAt: _now,
        );
        expect(unknown.authority.known, SnapshotAuthority.unknown);
        final derived = SnapshotBoundary(
          owner: _owner,
          hydrationGeneration: 'h',
          readStart: _boundary().readStart,
          readStartedAt: _now,
          authority: const OpenValue.known(SnapshotAuthority.derived),
        );
        expect(derived.authority, isNot(_boundary().authority));
      },
    );
    test(
      'a newer collection may carry a watermark-only source without claiming replay',
      () {
        final boundary = SnapshotBoundary(
          owner: _owner,
          hydrationGeneration: 'h',
          readStart: _boundary().readStart,
          readStartedAt: _now,
          source: SourceProvenance(
            harness: _harness,
            version: 'test',
            nativeType: 'watermark',
            aggregateSeq: BigInt.from(100),
            durability: const OpenValue.known(Durability.watermarkOnly),
          ),
        );
        expect(boundary.readStart.seq, BigInt.from(10));
        expect(boundary.source!.aggregateSeq, BigInt.from(100));
        expect(boundary.authority.known, SnapshotAuthority.unknown);
      },
    );
  });

  group('canonical ports and admission results', () {
    test('history open and detach observe without invoking mutation', () async {
      final adapter = _Adapter();
      final handle = await adapter.open(_ref, OpenIntent.viewHistory);
      await handle.snapshot();
      await handle.detach();
      expect(adapter.observations, [OpenIntent.viewHistory]);
      expect(adapter._handle.commands, isEmpty);
      expect(adapter._handle.detachments, 1);
      expect(handle.queue, isNull);
      expect(handle.undo, isNull);
      expect(handle.work, isNull);
      expect(handle.lifecycle, isNull);
      expect(adapter.workspace, isNull);
      expect(adapter.interactions, isNull);
    });
    test(
      'uncertain create returns receipt without a fabricated handle',
      () async {
        final result = await _Adapter().create(
          CreateSession(
            id: const CommandId('create'),
            harness: _harness,
            project: _project,
          ),
        );
        expect(result.receipt.state.known, ReceiptState.uncertain);
        expect(result.handle, isNull);
        expect(
          () => CreateResult(receipt: result.receipt, handle: _Handle(_ref)),
          throwsArgumentError,
        );
        expect(
          () => CreateSession(
            id: const CommandId('create'),
            harness: const HarnessRef(
              HostId('other'),
              HarnessInstanceId('installation'),
            ),
            project: _project,
          ),
          throwsArgumentError,
        );
      },
    );
    test(
      'known admission must bind handle to exact native reference and installation',
      () {
        final accepted = CommandReceipt.accepted(
          id: const CommandId('create'),
          owner: ProjectOwner(_project, harness: _harness),
          nativeRef: _ref.nativeId,
        );
        expect(
          CreateResult(receipt: accepted, handle: _Handle(_ref)).handle!.ref,
          _ref,
        );
        expect(
          () => CreateResult(
            receipt: accepted,
            handle: _Handle(
              const SessionRef(_host, HarnessInstanceId('other'), 'session'),
            ),
          ),
          throwsArgumentError,
        );
        expect(
          () => CreateResult(
            receipt: accepted,
            handle: _Handle(
              const SessionRef(
                _host,
                HarnessInstanceId('installation'),
                'wrong-native',
              ),
            ),
          ),
          throwsArgumentError,
        );
        final noRef = CommandReceipt.accepted(
          id: accepted.id,
          owner: accepted.owner,
        );
        expect(
          () => CreateResult(receipt: noRef, handle: _Handle(_ref)),
          throwsArgumentError,
        );
      },
    );
    test(
      'terminal handle similarly requires admission, exact owner and native reference',
      () {
        final accepted = CommandReceipt.accepted(
          id: const CommandId('terminal'),
          owner: _owner,
          nativeRef: 'terminal',
        );
        expect(
          TerminalResult(
            receipt: accepted,
            handle: _Terminal(_owner),
          ).handle!.id,
          'terminal',
        );
        expect(
          () => TerminalResult(
            receipt: CommandReceipt.uncertain(
              id: accepted.id,
              owner: _owner,
              reason: 'lost',
            ),
            handle: _Terminal(_owner),
          ),
          throwsArgumentError,
        );
        expect(
          () => TerminalResult(
            receipt: accepted,
            handle: _Terminal(
              const SessionOwner(
                SessionRef(_host, HarnessInstanceId('other'), 'session'),
              ),
            ),
          ),
          throwsArgumentError,
        );
        expect(
          () => TerminalResult(
            receipt: accepted,
            handle: _Terminal(_owner, id: 'different-terminal'),
          ),
          throwsArgumentError,
        );
        expect(
          () => TerminalResult(
            receipt: CommandReceipt.accepted(id: accepted.id, owner: _owner),
            handle: _Terminal(_owner),
          ),
          throwsArgumentError,
        );
      },
    );
    test(
      'every session mutation carries the supplied command correlation',
      () async {
        final handle = _Handle(_ref);
        await handle.send(
          PromptDraft(text: 'input'),
          id: const CommandId('send'),
        );
        await handle.interrupt(
          const InterruptTarget(kind: OpenValue.known(InterruptKind.turn)),
          id: const CommandId('interrupt'),
        );
        await handle.respond(
          const InteractionId('interaction'),
          ApprovalResponse('choice'),
          id: const CommandId('respond'),
        );
        await handle.select(
          const SelectionChange(selection: Selection(modelId: 'model')),
          id: const CommandId('select'),
        );
        expect(handle.commands.map((id) => id.value), [
          'send',
          'interrupt',
          'respond',
          'select',
        ]);
      },
    );
    test(
      'all optional mutation facets compile and retain correlation',
      () async {
        final queue = _Queue(_owner);
        final undo = _Undo(_owner);
        final work = _Work(_owner);
        final lifecycle = _Lifecycle(_owner);
        final interactions = _Interactions(const GlobalOwner(_harness));
        final workspace = _Workspace(_owner);
        final terminal = _Terminal(_owner);
        const input = ItemId('input');
        await queue.cancel(input, id: const CommandId('cancel'));
        await queue.edit(
          input,
          PromptDraft(text: 'edit'),
          id: const CommandId('edit'),
        );
        await queue.reorder([input], id: const CommandId('reorder'));
        await undo.stage(
          const RevertRequest(boundary: input, includeFiles: true),
          id: const CommandId('stage'),
        );
        await undo.clear(id: const CommandId('clear'));
        await undo.commit(id: const CommandId('commit'));
        await work.stop(const WorkId('work'), id: const CommandId('stop'));
        await work.moveToBackground(id: const CommandId('background'));
        await work.sendToChild(
          _ref,
          PromptDraft(text: 'child input'),
          id: const CommandId('child'),
        );
        await lifecycle.resume(id: const CommandId('resume'));
        expect(
          (await lifecycle.fork(
            const ForkRequest(id: CommandId('fork')),
          )).handle!.ref.nativeId,
          'fork',
        );
        await lifecycle.archive(id: const CommandId('archive'));
        await lifecycle.delete(id: const CommandId('delete'));
        await interactions.respond(
          const GlobalOwner(_harness),
          const InteractionId('global-form'),
          FormResponse(FormAnswers({})),
          id: const CommandId('global-response'),
        );
        await workspace.write(
          FileWrite(
            id: const CommandId('write'),
            file: FileRef(project: _project, path: 'opaque-path'),
            content: OutputRef(id: 'content'),
          ),
        );
        await workspace.openTerminal(
          TerminalRequest(id: const CommandId('terminal-open'), owner: _owner),
        );
        await terminal.input('text', id: const CommandId('terminal-input'));
        await terminal.resize(80, 24, id: const CommandId('terminal-resize'));
        await terminal.close(id: const CommandId('terminal-close'));
        await terminal.detach();
        expect(queue.commands, hasLength(3));
        expect(undo.commands, hasLength(3));
        expect(work.commands, hasLength(3));
        expect(lifecycle.commands, hasLength(4));
        expect(interactions.commands.single.value, 'global-response');
        expect(workspace.commands, hasLength(2));
        expect(terminal.commands, hasLength(3));
        expect(terminal.detachments, 1);
      },
    );
    test(
      'catalog modality absence remains unknown and cannot become a PDF pass',
      () async {
        final model = (await _Catalog().models()).single;
        expect(model.inputModalities['image/png'], isTrue);
        expect(model.inputModalities['application/pdf'], isNull);
        expect(model.contextLimit, isNull);
        expect(
          () => model.inputModalities['application/pdf'] = true,
          throwsUnsupportedError,
        );
      },
    );
  });
}
