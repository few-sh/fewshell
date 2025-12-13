import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class DateFormatter {
  static String formatAbsoluteDateTime(DateTime dateTime) {
    final formatter = DateFormat('MMM d, yyyy • h:mm a');
    return formatter.format(dateTime);
  }

  static String formatRelativeTime(DateTime dateTime) {
    return timeago.format(dateTime);
  }

  static String formatAbsoluteDate(DateTime dateTime) {
    final formatter = DateFormat('MMM d, yyyy');
    return formatter.format(dateTime);
  }

  static String formatSessionDateRange(DateTime start, DateTime end) {
    final timeDifference = end.difference(start);
    final showDateRange = timeDifference.inMinutes >= 5;
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;

    if (!showDateRange) {
      return formatAbsoluteDateTime(end);
    } else if (sameDay) {
      final startStr = DateFormat('h:mm a').format(start);
      final endStr = DateFormat('h:mm a').format(end);
      final dateStr = DateFormat('MMM d, yyyy').format(start);
      return '$dateStr • $startStr - $endStr';
    } else {
      final startStr = formatAbsoluteDateTime(start);
      final endStr = formatAbsoluteDateTime(end);
      return '$startStr - $endStr';
    }
  }
}
