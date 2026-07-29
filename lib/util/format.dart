/// Groups an integer with thousands separators, e.g. 12480 -> "12,480".
String thousands(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Today", "Yesterday", or "Wed 12 Mar".
String relativeDay(DateTime when, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());
  final day = _dayOf(when);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}';
}

/// "7:42 AM"
String clockTime(DateTime when) {
  final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
  final minute = when.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${when.hour < 12 ? 'AM' : 'PM'}';
}
