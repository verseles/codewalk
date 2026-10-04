import 'dart:convert';

import 'forms.dart';
import 'identity.dart';
import 'values.dart';

enum InteractionKind {
  permission,
  question,
  form,
  planApproval,
  installationConsent,
  projectTrust,
}

enum ApprovalScope { once, session, persistentProject, persistentRule }

enum ResolutionScope { request, session, project }

final class ApprovalChoice {
  ApprovalChoice({
    required this.id,
    required this.label,
    required this.allows,
    required this.scope,
    required this.resolutionScope,
    this.acceptsNote = false,
    this.scopePreview,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Must be nonempty');
  }

  final String id;
  final String label;
  final bool allows;
  final OpenValue<ApprovalScope> scope;
  final bool acceptsNote;
  final CanonicalValue? scopePreview;
  final OpenValue<ResolutionScope> resolutionScope;

  bool get isKnown => scope.known != null && resolutionScope.known != null;
}

final class InteractionRequest {
  InteractionRequest({
    required this.id,
    required this.owner,
    required this.kind,
    required this.title,
    Iterable<ApprovalChoice> choices = const [],
    this.form,
    this.subject,
    this.requiresInput = false,
    this.autoApprovable = false,
  }) : choices = immutableList(choices) {
    final seen = <String>{};
    for (final choice in this.choices) {
      if (!seen.add(choice.id)) {
        throw ArgumentError.value(choice.id, 'choices', 'Duplicate choice id');
      }
    }
  }

  final InteractionId id;
  final DomainOwner owner;
  final OpenValue<InteractionKind> kind;
  final String title;
  final List<ApprovalChoice> choices;
  final FormSpec? form;
  final CanonicalValue? subject;
  final bool requiresInput;
  final bool autoApprovable;

  String get identityKey => _identityKey(id, owner);

  /// Eligibility only. This does not reply, infer Host authority, or set a mode.
  ApprovalChoice? get automaticChoice {
    if (!autoApprovable ||
        owner is! SessionOwner ||
        !owner.isKnown ||
        kind.known != InteractionKind.permission ||
        requiresInput ||
        form != null ||
        choices.isEmpty ||
        choices.any((choice) => !choice.isKnown)) {
      return null;
    }
    for (final choice in choices) {
      if (choice.allows &&
          choice.scope.known == ApprovalScope.once &&
          choice.resolutionScope.known == ResolutionScope.request) {
        return choice;
      }
    }
    return null;
  }

  /// Denies unknown owner, kind or choice scope before any port mutation.
  List<InteractionResponseIssue> validateResponse(
    InteractionResponse response,
  ) {
    if (!owner.isKnown) return const [InteractionResponseIssue.unknownOwner];
    if (kind.known == null) return const [InteractionResponseIssue.unknownKind];
    if (choices.any((choice) => !choice.isKnown)) {
      return const [InteractionResponseIssue.unknownChoiceScope];
    }
    if (response is ApprovalResponse) {
      if (form != null ||
          kind.known == InteractionKind.form ||
          kind.known == InteractionKind.question) {
        return const [InteractionResponseIssue.wrongResponseKind];
      }
      ApprovalChoice? offered;
      for (final choice in choices) {
        if (choice.id == response.choiceId) offered = choice;
      }
      if (offered == null) {
        return const [InteractionResponseIssue.choiceNotOffered];
      }
      if (response.note != null && !offered.acceptsNote) {
        return const [InteractionResponseIssue.noteNotAccepted];
      }
      return const [];
    }
    if (response is FormResponse) {
      if (form == null) {
        return const [InteractionResponseIssue.wrongResponseKind];
      }
      return form!.validate(response.answers).isEmpty
          ? const []
          : const [InteractionResponseIssue.invalidFormAnswers];
    }
    return const [InteractionResponseIssue.wrongResponseKind];
  }
}

sealed class InteractionResponse {
  const InteractionResponse();
}

final class ApprovalResponse extends InteractionResponse {
  ApprovalResponse(this.choiceId, {this.note}) {
    if (choiceId.isEmpty) {
      throw ArgumentError.value(choiceId, 'choiceId', 'Must be nonempty');
    }
  }
  final String choiceId;
  final String? note;
}

final class FormResponse extends InteractionResponse {
  const FormResponse(this.answers);
  final FormAnswers answers;
}

enum InteractionResponseIssue {
  unknownOwner,
  unknownKind,
  unknownChoiceScope,
  wrongResponseKind,
  choiceNotOffered,
  noteNotAccepted,
  invalidFormAnswers,
}

enum InteractionResolutionKind { self, elsewhere, policy, expired, cancelled }

final class InteractionResolution {
  const InteractionResolution({
    required this.id,
    required this.owner,
    required this.kind,
    this.response,
    this.resolvedAt,
    this.source,
  });

  final InteractionId id;
  final DomainOwner owner;
  final OpenValue<InteractionResolutionKind> kind;
  final InteractionResponse? response;
  final DateTime? resolvedAt;
  final CanonicalValue? source;

  String get identityKey => _identityKey(id, owner);
}

String _identityKey(InteractionId id, DomainOwner owner) =>
    jsonEncode(['interaction', 1, owner.scopeKey, id.value]);
