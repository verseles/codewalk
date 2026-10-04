import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'dependency_graph.dart';
import 'manifest.dart';

/// Architecture predicates use syntax nodes, never comments or source regexes.
/// Local constants/locator aliases are followed without executing authored code.
final class AstRules extends RecursiveAstVisitor<void> {
  AstRules(
    this.source,
    this.path,
    this.manifest,
    this.violations, {
    this.importedLocators = const {},
    this.importedLookupHelpers = const {},
    this.widgetDeclarationNames = const {},
    this.importedHarnessNames = const {},
  });

  final DartSource source;
  final String path;
  final ArchitectureManifest manifest;
  final List<Violation> violations;
  final Set<String> importedLocators;
  final Set<String> importedLookupHelpers;
  final Set<String> _lookupHelpers = {};
  final Set<String> widgetDeclarationNames;
  final Set<String> importedHarnessNames;
  final List<VariableDeclaration> _variables = [];
  final List<FunctionDeclaration> _functions = [];
  final List<MethodDeclaration> _methods = [];
  final List<SimpleFormalParameter> _parameters = [];
  final Set<int> _reported = {};
  int _widgetDepth = 0;

  void check() {
    final declarations = _DeclarationCollector();
    source.unit.accept(declarations);
    _variables.addAll(declarations.variables);
    _functions.addAll(declarations.functions);
    _methods.addAll(declarations.methods);
    _parameters.addAll(
      declarations.parameters.whereType<SimpleFormalParameter>(),
    );
    _lookupHelpers.addAll(importedLookupHelpers);
    var changed = true;
    while (changed) {
      changed = false;
      for (final declaration in [
        ..._functions.map(
          (item) => (item.name.lexeme, item.functionExpression as AstNode),
        ),
        ..._methods.map((item) => (item.name.lexeme, item.body as AstNode)),
        ..._variables
            .where((item) => item.initializer != null)
            .map((item) => (item.name.lexeme, item.initializer! as AstNode)),
      ]) {
        if (_mentionsLookup(declaration.$2)) {
          changed = _lookupHelpers.add(declaration.$1) || changed;
        }
      }
    }
    source.unit.accept(this);
  }

  bool _isGetItType(TypeAnnotation? type) =>
      type is NamedType && type.name.lexeme == 'GetIt';

  void _fail(String rule, AstNode node, String message) {
    if (!_reported.add(node.offset)) return;
    violations.add(
      Violation(rule, path, message, line: source.line(node.offset)),
    );
  }

  @override
  void visitPartOfDirective(PartOfDirective node) {
    _fail(
      'part-of',
      node,
      'New v2 libraries must use imports/exports, not part of.',
    );
    super.visitPartOfDirective(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final widget = widgetDeclarationNames.contains(
      node.namePart.typeName.lexeme,
    );
    if (widget) _widgetDepth++;
    super.visitClassDeclaration(node);
    if (widget) _widgetDepth--;
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final widget = widgetDeclarationNames.contains(node.name.lexeme);
    if (widget) _widgetDepth++;
    super.visitMixinDeclaration(node);
    if (widget) _widgetDepth--;
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (manifest.isFeature(path) &&
        const {
          '==',
          '!=',
          '<',
          '>',
          '<=',
          '>=',
        }.contains(node.operator.lexeme) &&
        (_harness(node.leftOperand, {}) || _harness(node.rightOperand, {}))) {
      _fail(
        'harness-branch',
        node,
        'Features must branch on capabilities, not harness names.',
      );
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    _checkPattern(node.expression, node);
    super.visitSwitchCase(node);
  }

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    _checkPattern(node.guardedPattern.pattern, node);
    super.visitSwitchPatternCase(node);
  }

  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) {
    _checkPattern(node.guardedPattern.pattern, node);
    super.visitSwitchExpressionCase(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    final pattern = node.caseClause?.guardedPattern.pattern;
    if (pattern != null) _checkPattern(pattern, node);
    super.visitIfStatement(node);
  }

  @override
  void visitIfElement(IfElement node) {
    final pattern = node.caseClause?.guardedPattern.pattern;
    if (pattern != null) _checkPattern(pattern, node);
    super.visitIfElement(node);
  }

  void _checkPattern(AstNode pattern, AstNode owner) {
    if (manifest.isFeature(path) && _harness(pattern, {})) {
      _fail(
        'harness-branch',
        owner,
        'Features must not switch or match on harness names.',
      );
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (manifest.isFeature(path) &&
        const {'contains', 'containsKey', 'containsValue'}.contains(name) &&
        ((node.target != null && _harness(node.target!, {})) ||
            _harness(node.argumentList, {}))) {
      _fail(
        'harness-branch',
        node,
        'Features must not test membership by harness name.',
      );
    }
    if (_widgetDepth > 0 && (_lookup(node) || _helperCall(node))) {
      _fail(
        'widget-locator',
        node,
        'Inject widget dependencies; do not look them up through get_it.',
      );
    }
    if (!manifest.isComposition(path) && _lookup(node)) {
      _fail(
        'get-it-boundary',
        node,
        'Service locator lookups belong in the composition root.',
      );
    }
    super.visitMethodInvocation(node);
  }

  bool _helperCall(MethodInvocation node) {
    if (node.target == null) return _helperValue(node.methodName, {});
    if (node.methodName.name == 'call') return _helperValue(node.target!, {});
    if (node.target is! SimpleIdentifier) return false;
    final target = node.target! as SimpleIdentifier;
    if (_binding(target) != null) return false;
    return _lookupHelpers.contains('${target.name}.${node.methodName.name}');
  }

  bool _helperValue(AstNode node, Set<AstNode> visiting) {
    if (!visiting.add(node)) return false;
    if (node is SimpleIdentifier) {
      final binding = _binding(node);
      if (binding != null) {
        return binding.$1 != null && _helperValue(binding.$1!, visiting);
      }
      return _lookupHelpers.contains(node.name);
    }
    if (node is PrefixedIdentifier) {
      if (_binding(node.prefix) != null) return false;
      return _lookupHelpers.contains(
        '${node.prefix.name}.${node.identifier.name}',
      );
    }
    if (node is ParenthesizedExpression) {
      return _helperValue(node.expression, visiting);
    }
    if (node is PropertyAccess &&
        node.propertyName.name == 'call' &&
        node.target != null) {
      return _helperValue(node.target!, visiting);
    }
    if (node is FunctionExpression || node is FunctionBody) {
      return _mentionsLookup(node);
    }
    return false;
  }

  bool _mentionsLookup(AstNode node) {
    if (node is SimpleIdentifier &&
        (node.name == 'GetIt' || _lookupHelpers.contains(node.name))) {
      return true;
    }
    if (node is PrefixedIdentifier &&
        _lookupHelpers.contains(
          '${node.prefix.name}.${node.identifier.name}',
        )) {
      return true;
    }
    return node.childEntities.whereType<AstNode>().any(_mentionsLookup);
  }

  bool _lookup(MethodInvocation node) {
    final name = node.methodName.name;
    if (node.target == null) return _isLocator(node.methodName, {});
    if (node.target is SimpleIdentifier &&
        importedLocators.contains(
          '${(node.target! as SimpleIdentifier).name}.$name',
        )) {
      return true;
    }
    if (!_isLocator(node.target!, {})) return false;
    return const {
      'get',
      'getAsync',
      'getAll',
      'getAllAsync',
      'call',
      'I',
      'instance',
    }.contains(name);
  }

  bool _isLocator(AstNode node, Set<String> visited) {
    if (node is SimpleIdentifier) {
      if (node.name == 'GetIt') return true;
      final binding = _binding(node);
      if (binding == null) return importedLocators.contains(node.name);
      final (initializer, locatorType) = binding;
      return locatorType ||
          initializer != null &&
              visited.add('${node.name}:${initializer.offset}') &&
              _isLocator(initializer, visited);
    }
    if (node is PrefixedIdentifier && node.identifier.name == 'GetIt') {
      return true;
    }
    if (node is PrefixedIdentifier &&
        importedLocators.contains(
          '${node.prefix.name}.${node.identifier.name}',
        )) {
      return true;
    }
    if (node is NamedType && _isGetItType(node)) return true;
    // Only the receiver is relevant: `other(GetIt.I)` is not itself a locator.
    if (node is MethodInvocation) {
      return node.target == null
          ? _isLocator(node.methodName, visited)
          : _isLocator(node.target!, visited);
    }
    if (node is FunctionExpression) return _isLocator(node.body, visited);
    if (node is ExpressionFunctionBody) {
      return _isLocator(node.expression, visited);
    }
    if (node is BlockFunctionBody) {
      final returns = _ReturnCollector();
      node.accept(returns);
      return returns.expressions.any(
        (expression) => _isLocator(expression, {...visited}),
      );
    }
    if (node is InstanceCreationExpression) {
      return node.constructorName.type.name.lexeme == 'GetIt';
    }
    if (node is PropertyAccess) {
      return node.target != null && _isLocator(node.target!, visited);
    }
    if (node is PrefixedIdentifier) return _isLocator(node.prefix, visited);
    if (node is ParenthesizedExpression) {
      return _isLocator(node.expression, visited);
    }
    return false;
  }

  bool _harness(AstNode node, Set<String> visited) {
    if (node is StringLiteral) {
      final value = node.stringValue;
      return value != null &&
          manifest.harnessNames.contains(
            ArchitectureManifest.normalizeHarness(value),
          );
    }
    if (node is SimpleIdentifier) {
      final resolved = _binding(node);
      if (resolved == null) return importedHarnessNames.contains(node.name);
      final binding = resolved.$1;
      return binding != null &&
          visited.add('${node.name}:${binding.offset}') &&
          _harness(binding, visited);
    }
    if (node is PrefixedIdentifier &&
        importedHarnessNames.contains(
          '${node.prefix.name}.${node.identifier.name}',
        )) {
      return true;
    }
    if (node is PrefixedIdentifier &&
        manifest.harnessNames.contains(
          ArchitectureManifest.normalizeHarness(node.identifier.name),
        )) {
      return true;
    }
    if (node is PropertyAccess &&
        manifest.harnessNames.contains(
          ArchitectureManifest.normalizeHarness(node.propertyName.name),
        )) {
      return true;
    }
    for (final child in node.childEntities) {
      if (child is AstNode && _harness(child, {...visited})) return true;
    }
    return false;
  }

  (AstNode?, bool)? _binding(SimpleIdentifier identifier) {
    final candidates = <(AstNode, AstNode?, bool)>[];
    for (final variable in _variables) {
      if (variable.name.lexeme != identifier.name) continue;
      final scope = _variableScope(variable);
      if (scope == null || !_contains(scope, identifier)) continue;
      if (scope is Block && variable.offset > identifier.offset) continue;
      final parent = variable.parent;
      candidates.add((
        scope,
        variable.initializer,
        parent is VariableDeclarationList && _isGetItType(parent.type),
      ));
    }
    for (final function in _functions) {
      if (function.name.lexeme != identifier.name) continue;
      final scope = _variableScope(function);
      if (scope != null && _contains(scope, identifier)) {
        candidates.add((scope, function.functionExpression, false));
      }
    }
    for (final method in _methods) {
      if (method.name.lexeme != identifier.name) continue;
      final scope = _variableScope(method);
      if (scope != null && _contains(scope, identifier)) {
        candidates.add((scope, method.body, _isGetItType(method.returnType)));
      }
    }
    for (final parameter in _parameters) {
      if (parameter.name?.lexeme != identifier.name) continue;
      var scope = parameter.parent;
      while (scope != null && scope is! FormalParameterList) {
        scope = scope.parent;
      }
      scope = scope?.parent;
      if (scope != null && _contains(scope, identifier)) {
        candidates.add((scope, null, _isGetItType(parameter.type)));
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.$1.length.compareTo(b.$1.length));
    return (candidates.first.$2, candidates.first.$3);
  }

  AstNode? _variableScope(AstNode node) {
    var scope = node.parent;
    while (scope != null &&
        scope is! Block &&
        scope is! ClassBody &&
        scope is! CompilationUnit) {
      scope = scope.parent;
    }
    return scope;
  }

  bool _contains(AstNode scope, AstNode node) =>
      scope.offset <= node.offset && scope.end >= node.end;
}

final class _DeclarationCollector extends RecursiveAstVisitor<void> {
  final List<ClassDeclaration> classes = [];
  final List<VariableDeclaration> variables = [];
  final List<FunctionDeclaration> functions = [];
  final List<MethodDeclaration> methods = [];
  final List<FormalParameter> parameters = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    classes.add(node);
    super.visitClassDeclaration(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    variables.add(node);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    parameters.add(node);
    super.visitSimpleFormalParameter(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    functions.add(node);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    methods.add(node);
    super.visitMethodDeclaration(node);
  }
}

final class _ReturnCollector extends RecursiveAstVisitor<void> {
  final List<Expression> expressions = [];

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitReturnStatement(ReturnStatement node) {
    if (node.expression != null) expressions.add(node.expression!);
    super.visitReturnStatement(node);
  }
}
