/// Formats a Naira amount with thousands separators, the same way the
/// website does (e.g. 11505.5 -> "11,505.50"). Accepts num, String, or
/// null (num?/dynamic) since API values arrive in different shapes.
String nairaAmount(dynamic value) {
  final n = value is num ? value.toDouble() : (double.tryParse('$value') ?? 0);
  final fixed = n.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final isNegative = whole.startsWith('-');
  final digits = isNegative ? whole.substring(1) : whole;

  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${isNegative ? '-' : ''}$buf.${parts[1]}';
}
