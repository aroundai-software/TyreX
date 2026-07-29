import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/report_provider.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../utils/app_constants.dart';
import '../utils/haptic_utils.dart';
import '../providers/user_provider.dart';
import '../providers/admin_settings_provider.dart';

class CloseScreen extends StatefulWidget {
  const CloseScreen({super.key});

  @override
  State<CloseScreen> createState() => _CloseScreenState();
}

class _CloseScreenState extends State<CloseScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _washTabController;
  final supabase = Supabase.instance.client;
  final Set<int> _loadingJobIds = {};



  @override
  void initState() {
    super.initState();
    // Initialize with default length, will be updated in didChangeDependencies
    _tabController = TabController(length: 2, vsync: this);
    _washTabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _washTabController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        // ✅ FIX: Convert the integer ID to a string
        Provider.of<ReportProvider>(context, listen: false).fetchReports(user['id']);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Fixed to 2 tabs: Ready to Close + Complete
    if (_tabController.length != 2) {
      _tabController.dispose();
      _tabController = TabController(length: 2, vsync: this);
      _tabController.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  // ✅ ADD THIS HELPER FUNCTION
  List<dynamic> _parseJsonList(dynamic data) {
    if (data is String && data.isNotEmpty) {
      try {
        return jsonDecode(data) as List;
      } catch (e) {
        return [];
      }
    } else if (data is List) {
      return data;
    }
    return [];
  }


  @override
  void dispose() {
    _tabController.dispose();
    _washTabController.dispose();
    super.dispose();
  }




  /// Determines the next status after inspection approval
  String _getPostInspectionStatus(AdminSettingsProvider adminSettings) {
    // If wash module is enabled, go to wash after inspection
    if (adminSettings.featureWashModule) {
      return AppConstants.statusSentToWash;
    }
    // If wash is disabled, mark as completed
    else {
      return AppConstants.statusCompleted;
    }
  }

  Future<void> _updateJobStatus(int reportId, String newStatus, String vehicleNo) async {
    // Immediately show loading on button
    setState(() => _loadingJobIds.add(reportId));
    try {
      await supabase.from('reports').update({'status': newStatus}).eq('id', reportId);

      if (!mounted) return;

      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        if (!mounted) return;
        await Provider.of<ReportProvider>(context, listen: false).refresh(user['id'] as int);
      }

      if (mounted) {
        setState(() => _loadingJobIds.remove(reportId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('$vehicleNo marked as Completed'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingJobIds.remove(reportId));
        _showError('Failed to update status: $e');
      }
    }
  }

  Future<void> _resendForInspection(int reportId) async {
    try {
      await supabase.from('reports').update({'status': 'pending_inspection'}).eq('id', reportId);
      if (!mounted) return;
      _showSuccess('Job has been resent to the inspector.');

      // BEFORE: _loadInspectionPendingJobs();
      // AFTER:
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        if (!mounted) return;
        await Provider.of<ReportProvider>(context, listen: false).refresh(user['id']);
      }
    } catch (e) {
      if (mounted) _showError('Failed to resend: $e');
    }
  }


  // --- UTILITY AND HELPER FUNCTIONS ---

  // ✅ TASK 3: Make error snackbar semi-transparent red to avoid hiding bottom buttons
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

  void _showSuccess(String message) {
    // Commented out to reduce UI noise
    // if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //   content: Text(message),
    //   backgroundColor: Colors.green,
    //   behavior: SnackBarBehavior.floating,
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg)),
    //   margin: const EdgeInsets.all(16),
    // ));
  }

  String _getBrandModel(Map<String, dynamic> job) {
    final brand = job['vehicles']?['vehicle_models']?['brand'] ?? '';
    final model = job['vehicles']?['vehicle_models']?['Model name'] ?? '';
    return '$brand $model'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Close',
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
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Consumer<AdminSettingsProvider>(
              builder: (context, adminSettings, _) {
                const List<Tab> tabs = [
                  Tab(text: 'Ready to Close'),
                  Tab(text: 'Complete'),
                ];

                return TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: const Color(0xFF6B7280),
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  isScrollable: true,
                  tabs: tabs,
                );
              },
            ),
          ),
          Expanded(
            child: Consumer<ReportProvider>(
              builder: (context, reportProvider, child) {
                final allReports = reportProvider.reports;
                final isLoading = reportProvider.isLoading && allReports.isEmpty;

                final readyToCloseJobs = allReports.where((r) {
                  final approvedList = _parseJsonList(r['approved']);
                  // Ready for Inspection covers both direct-save (no WhatsApp) and customer-approved paths
                  if (r['status'] == 'Ready for Inspection') return true;
                  // Ongoing jobs where customer has approved via WhatsApp
                  return r['status'] == 'Ongoing' && approvedList.isNotEmpty;
                }).toList();

                final rejectedJobs = allReports.where((r) => r['status'] == 'rejected').toList();
                final pendingInspectionJobs = allReports.where((r) => r['status'] == 'pending_inspection').toList();
                // Split wash-related jobs for sub-tabs
                // Not Washed: Only jobs that are inspection_approved (awaiting decision)
                final notWashedJobs = allReports.where((r) => r['status'] == 'inspection_approved').toList();
                // In Wash: Jobs that have been sent to wash OR are currently being washed
                final inWashJobs = allReports.where((r) => ['Sent To Wash', 'washing'].contains(r['status'])).toList();
                // ✅ TASK 1: Exclude 'Delivered' status so completed jobs disappear from list
                final completeJobs = allReports.where((r) => ['Wash Completed', 'Completed'].contains(r['status'])).toList();

                return isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                  onRefresh: () async {
                    final user = Provider.of<UserProvider>(context, listen: false).user;
                    if (user != null) {
                      await reportProvider.refresh(user['id'] as int);
                    }
                  },
                  child: Consumer<AdminSettingsProvider>(
                    builder: (context, adminSettings, _) {
                      // Build tab views dynamically based on enabled modules
                      final List<Widget> tabViews = [
                        _buildReadyToCloseTab(readyToCloseJobs),
                        _buildCompleteTab(completeJobs),
                      ];

                      return TabBarView(
                        controller: _tabController,
                        children: tabViews,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- UI BUILDER METHODS FOR EACH TAB ---

  Widget _buildReadyToCloseTab(List<Map<String, dynamic>> readyToCloseJobs) {
    if (readyToCloseJobs.isEmpty) {
      return const Center(
        child: Text(
          'No jobs are ready for the next step.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: readyToCloseJobs.length,
      itemBuilder: (context, index) {
        final job = readyToCloseJobs[index];
        final vehicleNo = job['vehicles']?['Vehicle Number'] ?? 'N/A';
        final brandModel = _getBrandModel(job);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
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
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              Builder(builder: (context) {
                final isLoading = _loadingJobIds.contains(job['id']);
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () => _updateJobStatus(
                      job['id'],
                      AppConstants.statusCompleted,
                      vehicleNo,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: Colors.green.shade300,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Complete'),
                  ),
                );
              }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInspectionPendingTab(List<Map<String, dynamic>> rejectedJobs, List<Map<String, dynamic>> pendingInspectionJobs) {
    final hasRejected = rejectedJobs.isNotEmpty;
    final hasPending = pendingInspectionJobs.isNotEmpty;

    if (!hasRejected && !hasPending) {
      return const Center(
        child: Text(
          'No jobs pending for inspection.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasRejected) ...[
          const Text(
            'Rejected by Inspector',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 12),
          // Use the parameter here
          ...rejectedJobs.map((job) => _buildRejectedJobCard(job)),
          const SizedBox(height: 24),
        ],
        if (hasPending) ...[
          const Text(
            'Pending Inspection',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          // Use the parameter here
          ...pendingInspectionJobs.map((job) => _buildPendingInspectionCard(job)),
        ],
      ],
    );
  }

  Widget _buildRejectedJobCard(Map<String, dynamic> job) {
    final vehicleNo = job['vehicles']?['Vehicle Number'] ?? 'N/A';
    final brandModel = _getBrandModel(job);
    final inspectorName = job['inspector']?['username'] ?? 'Inspector';
    final remarks = job['inspection_remarks'] ?? 'No remarks provided.';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      ),
                    ],
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _resendForInspection(job['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text('Resend'),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Remarks from $inspectorName:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"$remarks"',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingInspectionCard(Map<String, dynamic> job) {
    final vehicleNo = job['vehicles']?['Vehicle Number'] ?? 'N/A';
    final brandModel = _getBrandModel(job);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
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
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Sent to Inspector',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Main Wash Pending tab with nested sub-tabs
  Widget _buildWashPendingTabWithSubTabs(List<Map<String, dynamic>> notWashedJobs, List<Map<String, dynamic>> inWashJobs) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _washTabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF6B7280),
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pending_actions, size: 16),
                      const SizedBox(width: 6),
                      Text('Not Washed (${notWashedJobs.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.water_drop, size: 16),
                      const SizedBox(width: 6),
                      Text('In Wash (${inWashJobs.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _washTabController,
            children: [
              _buildNotWashedTab(notWashedJobs),
              _buildInWashTab(inWashJobs),
            ],
          ),
        ),
      ],
    );
  }

  // Tab for jobs that haven't been sent to wash yet
  Widget _buildNotWashedTab(List<Map<String, dynamic>> notWashedJobs) {
    if (notWashedJobs.isEmpty) {
      return const Center(
        child: Text(
          'No jobs awaiting wash decision.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notWashedJobs.length,
      itemBuilder: (context, index) {
        final job = notWashedJobs[index];
        final vehicleNo = job['vehicles']?['Vehicle Number'] ?? 'N/A';
        final brandModel = _getBrandModel(job);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Inspection Approved. Choose next step:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              Consumer<AdminSettingsProvider>(
                builder: (context, adminSettings, _) {
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(adminSettings.featureWashModule ? Icons.local_car_wash : Icons.check_circle, size: 18),
                          label: Text(adminSettings.featureWashModule ? 'Send for Wash' : 'Mark Complete'),
                          onPressed: () {
                            HapticUtils.medium();
                            _updateJobStatus(
                              job['id'],
                              _getPostInspectionStatus(adminSettings),
                              vehicleNo,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: adminSettings.featureWashModule ? AppTheme.primaryColor : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                  if (adminSettings.featureWashModule) ...[
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.skip_next, size: 18),
                        label: const Text('Skip Wash'),
                        onPressed: () async {
                          HapticUtils.light();
                          final confirmed = await _showConfirmDialog(
                            'Skip Wash?',
                            'Mark job for $vehicleNo as ready for completion without washing?',
                          );
                          if (confirmed == true) {
                            HapticUtils.success();
                            _updateJobStatus(
                              job['id'],
                              AppConstants.statusWashCompleted,
                              vehicleNo,
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.warningColor),
                          foregroundColor: AppTheme.warningColor,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Tab for jobs sent to wash or currently being washed
  Widget _buildInWashTab(List<Map<String, dynamic>> inWashJobs) {
    if (inWashJobs.isEmpty) {
      return const Center(
        child: Text(
          'No jobs in wash process.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: inWashJobs.length,
      itemBuilder: (context, index) {
        final job = inWashJobs[index];
        final vehicleNo = job['vehicles']?['Vehicle Number'] ?? 'N/A';
        final brandModel = _getBrandModel(job);
        final status = job['status'];
        
        // Determine badge based on status
        final bool isWashing = status == 'washing';
        final badgeText = isWashing ? 'Washing' : 'Sent to Wash';
        final badgeColor = Colors.blue.shade700; // Changed to blue for both statuses
        final bgColor = Colors.blue.shade50; // Light blue for both statuses
        final borderColor = Colors.blue.shade200; // Light blue border for both statuses

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      badgeColor.withValues(alpha: 0.2),
                      badgeColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isWashing ? Icons.water_drop : Icons.local_car_wash,
                  color: badgeColor,
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
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isWashing ? Icons.water_drop : Icons.send,
                      size: 14,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompleteTab(List<Map<String, dynamic>> completeJobs) {
    if (completeJobs.isEmpty) { // uses parameter
      return const Center(
        child: Text('No completed jobs yet.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completeJobs.length, // uses parameter
      itemBuilder: (context, index) {
        final job = completeJobs[index]; // uses parameter
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
          child: Row(
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
                    const SizedBox(height: 4),
                    const Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 32),
            ],
          ),
        );
      },
    );
  }



  // ✅ ADDED for Skip Wash confirmation
  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg)),
        scrollable: true,
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          // --- FIX START ---
          ElevatedButton(
            // Correct onPressed: just pop true
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor, // Or confirmColor if passed
              foregroundColor: Colors.white,
            ),
            // Correct child: simple Text
            child: const Text('Confirm'),
          ),
          // --- FIX END ---
        ],
      ),
    );
  }
}

