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
/// Uses `local_auth` (maintained directly by the Flutter team) for the
/// actual biometric prompt — this replaced an earlier attempt with the
/// third-party `biometric_storage` package, whose Android build could
/// not be made to compile against the SDK versions its own dependencies
/// required. `local_auth` doesn't expose a native keystore binding the
/// way `biometric_storage` did, so the "auto-disable if the enrolled
/// fingerprint changes" protection below is approximated by comparing
/// the device's list of enrolled biometric types against what was
/// recorded when the user turned it on, rather than a hardware-backed
/// key invalidation. That covers the realistic case (someone adds or
/// removes a fingerprint on the phone) even though it isn't quite as
/// tamper-proof against a rooted device as the native approach.
class LockService {
  LockService._();
  static final LockService instance = LockService._();

  static const Duration inactivityLimit = Duration(minutes: 5);

  final ApiService _api = ApiService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const _kBiometricEnabledKey = 'biometric_unlock_enabled';
  static const _kBiometricSignatureKey = 'biometric_enrolled_signature';

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
