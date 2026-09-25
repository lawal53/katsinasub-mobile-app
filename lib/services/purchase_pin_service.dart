import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Lets a customer confirm a purchase with their fingerprint instead of
/// typing their transaction PIN every time. The PIN itself is still what
/// authorizes the transaction on the server — this just fills it in for
/// the customer once their fingerprint is confirmed, the same way the
/// app-lock's fingerprint unlock stands in for typing the lock PIN.
class PurchasePinService {
  static final PurchasePinService _instance = PurchasePinService._internal();
  factory PurchasePinService() => _instance;
  PurchasePinService._internal();

  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'purchase_fingerprint_enabled';
  static const _pinKey = 'purchase_fingerprint_pin';
  final _auth = LocalAuthentication();

  Future<bool> isEnabled() async {
    try {
      return await _storage.read(key: _enabledKey) == '1';
    } catch (_) {
      return false;
    }
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Turns the feature on: confirms the fingerprint, then stores this PIN
  /// (encrypted, device-local) so future purchases can be confirmed with
  /// just a fingerprint instead of typing it.
  Future<bool> enable(String pin) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Confirm your fingerprint to enable fingerprint purchases',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!ok) return false;
      await _storage.write(key: _pinKey, value: pin);
      await _storage.write(key: _enabledKey, value: '1');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disable() async {
    try {
      await _storage.delete(key: _pinKey);
      await _storage.write(key: _enabledKey, value: '0');
    } catch (_) {}
  }

  /// Prompts for a fingerprint and, on success, returns the saved PIN to
  /// auto-fill the transaction PIN field. Returns null on cancel/failure/
  /// not-enabled, in which case the customer just types their PIN as usual.
  Future<String?> getPinViaFingerprint() async {
    try {
      if (!await isEnabled()) return null;
      final pin = await _storage.read(key: _pinKey);
      if (pin == null || pin.isEmpty) return null;
      final ok = await _auth.authenticate(
        localizedReason: 'Use your fingerprint to confirm this purchase',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      return ok ? pin : null;
    } catch (_) {
      return null;
    }
  }
}
