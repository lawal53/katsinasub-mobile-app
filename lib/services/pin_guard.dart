import 'package:flutter/material.dart';
import '../main.dart' show rootNavigatorKey;
import '../screens/welcome_screen.dart';
import 'api_service.dart';
import 'lock_service.dart';

/// Wrong transaction PINs: after each wrong PIN the customer is told how many tries are left;
/// after the 5th wrong PIN in a row the app logs the account out. Logging in again starts fresh,
/// and a customer who forgot the PIN can simply log in and change it in Account Settings.
class PinGuard {
  static const int maxWrong = 5;
  static int _wrong = 0;
  /// A message waiting to be shown on the welcome page (after the automatic logout).
  static String? pendingNotice;

  static void reset() => _wrong = 0;

  /// Call when the server said the PIN was wrong. Returns the message to show.
  static Future<String> recordWrong() async {
    _wrong++;
    if (_wrong >= maxWrong) {
      _wrong = 0;
      const msg = 'You entered a wrong PIN 5 times, so you were logged out for your safety. Log in again. If you forgot your PIN, change it in Account Settings.';
      pendingNotice = msg;
      try { await ApiService().logout(); } catch (_) {}
      LockService.instance.unlock();
      rootNavigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false);
      return msg;
    }
    final left = maxWrong - _wrong;
    return 'Incorrect PIN. You have $left ${left == 1 ? 'try' : 'tries'} left. After $maxWrong wrong tries you will be logged out.';
  }
}
