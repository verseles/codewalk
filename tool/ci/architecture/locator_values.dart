import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Tracks locator values that escape a composition function. Concrete objects
/// built from resolved services are ordinary values. Objects or containers
/// carrying the actual locator retain its capability.
final class LocatorValues {
  LocatorValues(this.unit, this.imported) {
    unit.accept(_bindings);
  }

  final CompilationUnit unit;
  final Set<String> imported;
  final _Bindings _bindings = _Bindings();

  bool escapes(AstNode node, [Set<AstNode>? seen]) {
    final visiting = seen ?? <AstNode>{};
    if (!visiting.add(node)) return false;
    bool value(AstNode child) => escapes(child, {...visiting});
    if (node is FunctionExpression) return value(node.body);
    if (node is ExpressionFunctionBody) return value(node.expression);
    if (node is BlockFunctionBody) {
      final returns = _OwnReturns();
      node.accept(returns);
      return returns.values.any(value);
    }
    if (node is SimpleIdentifier) {
      final binding = _binding(node);
      if (binding != null) {
        return binding.$2 || binding.$1 != null && value(binding.$1!);
      }
      return node.name == 'GetIt' || imported.contains(node.name);
    }
    if (node is PrefixedIdentifier) {
      return node.identifier.name == 'GetIt' ||
          imported.contains('${node.prefix.name}.${node.identifier.name}') ||
          value(node.prefix);
    }
    if (node is PropertyAccess) {
      return node.target != null && value(node.target!);
    }
    if (node is InstanceCreationExpression) {
      return node.constructorName.type.name.lexeme == 'GetIt' ||
          node.argumentList.arguments.any(value);
    }
    if (node is MethodInvocation) {
      // An ordinary service returned by a lookup is not the locator used to
      // resolve it. Explicitly resolving GetIt itself still exports a locator.
      final arguments = node.typeArguments?.arguments;
      final binding = node.target == null ? _binding(node.methodName) : null;
      final knownLookup =
          node.target != null &&
              _locatorReceiver(node.target!, {}) &&
              const {
                'get',
                'getAsync',
                'getAll',
                'getAllAsync',
                'call',
                'I',
                'instance',
              }.contains(node.methodName.name) ||
          node.target == null &&
              binding != null &&
              binding.$1 is! FunctionExpression &&
              (binding.$2 ||
                  binding.$1 != null && _locatorReceiver(binding.$1!, {}));
      if (knownLookup) {
        return arguments?.any(
              (type) => type is NamedType && type.name.lexeme == 'GetIt',
            ) ??
            false;
      }
      // A generic argument alone does not classify a value. Unknown calls may
      // forward their actual arguments, as identity<Object>(GetIt.I) does.
      if (node.argumentList.arguments.any(value)) return true;
      if (node.target == null) {
        if (binding != null) {
          final initializer = binding.$1;
          return initializer is FunctionExpression && value(initializer);
        }
        final name = node.methodName.name;
        if (name.isNotEmpty &&
            name[0] == name[0].toUpperCase() &&
            name[0] != name[0].toLowerCase()) {
          return name == 'GetIt' || node.argumentList.arguments.any(value);
        }
        return node.methodName.name == 'GetIt' ||
            imported.contains(node.methodName.name);
      }
      if (node.target is SimpleIdentifier &&
          imported.contains(
            '${(node.target! as SimpleIdentifier).name}.${node.methodName.name}',
          )) {
        return true;
      }
      return const {
            'asNewInstance',
            'I',
            'instance',
          }.contains(node.methodName.name) &&
          value(node.target!);
    }
    if (node is ParenthesizedExpression) return value(node.expression);
    if (node is IndexExpression) return value(node.realTarget);
    if (node is CascadeExpression) return value(node.target);
    if (node is FunctionExpressionInvocation) {
      return value(node.function) || node.argumentList.arguments.any(value);
    }
    if (node is AssignmentExpression) return value(node.rightHandSide);
    if (node is NamedExpression) return value(node.expression);
    if (node is AsExpression) {
      return _getIt(node.type) || value(node.expression);
    }
    if (node is PostfixExpression && node.operator.lexeme == '!') {
      return value(node.operand);
    }
    if (node is ListLiteral) return node.elements.any(value);
    if (node is SetOrMapLiteral) return node.elements.any(value);
    if (node is RecordLiteral) return node.fields.any(value);
    if (node is MapLiteralEntry) return value(node.key) || value(node.value);
    if (node is SpreadElement) return value(node.expression);
    if (node is NullAwareElement) return value(node.value);
    if (node is IfElement) {
      return value(node.thenElement) ||
          node.elseElement != null && value(node.elseElement!);
    }
    if (node is ForElement) return value(node.body);
    if (node is BinaryExpression && node.operator.lexeme == '??') {
      return value(node.leftOperand) || value(node.rightOperand);
    }
    if (node is SwitchExpression) {
      return node.cases.any((branch) => value(branch.expression));
    }
    if (node is ConditionalExpression) {
      return value(node.thenExpression) || value(node.elseExpression);
    }
    if (node is AwaitExpression) return value(node.expression);
    return false;
  }

  (AstNode?, bool)? _binding(SimpleIdentifier identifier) {
    final candidates = <(AstNode, AstNode?, bool)>[];
    var enclosing = identifier.parent;
    while (enclosing != null) {
      if (enclosing is ForElement && _contains(enclosing.body, identifier)) {
        final parts = enclosing.forLoopParts;
        if (parts is ForEachPartsWithDeclaration &&
            parts.loopVariable.name.lexeme == identifier.name) {
          candidates.add((
            enclosing,
            parts.iterable,
            _getIt(parts.loopVariable.type),
          ));
        } else if (parts is ForEachPartsWithIdentifier &&
            parts.identifier.name == identifier.name) {
          candidates.add((enclosing, parts.iterable, false));
        }
      }
      enclosing = enclosing.parent;
    }
    for (final variable in _bindings.variables) {
      if (variable.name.lexeme != identifier.name) continue;
      final scope = _scope(variable);
      if (scope == null ||
          !_contains(scope, identifier) ||
          scope is Block && variable.offset > identifier.offset) {
        continue;
      }
      final parent = variable.parent;
      candidates.add((
        scope,
        variable.initializer,
        parent is VariableDeclarationList && _getIt(parent.type),
      ));
    }
    for (final function in _bindings.functions) {
      if (function.name.lexeme != identifier.name) continue;
      final scope = _scope(function);
      if (scope != null && _contains(scope, identifier)) {
        candidates.add((
          scope,
          function.functionExpression,
          _getIt(function.returnType),
        ));
      }
    }
    for (final parameter in _bindings.parameters) {
      if (parameter.name?.lexeme != identifier.name) continue;
      var scope = parameter.parent;
      while (scope != null && scope is! FormalParameterList) {
        scope = scope.parent;
      }
      scope = scope?.parent;
      if (scope != null && _contains(scope, identifier)) {
        candidates.add((scope, null, _getIt(parameter.type)));
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.$1.length.compareTo(b.$1.length));
    return (candidates.first.$2, candidates.first.$3);
  }

  // Aggregate escape tracking is deliberately broader than receiver identity:
  // a list carrying GetIt does not make an arbitrary list.get<T>() a lookup.
  bool _locatorReceiver(AstNode node, Set<AstNode> visiting) {
    if (!visiting.add(node)) return false;
    bool receiver(AstNode child) => _locatorReceiver(child, {...visiting});
    if (node is SimpleIdentifier) {
      final binding = _binding(node);
      return binding != null
          ? binding.$2 || binding.$1 != null && receiver(binding.$1!)
          : node.name == 'GetIt';
    }
    if (node is PrefixedIdentifier) {
      return node.identifier.name == 'GetIt' ||
          const {
                'I',
                'instance',
                'get',
                'getAsync',
                'getAll',
                'getAllAsync',
              }.contains(node.identifier.name) &&
              receiver(node.prefix);
    }
    if (node is PropertyAccess) {
      return node.target != null &&
          const {
            'I',
            'instance',
            'get',
            'getAsync',
            'getAll',
            'getAllAsync',
          }.contains(node.propertyName.name) &&
          receiver(node.target!);
    }
    if (node is InstanceCreationExpression) {
      return node.constructorName.type.name.lexeme == 'GetIt';
    }
    if (node is MethodInvocation) {
      if (node.target == null) {
        final binding = _binding(node.methodName);
        return binding != null &&
            (binding.$2 || binding.$1 != null && receiver(binding.$1!));
      }
      return receiver(node.target!) &&
          (const {
                'asNewInstance',
                'I',
                'instance',
              }.contains(node.methodName.name) ||
              (node.typeArguments?.arguments.any(_getIt) ?? false));
    }
    if (node is ParenthesizedExpression) return receiver(node.expression);
    if (node is AsExpression) {
      return _getIt(node.type) || receiver(node.expression);
    }
    if (node is PostfixExpression && node.operator.lexeme == '!') {
      return receiver(node.operand);
    }
    if (node is FunctionExpression) return receiver(node.body);
    if (node is ExpressionFunctionBody) return receiver(node.expression);
    if (node is BlockFunctionBody) {
      final returns = _OwnReturns();
      node.accept(returns);
      return returns.values.any(receiver);
    }
    return false;
  }

  bool _getIt(TypeAnnotation? type) =>
      type is NamedType && type.name.lexeme == 'GetIt';
  bool _contains(AstNode scope, AstNode node) =>
      scope.offset <= node.offset && scope.end >= node.end;

  AstNode? _scope(AstNode node) {
    var parent = node.parent;
    while (parent != null &&
        parent is! Block &&
        parent is! ClassBody &&
        parent is! CompilationUnit) {
      parent = parent.parent;
    }
    return parent;
  }
}

final class _Bindings extends RecursiveAstVisitor<void> {
  final List<VariableDeclaration> variables = [];
  final List<FunctionDeclaration> functions = [];
  final List<SimpleFormalParameter> parameters = [];

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    variables.add(node);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    functions.add(node);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    parameters.add(node);
    super.visitSimpleFormalParameter(node);
  }
}

final class _OwnReturns extends RecursiveAstVisitor<void> {
  final List<Expression> values = [];

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitReturnStatement(ReturnStatement node) {
    if (node.expression != null) values.add(node.expression!);
  }
}
