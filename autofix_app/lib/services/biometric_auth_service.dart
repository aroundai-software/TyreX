import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

/// Service for handling biometric authentication (fingerprint, face ID)
class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if biometric authentication is available on the device
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      _log('[biometric] canCheckBiometrics=$canCheck, isDeviceSupported=$supported');
      return canCheck || supported;
    } on PlatformException catch (e) {
      _log('[biometric] canCheckBiometrics error: ${e.message}');
      return false;
    }
  }

  /// Check if device has biometric hardware
  Future<bool> isDeviceSupported() async {
    try {
      final supported = await _auth.isDeviceSupported();
      _log('[biometric] isDeviceSupported=$supported');
      return supported;
    } on PlatformException catch (e) {
      _log('[biometric] isDeviceSupported error: ${e.message}');
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  /// Authenticate user with biometrics
  /// Returns true if authentication successful
  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access AutoFix',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool deviceSupported = await _auth.isDeviceSupported();
      final bool canAuthenticate = canAuthenticateWithBiometrics || deviceSupported;

      _log('[biometric] authenticate start, canCheck=$canAuthenticateWithBiometrics, deviceSupported=$deviceSupported');

      if (!canAuthenticate) {
        _log('[biometric] authenticate aborted: device cannot authenticate');
        return false;
      }

      final result = await _auth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true, // Force biometric authentication only
        ),
      );
      _log('[biometric] authenticate result=$result');
      return result;
    } on PlatformException catch (e) {
      _log('[biometric] authentication error: ${e.message}');
      return false;
    }
  }

  /// Stop authentication (if in progress)
  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } on PlatformException {
      // Ignore errors
    }
  }

  /// Get user-friendly biometric type name
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
      // default case removed as all BiometricType values are covered above
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
