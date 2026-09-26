import '../../domain/entities/quota.dart';

int? clampPercent(double? value) {
  if (value == null || value.isNaN) {
    return null;
  }
  return value.clamp(0, 100).round();
}

String formatPercent(double? value) {
  if (value == null || value.isNaN) {
    return '-';
  }
  return '${value.round()}%';
}

String resolveUsageTone(double? percent) {
  if (percent == null) {
    return 'safe';
  }
  if (percent >= 80) {
    return 'critical';
  }
  if (percent >= 50) {
    return 'warn';
  }
  return 'safe';
}

String formatWindowLabel(String label) {
  switch (label) {
    case '5h':
      return '5-Hour';
    case '7d':
      return '7-Day Limit';
    case '7d-sonnet':
      return '7-Day Sonnet Limit';
    case '7d-opus':
      return '7-Day Opus Limit';
    case 'weekly':
      return 'Weekly Limit';
    case 'rolling':
      return 'Rolling Usage';
    case 'daily':
      return 'Daily';
    case 'monthly':
      return 'Monthly Limit';
    case 'credits':
      return 'Credits';
    case 'session':
      return 'Session';
    case 'premium':
      return 'Premium Interactions';
    case 'chat':
      return 'Chat Requests';
    case 'completions':
      return 'Completions';
    case 'premium_interactions':
      return 'Premium interactions';
    default:
      return label;
  }
}

String formatCodexWindowLabel(int? seconds) {
  if (seconds == null || seconds <= 0) return 'Usage Limit';
  if (seconds == 18000) return '5-Hour';
  if (seconds == 604800) return 'Weekly Limit';
  if (seconds % 86400 == 0) return '${seconds ~/ 86400}-Day Limit';
  if (seconds % 3600 == 0) return '${seconds ~/ 3600}-Hour';
  if (seconds % 60 == 0) return '${seconds ~/ 60}-Minute Limit';
  return '$seconds-Second Limit';
}

int? inferWindowSeconds(String label) {
  final normalized = label.toLowerCase().trim();
  if (normalized == 'rolling') return 5 * 3600;
  if (normalized == '5h') return 5 * 3600;
  if (normalized == '7d' ||
      normalized == 'weekly' ||
      normalized == '7d-sonnet' ||
      normalized == '7d-opus') {
    return 7 * 86400;
  }
  if (normalized == 'monthly') return 30 * 86400;
  if (normalized == '24h' || normalized == 'daily') return 86400;
  if (normalized == '1h') return 3600;
  final hourMatch = RegExp(r'^(\d+)h$').firstMatch(normalized);
  if (hourMatch != null) {
    return int.parse(hourMatch.group(1)!) * 3600;
  }
  final dayMatch = RegExp(r'^(\d+)d$').firstMatch(normalized);
  if (dayMatch != null) {
    return int.parse(dayMatch.group(1)!) * 86400;
  }
  return null;
}

PaceInfo? calculatePace({
  required double? usedPercent,
  required int? resetAt,
  required int? windowSeconds,
  String? windowLabel,
  DateTime? now,
}) {
  var effectiveWindowSeconds = windowSeconds;
  if (effectiveWindowSeconds == null && windowLabel != null) {
    effectiveWindowSeconds = inferWindowSeconds(windowLabel);
  }
  if (usedPercent == null ||
      resetAt == null ||
      effectiveWindowSeconds == null) {
    return null;
  }
  if (effectiveWindowSeconds <= 0) {
    return null;
  }

  final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final remainingSeconds = ((resetAt - nowMs) / 1000)
      .clamp(0, double.infinity)
      .toDouble();
  final totalSeconds = effectiveWindowSeconds.toDouble();
  final elapsedSeconds = (totalSeconds - remainingSeconds)
      .clamp(0, totalSeconds)
      .toDouble();
  final elapsedRatio = (elapsedSeconds / totalSeconds).clamp(0, 1).toDouble();
  final usageRatio = usedPercent / 100;
  final isExhausted = usedPercent >= 100 && remainingSeconds > 0;

  double predictedFinalPercent;
  if (elapsedRatio > 0.01) {
    predictedFinalPercent = ((usageRatio / elapsedRatio) * 100).clamp(0, 999);
  } else {
    predictedFinalPercent = usedPercent;
  }

  final QuotaPaceStatus status;
  if (isExhausted) {
    status = QuotaPaceStatus.exhausted;
  } else if (usageRatio <= elapsedRatio) {
    status = QuotaPaceStatus.onTrack;
  } else if (predictedFinalPercent <= 130) {
    status = QuotaPaceStatus.slightlyFast;
  } else {
    status = QuotaPaceStatus.tooFast;
  }

  final usePerDay = totalSeconds >= 5 * 24 * 3600;
  final unitSeconds = usePerDay ? 86400 : 3600;
  final unitSuffix = usePerDay ? 'd' : 'h';
  final elapsedUnits = (elapsedSeconds / unitSeconds).clamp(
    0.01,
    double.infinity,
  );
  final pacePercentPerUnit = (usedPercent / elapsedUnits).clamp(0, 999.9);
  final paceRateText = '${pacePercentPerUnit.toStringAsFixed(1)}%/$unitSuffix';

  final predictText = predictedFinalPercent > 100
      ? '+${predictedFinalPercent.round()}%'
      : '${predictedFinalPercent.round()}%';

  double? dailyAllocationPercent;
  final windowDays = totalSeconds / 86400;
  if (windowDays >= 7) {
    dailyAllocationPercent = 100 / windowDays;
  }

  return PaceInfo(
    elapsedRatio: elapsedRatio,
    usageRatio: usageRatio,
    predictedFinalPercent: predictedFinalPercent,
    remainingSeconds: remainingSeconds,
    isExhausted: isExhausted,
    elapsedSeconds: elapsedSeconds,
    totalSeconds: totalSeconds,
    status: status,
    paceRateText: paceRateText,
    predictText: predictText,
    dailyAllocationPercent: dailyAllocationPercent,
  );
}

String formatRemainingTime(double seconds) {
  final totalSeconds = seconds.floor().clamp(0, 1 << 31).toDouble();
  final totalMinutes = (totalSeconds ~/ 60);
  final totalHours = (totalMinutes ~/ 60);
  final days = (totalHours ~/ 24);
  final hours = (totalHours % 24);
  final minutes = (totalMinutes % 60);

  if (days > 0) {
    return '${days}d ${hours}h';
  }
  if (totalHours > 0) {
    return '${totalHours}h';
  }
  if (totalMinutes == 0) {
    return '<1m';
  }
  return '${minutes}m';
}

double calculateExpectedUsagePercent(double elapsedRatio) {
  return (elapsedRatio * 100).clamp(0, 100);
}
