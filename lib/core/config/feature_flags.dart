class FeatureFlags {
  const FeatureFlags._();

  /// Rollback guardrail for Feature 017 (refreshless realtime UX).
  ///
  /// Use `--dart-define=CODEWALK_REFRESHLESS_ENABLED=false` to quickly
  /// restore manual refresh controls without reverting code.
  static const bool refreshlessRealtime = bool.fromEnvironment(
    'CODEWALK_REFRESHLESS_ENABLED',
    defaultValue: true,
  );
}
