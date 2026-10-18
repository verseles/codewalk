import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

/// CodeWalk's permission policy for authored v2 (ADR-059). Only [allowAll]
/// answers a request by itself; every other value keeps the manual cards.
/// Unrestricted belongs to V2-047B and is never emulated here.
enum PermissionMode { ask, allowAll }

/// Where the effective value comes from; never a harness identity.
enum PermissionModeSource { session, global, defaultOn }

/// The acknowledged effective policy for one session. An unknown, unreadable or
/// unsupported policy is never emulated as a mode: [mode] stays null and
/// [reason] says why, so nothing automatic happens.
final class SessionPermissionModeState {
  const SessionPermissionModeState({this.mode, this.source}) : reason = null;
  const SessionPermissionModeState.unavailable(this.reason)
    : mode = null,
      source = null;

  final PermissionMode? mode;
  final PermissionModeSource? source;
  final String? reason;

  /// The single predicate the automatic responder may consult.
  bool get answering => mode == PermissionMode.allowAll;
}

/// The read-only policy the live slot consults. The settings store implements
/// it for the app graph; a fake implements it in tests.
abstract class PermissionModePolicy extends ChangeNotifier {
  /// False until the persisted policy has been read. Nothing automatic happens
  /// before that: a cold failure grants no standing approval authority.
  bool get loaded;

  /// The acknowledged policy for [session]; overrides win over the global
  /// default, and unknown or unreadable values stay explicit.
  SessionPermissionModeState effectiveFor(SessionRef session);
}

/// The acknowledged policy plus the writes the live surface may request.
/// The automatic responder keeps reading [PermissionModePolicy] only, so a
/// wider write port never widens what the responder consults.
abstract class EditablePermissionModePolicy extends PermissionModePolicy {
  bool get hasPersistenceError;

  /// True when stored overrides cannot be read; writes are refused so the
  /// unread blob is preserved.
  bool get overridesUnreadable;
  Future<bool> setSessionMode(SessionRef session, PermissionMode mode);
  Future<bool> clearSessionMode(SessionRef session);
  Future<void> clearPersistenceError();
}
