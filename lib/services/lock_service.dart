import 'package:flutter/foundation.dart';
import '../l10n.dart' show tr;
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

enum BiometricUnlockResult { ok, canceled, error, invalidated }

/// App-lock: locks the app after 5 minutes of inactivity (same PIN as
/// the website's transaction PIN), with optional fingerprint/face
/// unlock as a shortcut on top of the PIN.
///
/// Uses `local_auth` for the actual biometric prompt. IMPORTANT LIMIT:
/// `local_auth`'s authenticate() is NOT bound to an Android Keystore key,
/// so the OS does not automatically invalidate it when a NEW fingerprint
/// is enrolled alongside existing ones (Android only auto-invalidates a
/// *Keystore-bound* credential on re-enrollment; a plain biometric prompt
/// keeps accepting any currently-enrolled finger). Detecting "a new
/// fingerprint was added" reliably requires native platform code (or the
/// `biometric_storage` plugin, which failed to build against this
/// project's Android setup previously) — neither of which this Dart-only
/// project has access to. As a real, working safety net instead: fingerprint
/// unlock always expires after [_kMaxDaysWithoutPin] days without the PIN
/// being typed in full, forcing a real PIN re-entry on a regular cadence
/// regardless of whether the enrolled fingerprint changed. This bounds how
/// long a changed fingerprint could work for, even though it can't detect
/// the change itself.
class LockService {
  LockService._();
  static final LockService instance = LockService._();

  static const Duration inactivityLimit = Duration(minutes: 5);

  final ApiService _api = ApiService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const _kBiometricEnabledKey = 'biometric_unlock_enabled';
  static const _kBiometricSignatureKey = 'biometric_enrolled_signature';
  static const _kLastPinVerifyKey = 'biometric_last_pin_verify_at';
  static const int _kMaxDaysWithoutPin = 7;

  /// True while the lock screen should be shown on top of everything.
  final ValueNotifier<bool> locked = ValueNotifier<bool>(false);

  DateTime? _backgroundedAt;
  static const _kBackgroundedAtKey = 'app_backgrounded_at';

  /// Call from the app's lifecycle observer. Also written to secure
  /// storage (not just kept in memory) so the timer survives the Dart
  /// isolate being torn down and recreated while backgrounded — some
  /// Android devices do this under memory pressure without fully killing
  /// the process, which would otherwise silently reset this to null.
  void onPause() {
    _backgroundedAt = DateTime.now();
    _secureStorage.write(key: _kBackgroundedAtKey, value: _backgroundedAt!.toIso8601String());
  }

  /// Call from the app's lifecycle observer when the app comes back to
  /// the foreground. Returns true if it just locked.
  Future<bool> onResume() async {
    var bg = _backgroundedAt;
    _backgroundedAt = null;

    // In-memory value is gone — fall back to what was persisted, in case
    // the isolate was torn down and recreated while backgrounded.
    if (bg == null) {
      try {
        final raw = await _secureStorage.read(key: _kBackgroundedAtKey);
        if (raw != null) bg = DateTime.tryParse(raw);
      } catch (_) {}
    }
    _secureStorage.delete(key: _kBackgroundedAtKey);

    if (bg != null && DateTime.now().difference(bg) >= inactivityLimit) {
      locked.value = true;
      return true;
    }
    return false;
  }

  void unlock() => locked.value = false;

  /// Checks a typed PIN against the website's transaction PIN. Every
  /// successful full-PIN entry resets the fingerprint-unlock expiry
  /// countdown (see [_kMaxDaysWithoutPin]).
  Future<bool> verifyPin(String pin) async {
    final res = await _api.verifyPin(pin);
    final ok = res['success'] == true;
    if (ok) await _recordPinVerified();
    return ok;
  }

  Future<void> _recordPinVerified() async {
    try {
      await _secureStorage.write(key: _kLastPinVerifyKey, value: DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<bool> _pinVerifiedRecently() async {
    try {
      final raw = await _secureStorage.read(key: _kLastPinVerifyKey);
      if (raw == null) return false;
      final last = DateTime.tryParse(raw);
      if (last == null) return false;
      return DateTime.now().difference(last).inDays < _kMaxDaysWithoutPin;
    } catch (_) {
      return false;
    }
  }

  /// Whether this device can even offer biometrics right now (hardware
  /// present and at least one fingerprint/face enrolled).
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final avail = await _localAuth.getAvailableBiometrics();
      return avail.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> _biometricSignature() async {
    try {
      final avail = await _localAuth.getAvailableBiometrics();
      final sorted = avail.map((e) => e.name).toList()..sort();
      return sorted.join(',');
    } catch (_) {
      return '';
    }
  }

  /// Whether fingerprint unlock is currently turned on for this account
  /// on this device. Automatically turns itself off (and returns false)
  /// if the phone's enrolled fingerprints/face have changed since it was
  /// last turned on.
  Future<bool> get biometricEnabled async {
    final flag = await _secureStorage.read(key: _kBiometricEnabledKey);
    if (flag != 'true') return false;
    final storedSignature = await _secureStorage.read(key: _kBiometricSignatureKey);
    final currentSignature = await _biometricSignature();
    if (storedSignature == null || storedSignature.isEmpty || storedSignature != currentSignature) {
      await disableBiometric();
      return false;
    }
    return true;
  }

  /// Call only after the PIN has already been verified. Prompts for a
  /// fingerprint scan to confirm it works, then turns unlock on.
  /// Throws if the scan itself fails or is canceled.
  Future<void> enableBiometric() async {
    final result = await _localAuth.authenticate(
      localizedReason: tr('Confirm your fingerprint to enable fingerprint unlock'),
      options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
    );
    if (!result) {
      throw Exception('Fingerprint scan bai yi nasara ba.');
    }
    await _secureStorage.write(key: _kBiometricEnabledKey, value: 'true');
    await _secureStorage.write(key: _kBiometricSignatureKey, value: await _biometricSignature());
    await _recordPinVerified();
  }

  Future<void> disableBiometric() async {
    await _secureStorage.delete(key: _kBiometricEnabledKey);
    await _secureStorage.delete(key: _kBiometricSignatureKey);
  }

  /// Attempts to unlock the app with a fingerprint/face scan. Returns
  /// [BiometricUnlockResult.invalidated] if biometric unlock isn't
  /// currently enabled (including just having auto-disabled itself due
  /// to a fingerprint enrollment change) — the caller should fall back
  /// to the PIN pad in that case.
  Future<BiometricUnlockResult> unlockWithBiometric() async {
    if (!await biometricEnabled) return BiometricUnlockResult.invalidated;
    // Real PIN not typed in a while (see class doc) — require it again as
    // a safety net, rather than trusting the fingerprint indefinitely.
    if (!await _pinVerifiedRecently()) return BiometricUnlockResult.invalidated;
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: tr('Use your fingerprint to unlock the app'),
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: false),
      );
      if (ok) {
        unlock();
        return BiometricUnlockResult.ok;
      }
      return BiometricUnlockResult.canceled;
    } catch (_) {
      return BiometricUnlockResult.error;
    }
  }
}
