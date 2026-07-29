import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/report_provider.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../utils/app_constants.dart';
import '../providers/user_provider.dart';
import '../services/supabase_service.dart';

class CloseScreen extends StatefulWidget {
  const CloseScreen({super.key});

  @override
  State<CloseScreen> createState() => _CloseScreenState();
}

class _CloseScreenState extends State<CloseScreen> {
  final supabase = Supabase.instance.client;
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<ReportProvider>(context, listen: false).fetchReports(user['id']);
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _getBrandModel(Map<String, dynamic> job) {
    final brand = job['vehicles']?['vehicle_models']?['brand'] ?? '';
    final model = job['vehicles']?['vehicle_models']?['Model name'] ?? '';
    return '$brand $model'.trim();
  }

  Future<void> _handleJobCompletion(Map<String, dynamic> job) async {
    final int reportId = job['id'];
    final String vehicleNo = job['vehicles']?['Vehicle Number'] ?? 'N/A';

    final confirmed = await _showCompletionConfirmationDialog(vehicleNo);
    if (confirmed != true) return;

    try {
      await supabase.from('reports').update({
        'status': 'Delivered',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);

      if (!mounted) return;

      try {
        await _supabaseService.createServiceReminder(reportId);
      } catch (reminderError) {
        if (mounted) {
          _showError('Job completed but failed to create service reminder: $reminderError');
        }
      }

      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        if (!mounted) return;
        await Provider.of<ReportProvider>(context, listen: false).refresh(user['id']);
      }

      if (mounted) {
        await _showSuccessDialog(vehicleNo);
      }
    } catch (e) {
      if (mounted) _showError('Failed to mark as completed: $e');
    }
  }

  Future<bool?> _showCompletionConfirmationDialog(String vehicleNo) {
    final confirmationController = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg)),
              scrollable: true,
              title: Row(
                children: const [
                  Icon(Icons.check_circle_outline, color: Colors.green),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Confirm Job Completion',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Are you sure you want to mark the job for vehicle $vehicleNo as completed?'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmationController,
                    decoration: const InputDecoration(
                      labelText: "Type 'yes' to confirm",
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: confirmationController.text.trim().toLowerCase() == 'yes'
                      ? () => Navigator.pop(context, true)
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Confirm Completion'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSuccessDialog(String vehicleNo) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Job Completed Successfully!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Vehicle $vehicleNo has been marked as delivered.',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Service reminder has been created.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Close / Delivery',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: AppTheme.primaryColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<ReportProvider>(
        builder: (context, reportProvider, child) {
          final allReports = reportProvider.reports;
          final isLoading = reportProvider.isLoading && allReports.isEmpty;

          // Only show completed jobs (which bypassed inspection/wash)
          final completeJobs = allReports.where((r) => r['status'] == AppConstants.statusCompleted).toList();

          return isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    final user = Provider.of<UserProvider>(context, listen: false).user;
                    if (user != null) {
                      await reportProvider.refresh(user['id'] as int);
                    }
                  },
                  child: _buildCompleteList(completeJobs),
                );
        },
      ),
    );
  }

  Widget _buildCompleteList(List<Map<String, dynamic>> completeJobs) {
    if (completeJobs.isEmpty) {
      return const Center(
        child: Text('No jobs are ready for completion.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completeJobs.length,
      itemBuilder: (context, index) {
        final job = completeJobs[index];
        final vehicleNo = job['vehicles']?['Vehicle Number'] ?? 'N/A';
        final brandModel = _getBrandModel(job);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEEBFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicleNo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (brandModel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            brandModel,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (job['started_at'] != null && job['completed_at'] != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: AppTheme.primaryColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Completed in ${_formatDuration(job['started_at'], job['completed_at'])}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        const Text(
                          'Ready for delivery',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _handleJobCompletion(job),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text(
                    'Mark Completed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(String? start, String? end) {
    if (start == null) return 'N/A';
    final startTime = DateTime.tryParse(start);
    if (startTime == null) return 'N/A';

    final endTime = (end != null ? DateTime.tryParse(end) : null) ?? DateTime.now();
    final duration = endTime.difference(startTime);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hr ${minutes} min';
    }
    return '$minutes min';
  }
}
