enum QuotaPaceStatus { onTrack, slightlyFast, tooFast, exhausted }

double? _readDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

String? _readString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

class UsageWindow {
  const UsageWindow({
    required this.usedPercent,
    required this.remainingPercent,
    required this.windowSeconds,
    required this.resetAfterSeconds,
    required this.resetAt,
    required this.resetAtFormatted,
    required this.resetAfterFormatted,
    required this.valueLabel,
  });

  final double? usedPercent;
  final double? remainingPercent;
  final int? windowSeconds;
  final int? resetAfterSeconds;
  final int? resetAt;
  final String? resetAtFormatted;
  final String? resetAfterFormatted;
  final String? valueLabel;

  factory UsageWindow.fromJson(Map<String, dynamic> json) {
    return UsageWindow(
      usedPercent: _readDouble(json['usedPercent']),
      remainingPercent: _readDouble(json['remainingPercent']),
      windowSeconds: _readInt(json['windowSeconds']),
      resetAfterSeconds: _readInt(json['resetAfterSeconds']),
      resetAt: _readInt(json['resetAt']),
      resetAtFormatted: _readString(json['resetAtFormatted']),
      resetAfterFormatted: _readString(json['resetAfterFormatted']),
      valueLabel: _readString(json['valueLabel']),
    );
  }

  bool get hasVisibleData =>
      usedPercent != null ||
      (valueLabel != null && valueLabel!.trim().toLowerCase() != 'configured');
}

class QuotaProviderUsage {
  const QuotaProviderUsage({required this.windows, required this.models});

  final Map<String, UsageWindow> windows;
  final Map<String, QuotaProviderUsage> models;

  factory QuotaProviderUsage.fromJson(Map<String, dynamic> json) {
    final parsedWindows = <String, UsageWindow>{};
    final rawWindows = json['windows'];
    if (rawWindows is Map) {
      for (final entry in rawWindows.entries) {
        if (entry.key is! String || entry.value is! Map) {
          continue;
        }
        parsedWindows[entry.key as String] = UsageWindow.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }

    final parsedModels = <String, QuotaProviderUsage>{};
    final rawModels = json['models'];
    if (rawModels is Map) {
      for (final entry in rawModels.entries) {
        if (entry.key is! String || entry.value is! Map) {
          continue;
        }
        parsedModels[entry.key as String] = QuotaProviderUsage.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }

    return QuotaProviderUsage(windows: parsedWindows, models: parsedModels);
  }

  bool get hasVisibleData {
    if (windows.values.any((window) => window.hasVisibleData)) {
      return true;
    }
    return models.values.any((usage) => usage.hasVisibleData);
  }
}

class QuotaProviderResult {
  const QuotaProviderResult({
    required this.providerId,
    required this.providerName,
    required this.ok,
    required this.configured,
    required this.usage,
    required this.error,
    required this.fetchedAt,
    this.errorCode,
  });

  final String providerId;
  final String providerName;
  final bool ok;
  final bool configured;
  final QuotaProviderUsage? usage;
  final String? error;
  final int fetchedAt;
  final String? errorCode;

  factory QuotaProviderResult.fromJson(Map<String, dynamic> json) {
    final usageRaw = json['usage'];
    return QuotaProviderResult(
      providerId: _readString(json['providerId']) ?? 'unknown',
      providerName: _readString(json['providerName']) ?? 'Unknown',
      ok: json['ok'] == true,
      configured: json['configured'] == true,
      usage: usageRaw is Map<String, dynamic>
          ? QuotaProviderUsage.fromJson(usageRaw)
          : usageRaw is Map
          ? QuotaProviderUsage.fromJson(Map<String, dynamic>.from(usageRaw))
          : null,
      error: _readString(json['error']),
      fetchedAt:
          _readInt(json['fetchedAt']) ?? DateTime.now().millisecondsSinceEpoch,
      errorCode: _readString(json['errorCode']),
    );
  }

  bool get hasVisibleData =>
      ok && configured && (usage?.hasVisibleData ?? false);
}

class PaceInfo {
  const PaceInfo({
    required this.elapsedRatio,
    required this.usageRatio,
    required this.predictedFinalPercent,
    required this.remainingSeconds,
    required this.isExhausted,
    required this.elapsedSeconds,
    required this.totalSeconds,
    required this.status,
    required this.paceRateText,
    required this.predictText,
    required this.dailyAllocationPercent,
  });

  final double elapsedRatio;
  final double usageRatio;
  final double predictedFinalPercent;
  final double remainingSeconds;
  final bool isExhausted;
  final double elapsedSeconds;
  final double totalSeconds;
  final QuotaPaceStatus status;
  final String paceRateText;
  final String predictText;
  final double? dailyAllocationPercent;
}

class QuotaEntry {
  const QuotaEntry({
    required this.providerId,
    required this.providerName,
    required this.label,
    required this.usedPercent,
    required this.remainingPercent,
    required this.windowSeconds,
    required this.resetAfterSeconds,
    required this.resetAt,
    required this.valueLabel,
    required this.paceInfo,
  });

  final String providerId;
  final String providerName;
  final String label;
  final double? usedPercent;
  final double? remainingPercent;
  final int? windowSeconds;
  final int? resetAfterSeconds;
  final int? resetAt;
  final String? valueLabel;
  final PaceInfo? paceInfo;

  static final RegExp _zeroRemainingCurrencyPattern = RegExp(
    r'^\$?0(?:\.0+)?\s+remaining$',
    caseSensitive: false,
  );

  bool get hasZeroRemainingValueLabel {
    final value = valueLabel?.trim();
    if (value == null || value.isEmpty) {
      return false;
    }
    return _zeroRemainingCurrencyPattern.hasMatch(value);
  }

  double? get effectiveUsedPercent {
    if (usedPercent != null) {
      return usedPercent;
    }
    if (hasZeroRemainingValueLabel) {
      return 100;
    }
    return null;
  }

  double get severityScore {
    final pace = paceInfo?.predictedFinalPercent ?? 0;
    final usage = effectiveUsedPercent ?? 0;
    return pace > usage ? pace : usage;
  }
}

class QuotaProviderGroup {
  const QuotaProviderGroup({
    required this.providerId,
    required this.providerName,
    required this.entries,
  });

  final String providerId;
  final String providerName;
  final List<QuotaEntry> entries;

  bool get canExpand => entries.length > 1;

  QuotaEntry get leadingEntry => entries.first;

  QuotaEntry get criticalEntry {
    return entries.reduce((current, next) {
      if (next.severityScore > current.severityScore) {
        return next;
      }
      if (next.severityScore < current.severityScore) {
        return current;
      }
      return (next.usedPercent ?? 0) > (current.usedPercent ?? 0)
          ? next
          : current;
    });
  }
}
