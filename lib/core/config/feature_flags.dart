class FeatureFlags {
  const FeatureFlags._();

  /// Rollback guardrail for the cellular data saver flow.
  ///
  /// Use `--dart-define=CODEWALK_CELLULAR_DATA_SAVER=false` to quickly restore
  /// the previous always-on mobile networking behavior without reverting code.
  static const bool cellularDataSaver = bool.fromEnvironment(
    'CODEWALK_CELLULAR_DATA_SAVER',
    defaultValue: true,
  );

  /// Rollback guardrail for Feature 017 (refreshless realtime UX).
  ///
  /// Use `--dart-define=CODEWALK_REFRESHLESS_ENABLED=false` to quickly
  /// restore manual refresh controls without reverting code.
  static const bool refreshlessRealtime = bool.fromEnvironment(
    'CODEWALK_REFRESHLESS_ENABLED',
    defaultValue: true,
  );

  /// Use session-idle-aware completion reconciliation for prompt_async sends.
  ///
  /// When enabled, datasource send completion waits for session status to
  /// become idle and then resolves the final assistant message from server
  /// history, avoiding stale message-id selection races.
  static const bool promptAsyncIdleCompletion = bool.fromEnvironment(
    'CODEWALK_PROMPT_ASYNC_IDLE_COMPLETION',
    defaultValue: true,
  );
}
