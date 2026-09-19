import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// App-lock: locks the app after 5 minutes of inactivity (same PIN as
/// the website's transaction PIN).
///
/// Note: fingerprint unlock was removed because the biometric_storage
/// plugin's Android build could not be made to compile against the
/// Android SDK versions its own dependencies require. The PIN lock
/// below is fully independent of that and works the same as before.
class LockService {
  LockService._();
  static final LockService instance = LockService._();

  static const Duration inactivityLimit = Duration(minutes: 5);

  final ApiService _api = ApiService();

  /// True while the lock screen should be shown on top of everything.
  final ValueNotifier<bool> locked = ValueNotifier<bool>(false);

  DateTime? _backgroundedAt;

  /// Call from the app's lifecycle observer.
  void onPause() => _backgroundedAt = DateTime.now();

  /// Call from the app's lifecycle observer when the app comes back to
  /// the foreground. Returns true if it just locked.
  bool onResume() {
    final bg = _backgroundedAt;
    _backgroundedAt = null;
    if (bg != null && DateTime.now().difference(bg) >= inactivityLimit) {
      locked.value = true;
      return true;
    }
    return false;
  }

  void unlock() => locked.value = false;

  /// Checks a typed PIN against the website's transaction PIN.
  Future<bool> verifyPin(String pin) async {
    final res = await _api.verifyPin(pin);
    return res['success'] == true;
  }
}
