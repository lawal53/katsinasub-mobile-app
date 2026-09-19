import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:biometric_storage/biometric_storage.dart';

import 'api_service.dart';

/// App-lock: locks the app after 5 minutes of inactivity (same PIN as
/// the website's transaction PIN), with optional fingerprint unlock.
///
/// Fingerprint security model (mirrors what a banking app does):
/// the PIN is stored in [BiometricStorage], which on Android is backed
/// by a Keystore key created with setInvalidatedByBiometricEnrollment
/// (true) and on iOS/macOS by a Keychain item with
/// kSecAccessControlBiometryCurrentSet. Both OSes destroy that key the
/// moment the user adds, removes, or re-enrolls a fingerprint/Face ID.
/// So the very next fingerprint attempt after ANY enrollment change
/// fails, we catch that, turn fingerprint unlock back off, and the
/// user has to open Account Settings > Security and turn it on again
/// (typing their PIN once) before it will work — exactly "kada app
/// yayi aiki da finger har sai an je settings an sake bude shi".
class LockService {
  LockService._();
  static final LockService instance = LockService._();

  static const Duration inactivityLimit = Duration(minutes: 5);
  static const String _storageName = 'katsinasub_lock_pin';

  final _secure = const FlutterSecureStorage();
  final ApiService _api = ApiService();

  /// True while the lock screen should be shown on top of everything.
  final ValueNotifier<bool> locked = ValueNotifier<bool>(false);

  DateTime? _backgroundedAt;

  Future<bool> get biometricEnabled async =>
      (await _secure.read(key: 'biometric_unlock_enabled')) == '1';

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

  Future<CanAuthenticateResponse> canUseBiometrics() =>
      BiometricStorage().canAuthenticate();

  /// Turns fingerprint unlock ON. Requires the correct PIN once (proves
  /// it's really the account owner), then binds that PIN behind a
  /// biometric-gated key for THIS device's current fingerprint set.
  Future<bool> enableBiometric(String verifiedPin) async {
    final storage = await BiometricStorage().getStorage(
      _storageName,
      options: StorageFileInitOptions(authenticationValidityDurationSeconds: -1, androidBiometricOnly: true),
    );
    await storage.write(verifiedPin); // prompts for fingerprint right here
    await _secure.write(key: 'biometric_unlock_enabled', value: '1');
    return true;
  }

  Future<void> disableBiometric() async {
    await _secure.delete(key: 'biometric_unlock_enabled');
    try {
      final storage = await BiometricStorage().getStorage(_storageName, options: StorageFileInitOptions());
      await storage.delete();
    } catch (_) {}
  }

  /// Result of a fingerprint unlock attempt.
  ///   ok        -> unlocked
  ///   canceled  -> user backed out; let them type the PIN instead
  ///   invalidated -> the fingerprint set on this phone changed since
  ///                  it was enrolled here; fingerprint unlock has been
  ///                  turned off — tell the user to redo it in Settings
  ///   error     -> anything else; fall back to PIN
  Future<BiometricUnlockResult> unlockWithBiometric() async {
    try {
      final storage = await BiometricStorage().getStorage(
        _storageName,
        options: StorageFileInitOptions(authenticationValidityDurationSeconds: -1, androidBiometricOnly: true),
      );
      final pin = await storage.read();
      if (pin == null || pin.isEmpty) {
        // Nothing usable came back — most likely the OS silently wiped
        // the key after an enrollment change. Treat as invalidated.
        await disableBiometric();
        return BiometricUnlockResult.invalidated;
      }
      unlock();
      return BiometricUnlockResult.ok;
    } on AuthException catch (e) {
      switch (e.code) {
        case AuthExceptionCode.userCanceled:
          return BiometricUnlockResult.canceled;
        case AuthExceptionCode.lockedOut:
        case AuthExceptionCode.lockedOutPermanently:
        case AuthExceptionCode.timeout:
          // Temporary — too many wrong fingerprints, not an enrollment
          // change. Let the user fall back to typing the PIN; leave
          // fingerprint unlock switched on for next time.
          return BiometricUnlockResult.error;
        default:
          // Anything else here — including the OS having just deleted
          // the invalidated key after an enrollment change — means we
          // can no longer trust this device's fingerprint for this
          // account. Require the PIN once, re-enabled from Settings.
          await disableBiometric();
          return BiometricUnlockResult.invalidated;
      }
    } catch (_) {
      await disableBiometric();
      return BiometricUnlockResult.invalidated;
    }
  }
}

enum BiometricUnlockResult { ok, canceled, invalidated, error }
