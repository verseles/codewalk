import 'package:http_parser/http_parser.dart';

final class RetryAfterHint {
  const RetryAfterHint({this.at, this.deferred = false});
  final DateTime? at;
  final bool deferred;

  /// No automatic retry. Delays outside this presentation budget stay deferred,
  /// rather than being clamped down and causing a request earlier than advised.
  static RetryAfterHint parse(String? input, DateTime now) {
    if (input == null) return const RetryAfterHint();
    var value = input.trim();
    if (RegExp(r'^\d+$').hasMatch(value)) {
      value = value.replaceFirst(RegExp(r'^0+'), '');
      if (value.isEmpty) value = '0';
      if (value.length > 5) return const RetryAfterHint(deferred: true);
      final seconds = int.tryParse(value);
      if (seconds == null || seconds > 86400) {
        return const RetryAfterHint(deferred: true);
      }
      return RetryAfterHint(at: now.toUtc().add(Duration(seconds: seconds)));
    }
    if (value.length > 256) return const RetryAfterHint();
    try {
      final obsolete = RegExp(
        r'^[A-Za-z]+, \d{2}-([A-Za-z]{3})-(\d{2}) \d{2}:\d{2}:\d{2} GMT$',
      ).firstMatch(value);
      DateTime date;
      if (obsolete != null) {
        // Portable parser uses a fixed 1900 century; RFC9110 uses a 50-year pivot.
        final year = int.parse(obsolete.group(2)!);
        var fullYear = now.year ~/ 100 * 100 + year;
        if (fullYear > now.year + 50) fullYear -= 100;
        final old = parseHttpDate(value);
        date = DateTime.utc(
          fullYear,
          old.month,
          old.day,
          old.hour,
          old.minute,
          old.second,
        );
      } else {
        date = parseHttpDate(value);
      }
      final delay = date.difference(now.toUtc());
      if (delay > const Duration(days: 1)) {
        return const RetryAfterHint(deferred: true);
      }
      return RetryAfterHint(at: delay.isNegative ? now.toUtc() : date.toUtc());
    } on FormatException {
      return const RetryAfterHint();
    }
  }
}
