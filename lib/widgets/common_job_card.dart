import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/haptic_utils.dart';

/// Reusable job card widget for consistent UI across screens
class CommonJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback? onTap;
  final Widget? trailing;
  final List<Widget>? actions;
  final bool showStatus;
  final bool showDate;
  final Color? statusColor;

  const CommonJobCard({
    super.key,
    required this.job,
    this.onTap,
    this.trailing,
    this.actions,
    this.showStatus = true,
    this.showDate = true,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final vehicle = job['vehicles'];
    final model = vehicle?['vehicle_models'];
    final vehicleNo = vehicle?['Vehicle Number'] ?? 'N/A';
    final brand = model?['brand'] ?? 'Unknown';
    final modelName = model?['Model name'] ?? '';
    final status = job['status'] ?? 'Unknown';
    final clientName = job['client_phone'] ?? 'N/A';
    final createdAt = job['created_at'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticUtils.light();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Vehicle Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Vehicle Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicleNo,
                          style: AppTypography.h3.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$brand $modelName',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Trailing widget
                  if (trailing != null) trailing!,
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Client Info
              _buildInfoRow(
                icon: Icons.person_outline,
                label: 'Client',
                value: clientName,
              ),

              // Status
              if (showStatus) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.info_outline,
                  label: 'Status',
                  value: status,
                  valueColor: statusColor ?? _getStatusColor(status),
                  valueWeight: FontWeight.w600,
                ),
              ],

              // Date
              if (showDate && createdAt != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Created',
                  value: _formatDate(createdAt),
                ),
              ],

              // Actions
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTypography.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: valueWeight ?? FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'ongoing':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.blue;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

/// Compact version of job card for lists
class CompactJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback? onTap;
  final Widget? trailing;

  const CompactJobCard({
    super.key,
    required this.job,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final vehicle = job['vehicles'];
    final vehicleNo = vehicle?['Vehicle Number'] ?? 'N/A';
    final status = job['status'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap != null
            ? () {
                HapticUtils.light();
                onTap!();
              }
            : null,
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryLight,
          child: const Icon(
            Icons.directions_car,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          vehicleNo,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          status,
          style: AppTypography.bodySmall,
        ),
        trailing: trailing,
      ),
    );
  }
}
