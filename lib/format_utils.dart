const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "2026-11-12 14:30:00" -> "12 Nov 2026". Returns '' when it cannot be read.
String fmtDate(dynamic value) {
  final d = DateTime.tryParse('${value ?? ''}'.replaceFirst(' ', 'T'));
  if (d == null) return '';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// 93784 seconds -> "1d 2h left"
String fmtTimeLeft(num seconds) {
  final s = seconds.toInt();
  if (s <= 0) return 'Time is up';
  final d = s ~/ 86400, h = (s % 86400) ~/ 3600, m = (s % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h left';
  if (h > 0) return '${h}h ${m}m left';
  return '${m}m left';
}
