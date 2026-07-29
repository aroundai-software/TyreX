import 'dart:async';
import 'package:flutter/material.dart';

/// Service to handle auto-logout on user inactivity
class InactivityService {
  Timer? _inactivityTimer;
  final Duration inactivityDuration;
  final VoidCallback onInactive;

  InactivityService({
    this.inactivityDuration = const Duration(minutes: 15),
    required this.onInactive,
  });

  /// Start or reset the inactivity timer
  void resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityDuration, () {
      onInactive();
    });
  }

  /// Stop the inactivity timer
  void stopTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// Dispose of the timer
  void dispose() {
    stopTimer();
  }
}

/// Mixin to add inactivity detection to any StatefulWidget
mixin InactivityMixin<T extends StatefulWidget> on State<T> {
  InactivityService? _inactivityService;

  /// Override this to define what happens on inactivity
  void onInactive();

  /// Override this to customize inactivity duration (default: 15 minutes)
  Duration get inactivityDuration => const Duration(minutes: 15);

  @override
  void initState() {
    super.initState();
    _inactivityService = InactivityService(
      inactivityDuration: inactivityDuration,
      onInactive: onInactive,
    );
    _inactivityService!.resetTimer();
  }

  @override
  void dispose() {
    _inactivityService?.dispose();
    super.dispose();
  }

  /// Call this method on user interactions to reset the timer
  void resetInactivityTimer() {
    _inactivityService?.resetTimer();
  }

  /// Wrap your widget with this to detect user interactions
  Widget wrapWithInactivityDetector(Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: resetInactivityTimer,
      onPanDown: (_) => resetInactivityTimer(),
      onScaleStart: (_) => resetInactivityTimer(),
      child: child,
    );
  }
}
