// lib/widgets/modern_page_route.dart
import 'package:flutter/material.dart';

/// Modern page route with smooth transitions
class ModernPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;
  final RouteTransitionType transitionType;

  ModernPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
    this.transitionType = RouteTransitionType.slideUp,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _buildTransition(
              animation,
              secondaryAnimation,
              child,
              transitionType,
            );
          },
        );

  static Widget _buildTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
    RouteTransitionType type,
  ) {
    switch (type) {
      case RouteTransitionType.slideUp:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );

      case RouteTransitionType.slideRight:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );

      case RouteTransitionType.fade:
        return FadeTransition(
          opacity: animation,
          child: child,
        );

      case RouteTransitionType.scale:
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );

      case RouteTransitionType.fadeScale:
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.95,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );

      case RouteTransitionType.rotation:
        return RotationTransition(
          turns: Tween<double>(
            begin: 0.95,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
    }
  }
}

enum RouteTransitionType {
  slideUp,
  slideRight,
  fade,
  scale,
  fadeScale,
  rotation,
}

/// Extension for easy navigation with modern transitions
extension ModernNavigation on BuildContext {
  Future<T?> pushModern<T>(
    Widget page, {
    RouteTransitionType transition = RouteTransitionType.slideUp,
  }) {
    return Navigator.of(this).push<T>(
      ModernPageRoute<T>(
        page: page,
        transitionType: transition,
      ),
    );
  }

  Future<T?> pushReplacementModern<T>(
    Widget page, {
    RouteTransitionType transition = RouteTransitionType.fadeScale,
  }) {
    return Navigator.of(this).pushReplacement<T, void>(
      ModernPageRoute<T>(
        page: page,
        transitionType: transition,
      ),
    );
  }
}
