import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing user preferences
class UserPreferencesProvider extends ChangeNotifier {
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _hapticFeedbackKey = 'haptic_feedback';
  static const String _animationsEnabledKey = 'animations_enabled';
  static const String _autoLogoutKey = 'auto_logout_enabled';
  static const String _autoLogoutMinutesKey = 'auto_logout_minutes';

  bool _biometricEnabled = false;
  bool _hapticFeedback = true;
  bool _animationsEnabled = true;
  bool _autoLogoutEnabled = true;
  int _autoLogoutMinutes = 15;

  bool get biometricEnabled => _biometricEnabled;
  bool get hapticFeedback => _hapticFeedback;
  bool get animationsEnabled => _animationsEnabled;
  bool get autoLogoutEnabled => _autoLogoutEnabled;
  int get autoLogoutMinutes => _autoLogoutMinutes;

  UserPreferencesProvider() {
    _loadPreferences();
  }

  /// Load all preferences from shared preferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    _biometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
    _hapticFeedback = prefs.getBool(_hapticFeedbackKey) ?? true;
    _animationsEnabled = prefs.getBool(_animationsEnabledKey) ?? true;
    _autoLogoutEnabled = prefs.getBool(_autoLogoutKey) ?? true;
    _autoLogoutMinutes = prefs.getInt(_autoLogoutMinutesKey) ?? 15;
    
    notifyListeners();
  }

  /// Toggle biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  /// Toggle haptic feedback
  Future<void> setHapticFeedback(bool enabled) async {
    _hapticFeedback = enabled;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticFeedbackKey, enabled);
  }

  /// Toggle animations
  Future<void> setAnimationsEnabled(bool enabled) async {
    _animationsEnabled = enabled;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animationsEnabledKey, enabled);
  }

  /// Toggle auto logout
  Future<void> setAutoLogoutEnabled(bool enabled) async {
    _autoLogoutEnabled = enabled;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoLogoutKey, enabled);
  }

  /// Set auto logout duration
  Future<void> setAutoLogoutMinutes(int minutes) async {
    _autoLogoutMinutes = minutes;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLogoutMinutesKey, minutes);
  }
}
