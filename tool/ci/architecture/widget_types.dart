import 'package:analyzer/dart/ast/ast.dart';

typedef _TypeSymbol = (String library, String name);

/// Resolves widget ancestry by declaration identity, rather than by basename.
/// Visibility belongs to each import/export edge; conditional alternatives are
/// unioned because the architecture guard must cover every target platform.
final class WidgetTypes {
  WidgetTypes({
    required this.unit,
    required this.resolve,
    required this.framework,
  });

  final CompilationUnit Function(String) unit;
  final String? Function(String, String) resolve;
  final String? framework;
  final Map<String, Map<String, List<NamedType>>> _declarations = {};
  final Map<(String, String?, String), Set<_TypeSymbol>> _references = {};
  final Set<_TypeSymbol> _widgets = {};

  Set<String> declarations(String path) => {
    for (final name in _types(path).keys)
      if (_isWidget((path, name), {})) name,
  };

  Map<String, List<NamedType>> _types(String path) => _declarations.putIfAbsent(
    path,
    () {
      final types = <String, List<NamedType>>{};
      for (final declaration in unit(path).declarations) {
        if (declaration is ClassDeclaration) {
          types[declaration.namePart.typeName.lexeme] = [
            if (declaration.extendsClause case final clause?) clause.superclass,
            ...?declaration.implementsClause?.interfaces,
            ...?declaration.withClause?.mixinTypes,
          ];
        } else if (declaration is GenericTypeAlias) {
          final type = declaration.type;
          types[declaration.name.lexeme] = [if (type is NamedType) type];
        } else if (declaration is ClassTypeAlias) {
          types[declaration.name.lexeme] = [
            declaration.superclass,
            ...?declaration.implementsClause?.interfaces,
            ...declaration.withClause.mixinTypes,
          ];
        } else if (declaration is MixinDeclaration) {
          types[declaration.name.lexeme] = [
            ...?declaration.onClause?.superclassConstraints,
            ...?declaration.implementsClause?.interfaces,
          ];
        }
      }
      return types;
    },
  );

  bool _isWidget(_TypeSymbol symbol, Set<_TypeSymbol> visiting) {
    if (_widgets.contains(symbol)) return true;
    if (!visiting.add(symbol)) return false;
    final (path, name) = symbol;
    if (path == framework &&
        const {
          'Widget',
          'StatelessWidget',
          'StatefulWidget',
          'State',
        }.contains(name)) {
      _widgets.add(symbol);
      return true;
    }
    for (final base in _types(path)[name] ?? const <NamedType>[]) {
      for (final ancestor in _typeReference(path, base)) {
        if (_isWidget(ancestor, {...visiting})) {
          _widgets.add(symbol);
          return true;
        }
      }
    }
    return false;
  }

  Set<_TypeSymbol> _typeReference(String path, NamedType type) {
    final prefix = type.importPrefix?.name.lexeme;
    final name = type.name.lexeme;
    return _references.putIfAbsent((path, prefix, name), () {
      // A local declaration shadows an unprefixed import, including ordinary
      // classes whose name happens to equal a framework type.
      if (prefix == null && _types(path).containsKey(name)) {
        return {(path, name)};
      }
      final candidates = <_TypeSymbol>{};
      for (final directive in unit(
        path,
      ).directives.whereType<ImportDirective>()) {
        if (directive.prefix?.name != prefix ||
            !_visible(name, directive.combinators)) {
          continue;
        }
        for (final uri in _uris(directive)) {
          final target = resolve(path, uri);
          if (target != null) candidates.addAll(_exported(target, name, {}));
        }
      }
      return candidates;
    });
  }

  Set<_TypeSymbol> _exported(
    String path,
    String name,
    Set<_TypeSymbol> visiting,
  ) {
    if (name.startsWith('_') || !visiting.add((path, name))) return {};
    if (_types(path).containsKey(name)) return {(path, name)};
    final candidates = <_TypeSymbol>{};
    // Imports do not form a public namespace; only explicit exports propagate
    // declarations, with that export's own show/hide filters.
    for (final directive in unit(
      path,
    ).directives.whereType<ExportDirective>()) {
      if (!_visible(name, directive.combinators)) continue;
      for (final uri in _uris(directive)) {
        final target = resolve(path, uri);
        if (target != null) {
          candidates.addAll(_exported(target, name, {...visiting}));
        }
      }
    }
    return candidates;
  }

  Iterable<String> _uris(NamespaceDirective directive) sync* {
    final uri = directive.uri.stringValue;
    if (uri != null) yield uri;
    for (final configuration in directive.configurations) {
      final alternative = configuration.uri.stringValue;
      if (alternative != null) yield alternative;
    }
  }

  bool _visible(String name, Iterable<Combinator> combinators) {
    for (final combinator in combinators) {
      if (combinator is ShowCombinator &&
          !combinator.shownNames.any((item) => item.name == name)) {
        return false;
      }
      if (combinator is HideCombinator &&
          combinator.hiddenNames.any((item) => item.name == name)) {
        return false;
      }
    }
    return true;
  }
}
