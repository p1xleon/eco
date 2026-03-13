import 'package:intl/intl.dart';

class DateFormatter {
  static String monthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  static String dayLabel(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return "Today";
    if (target == yesterday) return "Yesterday";

    return DateFormat('MMM d').format(date);
  }

  static String fullDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}
