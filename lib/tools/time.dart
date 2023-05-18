import 'package:intl/intl.dart';

String getFormattedTimestamp({int? timestamp, String? format}) {
  timestamp ??= DateTime.now().millisecondsSinceEpoch;

  String formattedOffsetTime = DateFormat(format ?? 'MM-dd-yyyy HH:mm:ss')
      .format(DateTime.fromMillisecondsSinceEpoch(timestamp));

  return formattedOffsetTime;
}

String formatDuration(Duration duration) {
  int seconds = duration.inSeconds % 60;
  int totalMinutes = duration.inMinutes;
  int minutes = totalMinutes % 60;
  int hours = totalMinutes ~/ 60;

  String formattedDuration;

  if (hours > 0) {
    minutes += hours * 60;
    formattedDuration = '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  } else {
    formattedDuration = '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return formattedDuration;
}

String formatInt(int number) {
  if (number < 100) {
    return number.toString().padLeft(2, '0');
  } else {
    return number.toString();
  }
}

String timestampToMonthDay(int timestamp, bool monthAsLetter) {
  DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
  // 15 OCT or 15/10
  DateFormat monthFormat = monthAsLetter ? DateFormat.MMM() : DateFormat.M();
  String month = monthFormat.format(dateTime).toUpperCase();
  String day = DateFormat.d().format(dateTime);
  return monthAsLetter ? '$day $month' : '$month/$day';
}
