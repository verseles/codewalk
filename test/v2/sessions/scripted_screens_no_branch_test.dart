import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Static proof that the authored v2 UI never branches on harness or product
/// names: no identifier or string literal in the session screens, their shared
/// session contracts, or the app composition may mention the test-only or
/// harness vocabulary, and no file there may import a test or harness tree.
///
/// Comments are excluded on purpose: they carry no behavior (the single
/// current token hit is a doc comment in `permission_mode.dart`). Product
/// lore in identifiers stays allowed on purpose: `OpenCodeThemePreset` names
/// the v2 appearance catalog (a ported preset registry), not a transport
/// branch. What fails is a harness *name* as a string literal — the exact
/// shape a name-based branch would take — read from the CI manifest next to
/// the G4 `harness-branch` rule in `tool/ci/architecture/ast_rules.dart`.
const _scannedDirs = [
  'lib/features/sessions',
  'lib/shared/sessions',
  'lib/app',
];

/// Tokens that only exist in the synthetic harness world; none of them may
/// appear in authored UI identifiers or strings.
const _harnessTokens = [
  'scripted',
  'synthetic',
  'fake',
  'mock',
  'stub',
  'fixture',
  'harness_host',
];

void main() {
  test('authored UI never branches on harness or product names', () {
    final root = Directory.current;
    for (final dir in _scannedDirs) {
      expect(
        Directory('${root.path}/$dir').existsSync(),
        isTrue,
        reason: 'missing scanned tree $dir',
      );
    }
    final manifest = File(
      '${root.path}/tool/ci/v2_architecture_manifest.json',
    );
    expect(manifest.existsSync(), isTrue, reason: 'missing G4 manifest');
    final harnessNames = (jsonDecode(manifest.readAsStringSync())
            as Map<String, dynamic>)['harnessNames'] as List;
    final products = {
      for (final name in harnessNames) (name as String).toLowerCase(),
    };
    expect(products, isNotEmpty);

    final files = <File>[];
    for (final dir in _scannedDirs) {
      files.addAll(
        Directory('${root.path}/$dir')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
      );
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty, reason: 'no Dart files scanned');

    final violations = <String>[];
    for (final file in files) {
      final relative = file.path.substring(root.path.length + 1);
      final result = parseString(
        content: file.readAsStringSync(),
        throwIfDiagnostics: false,
      );
      for (final error in result.errors) {
        violations.add(
          '$relative:${result.lineInfo.getLocation(error.offset).lineNumber}: '
          'syntax ${error.message}',
        );
      }
      result.unit.accept(
        _NoBranchVisitor(relative, result, products, violations),
      );
    }
    expect(
      violations,
      isEmpty,
      reason: 'harness/product branches in authored UI:\n'
          '${violations.join('\n')}',
    );
  });
}

final class _NoBranchVisitor extends RecursiveAstVisitor<void> {
  _NoBranchVisitor(this.relative, this.result, this.products, this.violations);

  final String relative;
  final ParseStringResult result;
  final Set<String> products;
  final List<String> violations;

  String _at(AstNode node) =>
      '$relative:${result.lineInfo.getLocation(node.offset).lineNumber}';

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final name = node.name.toLowerCase();
    for (final token in _harnessTokens) {
      if (name.contains(token)) {
        violations.add('${_at(node)}: identifier "${node.name}" '
            'mentions "$token"');
      }
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    final value = node.stringValue;
    if (value != null) {
      final lower = value.toLowerCase();
      for (final token in _harnessTokens) {
        if (lower.contains(token)) {
          violations.add('${_at(node)}: string "$value" mentions "$token"');
        }
      }
      if (products.contains(value.trim().toLowerCase())) {
        violations.add(
          '${_at(node)}: string "$value" is a harness/product name',
        );
      }
    }
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    _checkUri(node, node.uri.stringValue);
    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _checkUri(node, node.uri.stringValue);
    super.visitExportDirective(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    for (final element in node.elements) {
      if (element is InterpolationString) {
        final lower = element.value.toLowerCase();
        for (final token in _harnessTokens) {
          if (lower.contains(token)) {
            violations.add('${_at(node)}: string "$lower" mentions "$token"');
          }
        }
        if (products.contains(lower.trim())) {
          violations.add(
            '${_at(node)}: string "$lower" is a harness/product name',
          );
        }
      }
    }
    super.visitStringInterpolation(node);
  }

  @override
  void visitPartDirective(PartDirective node) {
    _checkUri(node, node.uri.stringValue);
    super.visitPartDirective(node);
  }

  void _checkUri(AstNode node, String? uri) {
    if (uri == null) return;
    final lower = uri.toLowerCase();
    if (lower.contains('test/') ||
        lower.contains('flutter_test') ||
        lower.contains('harness_')) {
      violations.add('${_at(node)}: dependency "$uri" leaves the v2 UI tree');
    }
  }
}
