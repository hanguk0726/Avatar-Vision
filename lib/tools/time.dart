import 'package:intl/intl.dart';

String getFormattedTimestamp({int? timestamp, String? format}) {
  timestamp ??= DateTime.now().millisecondsSinceEpoch;

  String formattedOffsetTime = DateFormat(format ?? 'yyyy-MM-dd HH:mm:ss')
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