import 'commands.dart';
import 'identity.dart';
import 'session.dart';
import 'timeline.dart';
import 'values.dart';

final class FileRef {
  FileRef({required this.project, required String path})
    : path = requireText(path);
  final ProjectRef project;

  /// Opaque host-native path. Core does not claim physical containment.
  final String path;
}

enum FileKind { file, directory, link, unknown }

final class FileEntry {
  FileEntry({
    required this.ref,
    required this.kind,
    this.sizeBytes,
    this.metadata,
  }) {
    if (sizeBytes != null && sizeBytes! < 0) {
      throw ArgumentError('Negative file size');
    }
  }
  final FileRef ref;
  final OpenValue<FileKind> kind;
  final int? sizeBytes;
  final CanonicalValue? metadata;
}

final class FileContent {
  const FileContent({required this.ref, required this.output});
  final FileRef ref;
  final OutputRef output;
}

final class SearchQuery {
  SearchQuery({
    required this.project,
    required this.query,
    this.cursor,
    this.limit = 50,
  }) {
    if (limit <= 0) throw ArgumentError('Search limit must be positive');
  }
  final ProjectRef project;
  final String query;
  final String? cursor;
  final int limit;
}

final class SearchHit {
  SearchHit({required this.file, this.line, this.preview}) {
    if (line != null && line! < 0) throw ArgumentError('Negative search line');
  }
  final FileRef file;
  final int? line;
  final String? preview;
}

final class FileWrite {
  const FileWrite({
    required this.id,
    required this.file,
    required this.content,
  });
  final CommandId id;
  final FileRef file;
  final OutputRef content;
}

final class TerminalRequest {
  TerminalRequest({
    required this.id,
    required this.owner,
    this.columns = 80,
    this.rows = 24,
    this.metadata,
  }) {
    if (columns <= 0 || rows <= 0) {
      throw ArgumentError('Terminal dimensions must be positive');
    }
  }
  final CommandId id;
  final DomainOwner owner;
  final int columns;
  final int rows;
  final CanonicalValue? metadata;
}

final class TerminalResult {
  TerminalResult({required this.receipt, this.handle}) {
    if (handle != null &&
        (!receipt.admissionKnown ||
            !receipt.owner.hasSameScope(handle!.owner) ||
            receipt.nativeRef != handle!.id)) {
      throw ArgumentError(
        'Terminal handle requires known admission in its original scope',
      );
    }
  }
  final CommandReceipt receipt;
  final TerminalHandle? handle;
}

abstract interface class TerminalHandle {
  String get id;
  DomainOwner get owner;
  Stream<OutputRef> get output;
  Future<CommandReceipt> input(String text, {required CommandId id});
  Future<CommandReceipt> resize(int columns, int rows, {required CommandId id});
  Future<CommandReceipt> close({required CommandId id});
  Future<void> detach();
}

abstract interface class WorkspaceFacet {
  Future<Page<FileEntry>> list(ProjectRef project, {String? cursor});
  Future<FileContent> read(FileRef file);
  Future<Page<SearchHit>> search(SearchQuery query);
  Future<CommandReceipt> write(FileWrite request);
  Future<TerminalResult> openTerminal(TerminalRequest request);
}
