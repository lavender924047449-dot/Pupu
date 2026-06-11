import 'package:intl/intl.dart';
import 'package:pupu/models/bowel_record.dart';

String formatLogSessionMeta(BowelRecord record, String localeName) {
  final time = DateFormat.jm(localeName).format(record.dateTime);
  final duration = '${record.displayMinutes} min ${record.displaySeconds} sec';
  return '$time   $duration';
}
