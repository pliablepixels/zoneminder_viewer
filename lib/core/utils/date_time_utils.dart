import 'package:intl/intl.dart';

/// A utility class for handling date and time operations
class DateTimeUtils {
  /// Common date formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String timeFormat = 'HH:mm:ss';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String apiDateTimeFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'";
  static const String displayDateFormat = 'MMM d, yyyy';
  static const String displayTimeFormat = 'h:mm a';
  static const String displayDateTimeFormat = 'MMM d, yyyy h:mm a';

  /// Parses a date string in the API format to a DateTime object
  static DateTime? parseApiDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    
    try {
      // Try parsing with timezone first
      if (dateString.endsWith('Z')) {
        return DateTime.parse(dateString).toLocal();
      }
      
      // Try parsing without timezone
      return DateFormat(apiDateTimeFormat).parse(dateString, true).toLocal();
    } catch (e) {
      // Try parsing with standard format if API format fails
      try {
        return DateTime.parse(dateString).toLocal();
      } catch (_) {
        return null;
      }
    }
  }

  /// Formats a DateTime object to a display string
  static String formatDisplayDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat(displayDateFormat).format(date);
  }

  /// Formats a DateTime object to a display time string
  static String formatDisplayTime(DateTime? date) {
    if (date == null) return '';
    return DateFormat(displayTimeFormat).format(date);
  }

  /// Formats a DateTime object to a display date and time string
  static String formatDisplayDateTime(DateTime? date) {
    if (date == null) return '';
    return DateFormat(displayDateTimeFormat).format(date);
  }

  /// Formats a DateTime object to an API date string
  static String formatApiDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat(apiDateTimeFormat).format(date.toUtc());
  }

  /// Gets the current date and time as a string in the API format
  static String getCurrentApiDateTime() {
    return formatApiDate(DateTime.now());
  }

  /// Calculates the time difference between two dates in a human-readable format
  static String timeAgo(DateTime date, {bool numericDates = true}) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return numericDates ? '$years year${years > 1 ? 's' : ''} ago' : 'Last year';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return numericDates ? '$months month${months > 1 ? 's' : ''} ago' : 'Last month';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return numericDates ? '$weeks week${weeks > 1 ? 's' : ''} ago' : 'Last week';
    } else if (difference.inDays > 0) {
      return numericDates 
          ? '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago' 
          : 'Yesterday';
    } else if (difference.inHours > 0) {
      return numericDates 
          ? '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago' 
          : 'Today';
    } else if (difference.inMinutes > 0) {
      return numericDates 
          ? '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago' 
          : 'Just now';
    } else {
      return 'Just now';
    }
  }

  /// Checks if two dates are the same day
  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Gets the start of the day for a given date
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Gets the end of the day for a given date
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);
  }

  /// Gets a list of dates in a range
  static List<DateTime> getDaysInRange(DateTime startDate, DateTime endDate) {
    final days = <DateTime>[];
    var currentDate = startDate;
    
    while (currentDate.isBefore(endDate) || isSameDay(currentDate, endDate)) {
      days.add(currentDate);
      currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day + 1);
    }
    
    return days;
  }
  
  /// Formats a duration in a human-readable format
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    final parts = <String>[];
    
    if (hours > 0) {
      parts.add('${hours}h');
    }
    
    if (minutes > 0 || hours > 0) {
      parts.add('${minutes}m');
    }
    
    parts.add('${seconds}s');
    
    return parts.join(' ');
  }
}
