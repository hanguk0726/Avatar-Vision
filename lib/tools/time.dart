import 'package:intl/intl.dart';

String getFormattedTimestamp(int timestamp, {int? timezoneOffset}) {
  timezoneOffset ??= getTimeZoneOffset();
  DateTime time = DateTime.fromMillisecondsSinceEpoch(timestamp);

  int offset = timezoneOffset * 60 * 1000;
  DateTime offsetTime = time.add(Duration(milliseconds: offset));
  String formattedOffsetTime =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(offsetTime);

  return formattedOffsetTime;
}

int getTimeZoneOffset() {
  final now = DateTime.now();
  final timeZoneOffset = now.timeZoneOffset.inSeconds;
  return timeZoneOffset;
}
