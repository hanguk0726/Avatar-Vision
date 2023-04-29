import 'package:intl/intl.dart';

String getFormattedTimestamp(int timestamp, {int? timezoneOffsetInSeconds}) {
  timezoneOffsetInSeconds ??= getTimeZoneOffsetInSeconds();
  DateTime time = DateTime.fromMillisecondsSinceEpoch(timestamp);

  int offset = timezoneOffsetInSeconds * 60 * 1000;
  DateTime offsetTime = time.add(Duration(milliseconds: offset));
  String formattedOffsetTime =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(offsetTime);

  return formattedOffsetTime;
}

int getTimeZoneOffsetInSeconds() {
  final now = DateTime.now();
  final timeZoneOffset = now.timeZoneOffset.inSeconds;
  return timeZoneOffset;
}

String formatDuration(int seconds) {
  String sign = seconds < 0 ? '-' : '+';
  seconds = seconds.abs();

  int hours = seconds ~/ 3600;

  int minutes = (seconds % 3600) ~/ 60;
  return '$sign ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

int parseTimeZoneOffset(String timeZoneOffset) {
  int sign = timeZoneOffset[0] == '-' ? -1 : 1;
  int hours = int.parse(timeZoneOffset.substring(2, 4));
  int minutes = int.parse(timeZoneOffset.substring(5, 7));
  return sign * (hours * 3600 + minutes * 60);
}

int toUtcTimestamp(String dateTimeString, {String timezoneOffset = ""}) {
  if (timezoneOffset.isEmpty) {
    timezoneOffset = formatDuration(getTimeZoneOffsetInSeconds());
  }

  if (!RegExp(r'^[+-]\d{2}:\d{2}$').hasMatch(timezoneOffset)) {
    throw ArgumentError('Invalid timezone offset format');
  }

  DateTime localDateTime = DateTime.parse(dateTimeString);

  int hoursOffset = int.parse(timezoneOffset.substring(1, 3));
  int minutesOffset = int.parse(timezoneOffset.substring(4));
  int totalOffset = (hoursOffset * 60 + minutesOffset) *
      (timezoneOffset.startsWith("-") ? -1 : 1);

  DateTime utcDateTime =
      localDateTime.toUtc().add(Duration(minutes: totalOffset));

  return utcDateTime.millisecondsSinceEpoch ~/ 1000;
}

List<String> timeZoneOffsetList = [
  "- 12:00",
  "- 11:00",
  "- 10:00",
  "- 09:30",
  "- 09:00",
  "- 08:00",
  "- 07:00",
  "- 06:00",
  "- 05:00",
  "- 04:30",
  "- 04:00",
  "- 03:30",
  "- 03:00",
  "- 02:00",
  "- 01:00",
  "+ 00:00",
  "+ 01:00",
  "+ 02:00",
  "+ 03:00",
  "+ 03:30",
  "+ 04:00",
  "+ 04:30",
  "+ 05:00",
  "+ 05:30",
  "+ 05:45",
  "+ 06:00",
  "+ 06:30",
  "+ 07:00",
  "+ 08:00",
  "+ 08:45",
  "+ 09:00",
  "+ 09:30",
  "+ 10:00",
  "+ 10:30",
  "+ 11:00",
  "+ 12:00",
  "+ 12:45",
  "+ 13:00",
  "+ 14:00"
];
