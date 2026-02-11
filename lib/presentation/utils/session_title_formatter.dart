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
      return 'Today $timeLabel ($absoluteDateLabel)';
    }
    if (relativeDays == 1) {
      return 'Yesterday $timeLabel ($absoluteDateLabel)';
    }
    if (relativeDays > 1 && relativeDays < 7) {
      final weekdays = <String>[
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];
      final weekday = weekdays[time.weekday - 1];
      return '$weekday $timeLabel ($absoluteDateLabel)';
    }
    return '$absoluteDateLabel $timeLabel';
  }

  static String _absoluteDateLabel(DateTime time) {
    return '${time.month}/${time.day}/${time.year}';
  }
}
