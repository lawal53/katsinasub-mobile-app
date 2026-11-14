/// The same easy-to-guess checks the server makes, so the customer is told at once.
/// Returns null when the password is acceptable, otherwise the reason and an example.
String? passwordProblem(String pw, {String username = '', String email = '', String phone = '', String name = ''}) {
  const example = 'Example of a good password: Kasuwa@2026 or Mango7Tree.';
  final lower = pw.toLowerCase();
  if (pw.length < 8) return 'Your password is too short. Use at least 8 characters, mixing letters and numbers. $example';
  if (pw.length > 100) return 'Your password is too long. Use at most 100 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(pw) || !RegExp(r'\d').hasMatch(pw)) {
    return 'Your password is too easy to guess because it uses only numbers (or only letters). Mix letters and numbers. $example';
  }
  const common = {
    '12345678', '123456789', '1234567890', '87654321', '11111111', '00000000', 'password', 'password1', 'password12', 'password123', 'passw0rd',
    'qwerty123', 'qwertyui', 'qwertyuiop', 'abcd1234', 'abc12345', 'abcdefgh', 'a1234567', 'a12345678', '1q2w3e4r', '1qaz2wsx', 'iloveyou',
    'iloveyou1', 'welcome1', 'welcome123', 'admin123', 'admin1234', 'letmein1', 'monkey123', 'dragon123', 'football1', 'nigeria123',
    'katsina123', 'katsinasub', 'katsinasub1', 'katsinasub123', 'katsinasub1234', 'musa1234', 'abdul1234', 'ibrahim123', 'sunday123',
    'changeme1', 'test1234', 'user1234',
  };
  if (common.contains(lower)) return 'That password is one of the most commonly used ones, so anyone can guess it. $example';
  if (RegExp(r'^(.{1,3})\1+$').hasMatch(pw)) return 'Your password repeats the same characters, so it is easy to guess. $example';
  // Long runs such as 12345 or abcde.
  var run = 1, best = 1, dir = 0;
  for (var i = 1; i < lower.length; i++) {
    final a = lower.codeUnitAt(i - 1), b = lower.codeUnitAt(i);
    final d = b - a;
    final bothDigits = a >= 48 && a <= 57 && b >= 48 && b <= 57;
    final bothLetters = a >= 97 && a <= 122 && b >= 97 && b <= 122;
    if ((bothDigits || bothLetters) && (d == 1 || d == -1)) {
      run = (dir == d) ? run + 1 : 2;
      dir = d;
    } else {
      run = 1;
      dir = 0;
    }
    if (run > best) best = run;
  }
  if (best >= 5) return 'Your password contains an easy sequence (like 12345 or abcde). Choose something less predictable. $example';
  final bits = <String>[];
  for (final src in [username, name]) {
    for (final part in src.toLowerCase().split(RegExp(r'[\s_.\-]+'))) {
      if (part.length >= 4) bits.add(part);
    }
  }
  final local = email.toLowerCase().split('@').first;
  if (local.length >= 4) bits.add(local);
  for (final b in bits) {
    if (lower == b || (b.length >= 6 && lower.contains(b))) {
      return 'Your password contains your own name, username or email, which is easy for others to guess. $example';
    }
  }
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 7 && pw.replaceAll(RegExp(r'\D'), '').contains(digits.substring(digits.length - 7))) {
    return 'Your password contains your phone number, which is easy for others to guess. $example';
  }
  return null;
}
