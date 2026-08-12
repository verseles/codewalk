import '../../core/i18n/l10n_bridge.dart';

class SessionTitleFormatter {
  SessionTitleFormatter._();

  static String displayTitle({
    required DateTime time,
    String? title,
    DateTime? now,
  }) {
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return fallbackTitle(time: time, now: now);
  }

  static String fallbackTitle({required DateTime time, DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final sessionDate = DateTime(time.year, time.month, time.day);
    final timeLabel =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final absoluteDateLabel = _absoluteDateLabel(time);
    final relativeDays = today.difference(sessionDate).inDays;

    if (relativeDays == 0) {
      return L10nBridge.current?.sessionTitleToday(
            absoluteDateLabel,
            timeLabel,
          ) ??
          'Today $timeLabel ($absoluteDateLabel)';
    }
    if (relativeDays == 1) {
      return L10nBridge.current?.sessionTitleYesterday(
            absoluteDateLabel,
            timeLabel,
          ) ??
          'Yesterday $timeLabel ($absoluteDateLabel)';
    }
    if (relativeDays > 1 && relativeDays < 7) {
      final weekday = _weekdayLabel(time.weekday);
      return L10nBridge.current?.sessionTitleWeekday(
            absoluteDateLabel,
            timeLabel,
            weekday,
          ) ??
          '$weekday $timeLabel ($absoluteDateLabel)';
    }
    return L10nBridge.current?.sessionTitleDateAndTime(
          absoluteDateLabel,
          timeLabel,
        ) ??
        '$absoluteDateLabel $timeLabel';
  }

  static String _weekdayLabel(int weekday) {
    return switch (weekday) {
      1 => L10nBridge.current?.sessionWeekdayMon ?? 'Mon',
      2 => L10nBridge.current?.sessionWeekdayTue ?? 'Tue',
      3 => L10nBridge.current?.sessionWeekdayWed ?? 'Wed',
      4 => L10nBridge.current?.sessionWeekdayThu ?? 'Thu',
      5 => L10nBridge.current?.sessionWeekdayFri ?? 'Fri',
      6 => L10nBridge.current?.sessionWeekdaySat ?? 'Sat',
      _ => L10nBridge.current?.sessionWeekdaySun ?? 'Sun',
    };
  }

  static String _absoluteDateLabel(DateTime time) {
    return '${time.month}/${time.day}/${time.year}';
  }
}
