import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart' hide FormField;
import 'package:url_launcher/url_launcher.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_permission_reply.dart';
import 'session_live_controller.dart';

/// Form cards for interactive OpenCode forms resident in the live session.
/// Answers are preserved in controller draft state on failure and pruned
/// only when the interaction leaves resident state.
class SessionFormCards extends StatelessWidget {
  const SessionFormCards({
    super.key,
    required this.live,
    this.maxHeight = 300,
  });

  final SessionLiveController live;

  /// Height the viewer budgeted for these cards; derived from the body
  /// so cards and composer never overrun a short viewport.
  final double maxHeight;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: live,
    builder: (context, _) {
      final all = [
        for (final request
            in live.state?.interactions ?? const <InteractionRequest>[])
          if (request.kind.known == InteractionKind.form &&
              live.supportsReplies)
            request,
      ];
      final children = <SessionRef>[];
      for (final request in all) {
        final child = formChildOf(live.session, request);
        if (child != null && !children.contains(child)) children.add(child);
      }
      final requests = [
        for (final r in all)
          if (formChildOf(live.session, r) == null) r,
        for (final child in children)
          for (final r in all)
            if (formChildOf(live.session, r) == child) r,
      ];
      if (requests.isEmpty) return const SizedBox.shrink();
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final request in requests)
                SessionFormCard(
                  key: ValueKey(
                    'live-form-${formKeyOf(live.session, request)}',
                  ),
                  live: live,
                  request: request,
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// The child session that owns [request] when it is a sub-agent request shown
/// in [session]; null for the session's own requests.
SessionRef? formChildOf(SessionRef session, InteractionRequest request) {
  final owner = request.owner;
  return owner is SessionOwner && owner.session != session
      ? owner.session
      : null;
}

/// Widget key part unique across the session and its children.
String formKeyOf(SessionRef session, InteractionRequest request) {
  final child = formChildOf(session, request);
  return child == null
      ? request.id.value
      : '${child.nativeId}/${request.id.value}';
}

/// Localized copy for a form reply state.
String? formNoticeText(
  V2Localizations l10n,
  SessionPermissionReplyState state,
) => switch (state.phase) {
  SessionPermissionReplyPhase.ready || SessionPermissionReplyPhase.idle => null,
  SessionPermissionReplyPhase.requesting => l10n.liveFormSending,
  SessionPermissionReplyPhase.requested => l10n.liveFormSent,
  SessionPermissionReplyPhase.unconfirmed => l10n.liveFormUnconfirmed,
  SessionPermissionReplyPhase.refused =>
    switch (state.receipt?.error?.rawType) {
      'UnauthorizedError' => l10n.hostsAuthRequired,
      'RateLimited' => l10n.sessionsRateLimited,
      'NotFoundError' => l10n.livePermissionAnsweredElsewhere,
      _ => l10n.liveFormRefused,
    },
};

/// An interactive form card rendered according to its [FormSpec].
class SessionFormCard extends StatefulWidget {
  const SessionFormCard({
    super.key,
    required this.live,
    required this.request,
  });

  final SessionLiveController live;
  final InteractionRequest request;

  @override
  State<SessionFormCard> createState() => _SessionFormCardState();
}

class _SessionFormCardState extends State<SessionFormCard> {
  final _controllers = <String, TextEditingController>{};
  final _revealedSecrets = <String>{};
  final _errors = <String, String>{};
  bool _submitted = false;

  SessionRef? get _child => formChildOf(widget.live.session, widget.request);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String key, String initialText) {
    return _controllers.putIfAbsent(key, () {
      final controller = TextEditingController(text: initialText);
      return controller;
    });
  }

  FormAnswers _buildAnswers(
    FormSpec spec,
    Map<String, dynamic> draft,
  ) {
    final rawAnswers = <String, FormAnswer>{};
    for (final field in spec.fields) {
      final val = draft[field.key] ?? _defaultRaw(field);
      if (val != null) {
        final answer = _rawToAnswer(field, val);
        if (answer != null) {
          rawAnswers[field.key] = answer;
        }
      }
    }
    final all = FormAnswers(rawAnswers);
    // Active answers only: inactive fields must not have answers in the payload.
    final activeMap = <String, FormAnswer>{};
    for (final field in spec.fields) {
      if (field.isActive(all)) {
        final ans = all[field.key];
        if (ans != null) {
          activeMap[field.key] = ans;
        }
      }
    }
    return FormAnswers(activeMap);
  }

  Object? _defaultRaw(FormField field) {
    final def = field.defaultAnswer;
    if (def == null) return null;
    return switch (def) {
      StringAnswer(:final value) => value,
      NumberAnswer(:final value) => value,
      IntegerAnswer(:final value) => value,
      BooleanAnswer(:final value) => value,
      SingleSelectAnswer(:final value) => value,
      MultiSelectAnswer(:final values) => List<String>.from(values),
      CustomAnswer(:final value) => value.value,
      SecretAnswer(:final value) => value,
      _ => null,
    };
  }

  FormAnswer? _rawToAnswer(FormField field, Object raw) {
    final kind = field.kind.known;
    if (kind == null) return null;
    return switch (kind) {
      FormFieldKind.string =>
        raw is String ? StringAnswer(raw) : StringAnswer(raw.toString()),
      FormFieldKind.number => switch (raw) {
        final num n when n.isFinite => NumberAnswer(n),
        final String s => num.tryParse(s) != null && num.tryParse(s)!.isFinite
            ? NumberAnswer(num.tryParse(s)!)
            : null,
        _ => null,
      },
      FormFieldKind.integer => switch (raw) {
        final int i => IntegerAnswer(i),
        final num n when n.truncate() == n => IntegerAnswer(n.toInt()),
        final String s =>
          int.tryParse(s) != null ? IntegerAnswer(int.tryParse(s)!) : null,
        _ => null,
      },
      FormFieldKind.boolean => switch (raw) {
        final bool b => BooleanAnswer(b),
        final String s => BooleanAnswer(s.toLowerCase() == 'true'),
        _ => null,
      },
      FormFieldKind.singleSelect => raw is String
          ? SingleSelectAnswer(raw)
          : SingleSelectAnswer(raw.toString()),
      FormFieldKind.multiSelect => switch (raw) {
        final List<String> list => MultiSelectAnswer(list),
        final Iterable list => MultiSelectAnswer(list.map((e) => e.toString())),
        _ => null,
      },
      FormFieldKind.custom => switch (raw) {
        final CanonicalValue cv => CustomAnswer(cv),
        final String s => _tryParseJson(s),
        _ => CustomAnswer(CanonicalValue(raw)),
      },
      FormFieldKind.secret =>
        raw is String ? SecretAnswer(raw) : SecretAnswer(raw.toString()),
      FormFieldKind.externalLink => null,
    };
  }

  CustomAnswer _tryParseJson(String s) {
    try {
      final decoded = jsonDecode(s);
      return CustomAnswer(CanonicalValue(decoded));
    } catch (_) {
      return CustomAnswer(CanonicalValue(s));
    }
  }

  void _validateAll(
    V2Localizations l10n,
    FormSpec spec,
    FormAnswers answers,
    Map<String, dynamic> draft,
  ) {
    _errors.clear();
    for (final field in spec.fields) {
      if (!field.isActive(answers)) continue;
      final raw = draft[field.key];
      if (raw != null) {
        final s = raw.toString().trim();
        final kind = field.kind.known;
        if (kind == FormFieldKind.number) {
          if (s.isNotEmpty &&
              (num.tryParse(s) == null || !num.tryParse(s)!.isFinite)) {
            _errors[field.key] = l10n.liveFormInvalidNumber;
          }
        } else if (kind == FormFieldKind.integer) {
          if (s.isNotEmpty && int.tryParse(s) == null) {
            _errors[field.key] = l10n.liveFormInvalidInteger;
          }
        }
      }
    }
    final issues = spec.validate(answers);
    for (final issue in issues) {
      if (_errors.containsKey(issue.key)) continue;
      final msg = switch (issue.kind) {
        FormValidationKind.missingRequired => l10n.liveFormRequiredField,
        FormValidationKind.invalidAnswer => switch (spec.fields
            .firstWhere(
              (f) => f.key == issue.key,
              orElse: () => spec.fields.first,
            )
            .kind
            .known) {
          FormFieldKind.number => l10n.liveFormInvalidNumber,
          FormFieldKind.integer => l10n.liveFormInvalidInteger,
          _ => l10n.liveFormRefused,
        },
        _ => l10n.liveFormRefused,
      };
      _errors[issue.key] = msg;
    }
  }

  Future<void> _submit(
    V2Localizations l10n,
    FormSpec spec,
    Map<String, dynamic> draft,
  ) async {
    setState(() => _submitted = true);
    final answers = _buildAnswers(spec, draft);
    _validateAll(l10n, spec, answers, draft);
    if (_errors.isNotEmpty) {
      setState(() {});
      return;
    }
    await widget.live.replyToForm(
      request: widget.request,
      answers: answers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final request = widget.request;
    final spec = request.form;
    final l10n = context.v2L10n;
    final child = _child;
    final state = live.replyState(request.id, owner: child);
    final busy = state.busy;
    final enabled = live.canReplyForm(request) && !busy;
    final notice = formNoticeText(l10n, state);
    final draft = live.formDraft(request.id, owner: child);
    final scheme = Theme.of(context).colorScheme;

    // Build intermediate answers to evaluate dynamic conditional visibility
    final activeAnswers = spec != null
        ? _buildAnswers(spec, draft)
        : FormAnswers(const {});

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (child != null)
                  Chip(
                    padding: EdgeInsets.zero,
                    label: Text(
                      l10n.livePermissionChildBadge,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            if (notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  notice,
                  key: const ValueKey('live-form-notice'),
                  style: TextStyle(
                    color: state.phase == SessionPermissionReplyPhase.refused
                        ? scheme.error
                        : scheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (spec != null) ...[
              const SizedBox(height: 8),
              for (final field in spec.fields)
                if (field.isActive(activeAnswers) && !field.hidden)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildField(
                      context,
                      field,
                      draft,
                      enabled,
                      l10n,
                    ),
                  ),
            ],
            const SizedBox(height: 8),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  key: ValueKey(
                    'form-dismiss-${formKeyOf(live.session, request)}',
                  ),
                  onPressed: enabled
                      ? () => live.dismissForm(request: request)
                      : null,
                  child: Text(l10n.liveFormDismiss),
                ),
                FilledButton(
                  key: ValueKey(
                    'form-submit-${formKeyOf(live.session, request)}',
                  ),
                  onPressed: enabled && spec != null
                      ? () => _submit(l10n, spec, draft)
                      : null,
                  child: Text(l10n.liveFormSubmit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    FormField field,
    Map<String, dynamic> draft,
    bool enabled,
    V2Localizations l10n,
  ) {
    final kind = field.kind.known;
    final errorText = _submitted ? _errors[field.key] : null;
    final label = '${field.title ?? field.key}${field.required ? ' *' : ''}';

    switch (kind) {
      case FormFieldKind.string:
        if (field.options.isNotEmpty) {
          final currentVal = draft[field.key]?.toString() ??
              _defaultRaw(field)?.toString() ??
              '';
          final hasCustom = field.acceptsCustom;
          final isPredefined = field.options.any((o) => o.value == currentVal);
          return Column(
            key: ValueKey('form-field-${field.key}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              if (field.description != null)
                Text(
                  field.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final opt in field.options)
                    ChoiceChip(
                      key: ValueKey('form-option-${field.key}-${opt.value}'),
                      label: Text(opt.label),
                      selected: currentVal == opt.value,
                      onSelected: enabled
                          ? (selected) {
                              widget.live.setFormFieldDraft(
                                widget.request.id,
                                field.key,
                                selected ? opt.value : null,
                                owner: _child,
                              );
                            }
                          : null,
                    ),
                ],
              ),
              if (hasCustom) ...[
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey('form-field-${field.key}-custom'),
                  controller: _controllerFor(
                    '${field.key}_custom',
                    (!isPredefined && currentVal.isNotEmpty) ? currentVal : '',
                  ),
                  enabled: enabled,
                  decoration: InputDecoration(
                    labelText: l10n.liveFormCustomAnswer,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    widget.live.setFormFieldDraft(
                      widget.request.id,
                      field.key,
                      val.isEmpty ? null : val,
                      owner: _child,
                    );
                  },
                ),
              ],
              if (errorText != null) ...[
                const SizedBox(height: 4),
                Text(
                  errorText,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          );
        }
        final currentVal = draft[field.key]?.toString() ??
            _defaultRaw(field)?.toString() ??
            '';
        final controller = _controllerFor(field.key, currentVal);
        return TextFormField(
          key: ValueKey('form-field-${field.key}'),
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: label,
            helperText: field.description,
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
          onChanged: (val) {
            widget.live.setFormFieldDraft(
              widget.request.id,
              field.key,
              val.isEmpty ? null : val,
              owner: _child,
            );
          },
        );

      case FormFieldKind.custom:
        final currentVal = draft[field.key]?.toString() ??
            _defaultRaw(field)?.toString() ??
            '';
        final controller = _controllerFor(field.key, currentVal);
        return TextFormField(
          key: ValueKey('form-field-${field.key}'),
          controller: controller,
          enabled: enabled,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: label,
            helperText: field.description,
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
          onChanged: (val) {
            widget.live.setFormFieldDraft(
              widget.request.id,
              field.key,
              val.isEmpty ? null : val,
              owner: _child,
            );
          },
        );

      case FormFieldKind.secret:
        final currentVal = draft[field.key]?.toString() ??
            _defaultRaw(field)?.toString() ??
            '';
        final controller = _controllerFor(field.key, currentVal);
        final revealed = _revealedSecrets.contains(field.key);
        return TextFormField(
          key: ValueKey('form-field-${field.key}'),
          controller: controller,
          enabled: enabled,
          obscureText: !revealed,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: label,
            helperText: field.description,
            errorText: errorText,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              key: ValueKey('form-secret-toggle-${field.key}'),
              icon: Icon(revealed ? Icons.visibility_off : Icons.visibility),
              tooltip: l10n.liveFormSecretToggle,
              onPressed: () {
                setState(() {
                  if (revealed) {
                    _revealedSecrets.remove(field.key);
                  } else {
                    _revealedSecrets.add(field.key);
                  }
                });
              },
            ),
          ),
          onChanged: (val) {
            widget.live.setFormFieldDraft(
              widget.request.id,
              field.key,
              val.isEmpty ? null : val,
              owner: _child,
            );
          },
        );

      case FormFieldKind.number:
      case FormFieldKind.integer:
        final currentVal = draft[field.key]?.toString() ??
            _defaultRaw(field)?.toString() ??
            '';
        final controller = _controllerFor(field.key, currentVal);
        final isInt = kind == FormFieldKind.integer;
        return TextFormField(
          key: ValueKey('form-field-${field.key}'),
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.numberWithOptions(
            decimal: !isInt,
            signed: true,
          ),
          decoration: InputDecoration(
            labelText: label,
            helperText: field.description,
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
          onChanged: (val) {
            if (val.isEmpty) {
              widget.live.setFormFieldDraft(
                widget.request.id,
                field.key,
                null,
                owner: _child,
              );
              return;
            }
            final parsed = isInt ? int.tryParse(val) : num.tryParse(val);
            widget.live.setFormFieldDraft(
              widget.request.id,
              field.key,
              parsed ?? val,
              owner: _child,
            );
          },
        );

      case FormFieldKind.boolean:
        final currentVal = draft[field.key] is bool
            ? draft[field.key] as bool
            : (_defaultRaw(field) as bool? ?? false);
        return SwitchListTile(
          key: ValueKey('form-field-${field.key}'),
          title: Text(label),
          subtitle: field.description != null ? Text(field.description!) : null,
          value: currentVal,
          onChanged: enabled
              ? (val) {
                  widget.live.setFormFieldDraft(
                    widget.request.id,
                    field.key,
                    val,
                    owner: _child,
                  );
                }
              : null,
        );

      case FormFieldKind.singleSelect:
        final currentVal = draft[field.key]?.toString() ??
            _defaultRaw(field)?.toString();
        final hasCustom = field.acceptsCustom;
        final isPredefined = field.options.any((o) => o.value == currentVal);
        final dropdown = DropdownButtonFormField<String>(
          key: ValueKey('form-field-${field.key}'),
          initialValue: isPredefined ? currentVal : null,
          hint: Text(l10n.liveFormSelectOption),
          decoration: InputDecoration(
            labelText: label,
            helperText: field.description,
            errorText: hasCustom ? null : errorText,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final opt in field.options)
              DropdownMenuItem(
                value: opt.value,
                child: Text(opt.label),
              ),
          ],
          onChanged: enabled
              ? (val) {
                  widget.live.setFormFieldDraft(
                    widget.request.id,
                    field.key,
                    val,
                    owner: _child,
                  );
                }
              : null,
        );
        if (!hasCustom) return dropdown;
        return Column(
          key: ValueKey('form-field-container-${field.key}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            dropdown,
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('form-field-${field.key}-custom'),
              controller: _controllerFor(
                '${field.key}_custom',
                (!isPredefined && currentVal != null && currentVal.isNotEmpty)
                    ? currentVal
                    : '',
              ),
              enabled: enabled,
              decoration: InputDecoration(
                labelText: l10n.liveFormCustomAnswer,
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) {
                widget.live.setFormFieldDraft(
                  widget.request.id,
                  field.key,
                  val.isEmpty ? null : val,
                  owner: _child,
                );
              },
            ),
            if (errorText != null) ...[
              const SizedBox(height: 4),
              Text(
                errorText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        );

      case FormFieldKind.multiSelect:
        final currentList = switch (draft[field.key]) {
          final List<String> list => list,
          final Iterable it => it.map((e) => e.toString()).toList(),
          _ => switch (_defaultRaw(field)) {
              final List<String> defs => defs,
              final Iterable it => it.map((e) => e.toString()).toList(),
              _ => const <String>[],
            },
        };
        return Column(
          key: ValueKey('form-field-${field.key}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            if (field.description != null)
              Text(
                field.description!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final opt in field.options)
                  FilterChip(
                    key: ValueKey('form-option-${field.key}-${opt.value}'),
                    label: Text(opt.label),
                    selected: currentList.contains(opt.value),
                    onSelected: enabled
                        ? (selected) {
                            final updated = List<String>.from(currentList);
                            if (selected) {
                              updated.add(opt.value);
                            } else {
                              updated.remove(opt.value);
                            }
                            widget.live.setFormFieldDraft(
                              widget.request.id,
                              field.key,
                              updated,
                              owner: _child,
                            );
                          }
                        : null,
                  ),
              ],
            ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  errorText,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );

      case FormFieldKind.externalLink:
        final url = field.externalUrl;
        return OutlinedButton.icon(
          key: ValueKey('form-field-${field.key}'),
          icon: const Icon(Icons.open_in_new),
          label: Text(field.title ?? l10n.liveFormOpenLink),
          onPressed: url != null
              ? () async {
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri);
                  }
                }
              : null,
        );

      case null:
        return const SizedBox.shrink();
    }
  }
}
