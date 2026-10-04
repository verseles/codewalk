import 'values.dart';

enum FormFieldKind {
  string,
  number,
  integer,
  boolean,
  singleSelect,
  multiSelect,
  custom,
  externalLink,
  secret,
}

/// Option values and field keys are opaque native values, without normalization.
final class FormOption {
  const FormOption({
    required this.value,
    required this.label,
    this.description,
  });

  final String value;
  final String label;
  final String? description;
}

sealed class FormAnswer {
  const FormAnswer();

  Object? toJson();
}

final class StringAnswer extends FormAnswer {
  const StringAnswer(this.value);
  final String value;
  @override
  String toJson() => value;
}

final class NumberAnswer extends FormAnswer {
  NumberAnswer(this.value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'Must be finite');
    }
  }
  final num value;
  @override
  num toJson() => value;
}

final class IntegerAnswer extends FormAnswer {
  const IntegerAnswer(this.value);
  final int value;
  @override
  int toJson() => value;
}

final class BooleanAnswer extends FormAnswer {
  const BooleanAnswer(this.value);
  final bool value;
  @override
  bool toJson() => value;
}

final class SingleSelectAnswer extends FormAnswer {
  const SingleSelectAnswer(this.value);
  final String value;
  @override
  String toJson() => value;
}

final class MultiSelectAnswer extends FormAnswer {
  MultiSelectAnswer(Iterable<String> values) : values = immutableList(values);
  final List<String> values;
  @override
  List<String> toJson() => values;
}

final class CustomAnswer extends FormAnswer {
  const CustomAnswer(this.value);
  final CanonicalValue value;
  @override
  Object? toJson() => value.toJson();
}

/// A secret is explicitly typed; it is never added to diagnostic metadata here.
final class SecretAnswer extends FormAnswer {
  const SecretAnswer(this.value);
  final String value;
  @override
  String toJson() => value;
}

/// Retained for observation, never a supported response to a known field.
final class UnknownAnswer extends FormAnswer {
  UnknownAnswer({required String kind, required this.value})
    : kind = requireText(kind, 'kind');
  final String kind;
  final CanonicalValue value;
  @override
  Object? toJson() => value.toJson();
}

final class FormAnswers {
  FormAnswers(Map<String, FormAnswer> values)
    : values = Map<String, FormAnswer>.unmodifiable(values);

  final Map<String, FormAnswer> values;

  FormAnswer? operator [](String key) => values[key];

  Map<String, Object?> toJson() => Map<String, Object?>.unmodifiable({
    for (final entry in values.entries) entry.key: entry.value.toJson(),
  });
}

/// Conditions are immutable data. Missing or unknown answers always fail.
sealed class FormCondition {
  const FormCondition();

  bool get isKnown => true;
  bool evaluate(FormAnswers answers);
  Iterable<String> get referencedKeys;
}

/// Future conditions retain their content and cannot silently hide a required
/// field or authorize submitting the remaining fields.
final class UnknownCondition extends FormCondition {
  UnknownCondition({required String rawType, required this.raw})
    : rawType = requireText(rawType);
  final String rawType;
  final CanonicalValue raw;
  @override
  bool get isKnown => false;
  @override
  bool evaluate(FormAnswers answers) => false;
  @override
  Iterable<String> get referencedKeys => const [];
}

final class EqualsCondition extends FormCondition {
  EqualsCondition(this.key, Object value) : value = _conditionValue(value);
  final String key;
  final CanonicalValue value;

  @override
  bool evaluate(FormAnswers answers) => _matches(answers[key], value);

  @override
  Iterable<String> get referencedKeys => [key];
}

final class NotEqualsCondition extends FormCondition {
  NotEqualsCondition(this.key, Object value) : value = _conditionValue(value);
  final String key;
  final CanonicalValue value;

  @override
  bool evaluate(FormAnswers answers) {
    final answer = answers[key];
    return _isComparable(answer, value) && !_matches(answer, value);
  }

  @override
  Iterable<String> get referencedKeys => [key];
}

final class IncludesCondition extends FormCondition {
  const IncludesCondition(this.key, this.value);
  final String key;
  final String value;

  @override
  bool evaluate(FormAnswers answers) {
    final answer = answers[key];
    return answer is MultiSelectAnswer && answer.values.contains(value);
  }

  @override
  Iterable<String> get referencedKeys => [key];
}

final class AllConditions extends FormCondition {
  AllConditions(Iterable<FormCondition> conditions)
    : conditions = immutableList(conditions);
  final List<FormCondition> conditions;

  @override
  bool get isKnown => conditions.every((condition) => condition.isKnown);

  @override
  bool evaluate(FormAnswers answers) =>
      conditions.every((condition) => condition.evaluate(answers));

  @override
  Iterable<String> get referencedKeys =>
      conditions.expand((condition) => condition.referencedKeys);
}

final class AnyConditions extends FormCondition {
  AnyConditions(Iterable<FormCondition> conditions)
    : conditions = immutableList(conditions);
  final List<FormCondition> conditions;

  @override
  bool get isKnown => conditions.every((condition) => condition.isKnown);

  @override
  bool evaluate(FormAnswers answers) =>
      conditions.any((condition) => condition.evaluate(answers));

  @override
  Iterable<String> get referencedKeys =>
      conditions.expand((condition) => condition.referencedKeys);
}

final class FormField {
  FormField({
    required this.key,
    required this.kind,
    this.title,
    this.description,
    this.required = false,
    this.hidden = false,
    this.acceptsCustom = false,
    Iterable<FormOption> options = const [],
    this.condition,
    this.defaultAnswer,
    this.metadata,
    this.constraints,
    this.externalUrl,
  }) : options = immutableList(options) {
    final seen = <String>{};
    for (final option in this.options) {
      if (!seen.add(option.value)) {
        throw ArgumentError.value(option.value, 'options', 'Duplicate value');
      }
    }
    if (kind.known == FormFieldKind.externalLink && externalUrl == null) {
      throw ArgumentError('An external link requires its supplied URL');
    }
    if (defaultAnswer != null &&
        kind.known != null &&
        !_accepts(defaultAnswer!)) {
      throw ArgumentError.value(defaultAnswer, 'defaultAnswer', 'Wrong type');
    }
  }

  final String key;
  final OpenValue<FormFieldKind> kind;
  final String? title;
  final String? description;
  final bool required;
  final bool hidden;
  final bool acceptsCustom;
  final List<FormOption> options;
  final FormCondition? condition;
  final FormAnswer? defaultAnswer;
  final CanonicalValue? metadata;
  final CanonicalValue? constraints;
  final String? externalUrl;

  bool isActive(FormAnswers answers) => condition?.evaluate(answers) ?? true;

  bool _accepts(FormAnswer answer) {
    final typeMatches = switch (kind.known) {
      FormFieldKind.string => answer is StringAnswer,
      FormFieldKind.number => answer is NumberAnswer || answer is IntegerAnswer,
      FormFieldKind.integer => answer is IntegerAnswer,
      FormFieldKind.boolean => answer is BooleanAnswer,
      FormFieldKind.singleSelect => answer is SingleSelectAnswer,
      FormFieldKind.multiSelect => answer is MultiSelectAnswer,
      FormFieldKind.custom => answer is CustomAnswer,
      FormFieldKind.secret => answer is SecretAnswer,
      FormFieldKind.externalLink || null => false,
    };
    if (!typeMatches) return false;
    if (acceptsCustom) return true;
    if (options.isEmpty &&
        kind.known != FormFieldKind.singleSelect &&
        kind.known != FormFieldKind.multiSelect) {
      return true;
    }
    final selected = switch (answer) {
      StringAnswer(:final value) => [value],
      SingleSelectAnswer(:final value) => [value],
      MultiSelectAnswer(:final values) => values,
      _ => const <String>[],
    };
    return selected.every(
      (value) => options.any((option) => option.value == value),
    );
  }
}

enum FormValidationKind {
  unknownField,
  unknownCondition,
  unexpectedField,
  inactiveField,
  missingRequired,
  invalidAnswer,
}

final class FormValidationIssue {
  const FormValidationIssue({required this.key, required this.kind});
  final String key;
  final FormValidationKind kind;
}

final class FormSpec {
  FormSpec({required Iterable<FormField> fields, this.metadata})
    : fields = immutableList(fields) {
    final earlierKeys = <String>{};
    for (final field in this.fields) {
      if (earlierKeys.contains(field.key)) {
        throw ArgumentError.value(field.key, 'fields', 'Duplicate field key');
      }
      for (final key in field.condition?.referencedKeys ?? const <String>[]) {
        if (!earlierKeys.contains(key)) {
          throw ArgumentError.value(
            key,
            'condition',
            'Must reference an earlier field',
          );
        }
      }
      earlierKeys.add(field.key);
    }
  }

  final List<FormField> fields;
  final CanonicalValue? metadata;

  /// Structural validation, not a substitute for harness constraint validation.
  List<FormValidationIssue> validate(FormAnswers answers) {
    final issues = <FormValidationIssue>[];
    final keys = fields.map((field) => field.key).toSet();
    for (final key in answers.values.keys) {
      if (!keys.contains(key)) {
        issues.add(
          FormValidationIssue(
            key: key,
            kind: FormValidationKind.unexpectedField,
          ),
        );
      }
    }
    for (final field in fields) {
      final answer = answers[field.key];
      FormValidationKind? issue;
      if (field.kind.known == null) {
        issue = FormValidationKind.unknownField;
      } else if (field.condition?.isKnown == false) {
        issue = FormValidationKind.unknownCondition;
      } else if (!field.isActive(answers)) {
        if (answer != null) issue = FormValidationKind.inactiveField;
      } else if (answer == null) {
        if (field.required && field.kind.known != FormFieldKind.externalLink) {
          issue = FormValidationKind.missingRequired;
        }
      } else if (!field._accepts(answer)) {
        issue = FormValidationKind.invalidAnswer;
      }
      if (issue != null) {
        issues.add(FormValidationIssue(key: field.key, kind: issue));
      }
    }
    return immutableList(issues);
  }
}

CanonicalValue _conditionValue(Object value) {
  if (value is! String && value is! num && value is! bool) {
    throw ArgumentError.value(value, 'value', 'Condition requires a scalar');
  }
  if (value is num && !value.isFinite) {
    throw ArgumentError.value(
      value,
      'value',
      'Condition requires finite numbers',
    );
  }
  return CanonicalValue(value);
}

bool _matches(FormAnswer? answer, CanonicalValue value) {
  if (!_isComparable(answer, value)) return false;
  if (answer is MultiSelectAnswer) {
    return value.value is String && answer.values.contains(value.value);
  }
  return CanonicalValue(answer!.toJson()) == value;
}

bool _isComparable(FormAnswer? answer, CanonicalValue value) {
  if (answer == null || answer is UnknownAnswer) return false;
  if (answer is MultiSelectAnswer) return value.value is String;
  final actual = answer.toJson();
  final expected = value.value;
  return (actual is String && expected is String) ||
      (actual is num && expected is num) ||
      (actual is bool && expected is bool);
}
