import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_typography.dart';

/// Widget to display when there's no data to show
class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  final Color? iconColor;
  final bool animate;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
    this.iconColor,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget content = Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.grey.shade400).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: iconColor ?? Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTypography.h2.copyWith(
                color: theme.textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTypography.body.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel ?? 'Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (animate) {
      return content
          .animate()
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOut);
    }

    return content;
  }
}

/// Predefined empty states for common scenarios
class EmptyStates {
  static Widget noJobs({VoidCallback? onRefresh}) => EmptyState(
        title: 'No Jobs Available',
        message: 'There are no jobs to display at the moment.',
        icon: Icons.work_off_outlined,
        onAction: onRefresh,
        actionLabel: 'Refresh',
      );

  static Widget noReports({VoidCallback? onRefresh}) => EmptyState(
        title: 'No Reports Found',
        message: 'You haven\'t created any reports yet.',
        icon: Icons.description_outlined,
        onAction: onRefresh,
        actionLabel: 'Refresh',
      );

  static Widget noSearchResults({VoidCallback? onClear}) => EmptyState(
        title: 'No Results Found',
        message: 'Try adjusting your search filters.',
        icon: Icons.search_off,
        onAction: onClear,
        actionLabel: 'Clear Filters',
      );

  static Widget networkError({VoidCallback? onRetry}) => EmptyState(
        title: 'Connection Error',
        message: 'Unable to load data. Please check your internet connection.',
        icon: Icons.wifi_off,
        iconColor: Colors.orange,
        onAction: onRetry,
        actionLabel: 'Retry',
      );

  static Widget error({
    required String message,
    VoidCallback? onRetry,
  }) =>
      EmptyState(
        title: 'Something Went Wrong',
        message: message,
        icon: Icons.error_outline,
        iconColor: Colors.red,
        onAction: onRetry,
        actionLabel: 'Try Again',
      );
}
