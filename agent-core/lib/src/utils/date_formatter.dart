import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class DateFormatter {
  static final _absoluteFormatter = DateFormat('MMM d, yyyy • h:mm a');

  static String format(DateTime dateTime) {
    return _absoluteFormatter.format(dateTime);
  }

  static String formatRelative(DateTime dateTime) {
    return timeago.format(dateTime);
  }
}
