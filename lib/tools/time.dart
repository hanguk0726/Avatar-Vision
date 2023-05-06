import 'package:intl/intl.dart';

String getFormattedTimestamp({int? timestamp, String? format}) {
  timestamp ??= DateTime.now().millisecondsSinceEpoch;

  String formattedOffsetTime =
      DateFormat(format ?? 'yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(timestamp));

  return formattedOffsetTime;
}
