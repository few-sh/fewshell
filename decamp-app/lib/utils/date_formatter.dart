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
}
