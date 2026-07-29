import 'package:flutter/services.dart';

/// Utility class for haptic feedback throughout the app
class HapticUtils {
  /// Light haptic feedback for subtle interactions (e.g., button taps, switches)
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium haptic feedback for standard interactions (e.g., confirmations, selections)
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy haptic feedback for important actions (e.g., deletions, critical confirmations)
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Selection haptic feedback for scrolling through items
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Vibrate pattern for success actions
  static void success() {
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.lightImpact();
    });
  }

  /// Vibrate pattern for error/warning actions
  static void error() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.heavyImpact();
    });
  }
}
