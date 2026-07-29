// lib/screens/telecaller_dashboard_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/auth_helper.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart'; // ✅ Contains AppCard, FormLabel, and all theme properties
import '../providers/user_provider.dart';
import '../providers/admin_settings_provider.dart';
import '../widgets/modern_card.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_loading.dart';
import '../widgets/service_reminder_card.dart';
import '../utils/app_constants.dart';
import 'profile_screen.dart';

void _showSuccessDialog(BuildContext context, String customerName, String action) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Success!',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          
            Text(
              'Booking created successfully for $customerName',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),

          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );
}


class TelecallerDashboardScreen extends StatefulWidget {
  const TelecallerDashboardScreen({super.key});

  @override
  State<TelecallerDashboardScreen> createState() =>
      _TelecallerDashboardScreenState();
}

class _TelecallerDashboardScreenState extends State<TelecallerDashboardScreen> 
    with SingleTickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  late Future<Map<String, List<Map<String, dynamic>>>> _dataFuture;
  bool _isLoading = false;
  late TabController _tabController;
  bool _isWorkloadExpanded = false;

  // Get a reference to the Supabase client
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _dataFuture = _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchData() async {
    // Fetch all required data in parallel for faster loading
    final results = await Future.wait([
      _supabaseService.getOpenBookings(),
      _supabaseService.getPudoUsers(),
      _supabaseService.getExecutiveWorkload(),
      _supabaseService.getPudoWorkload(),
      _supabaseService.getDueServiceReminders(),
      _supabaseService.getJobsAwaitingExecutiveAssignment(),
      _supabaseService.getExecutiveUsers(),
      _supabaseService.getJobsForFeedback(),
    ]);
    return {
      'bookings': results[0],
      'pudoUsers': results[1],
      'workload': results[2],
      'pudoWorkload': results[3],
      'serviceReminders': results[4],
      'jobsAwaitingAssignment': results[5],
      'executiveUsers': results[6],
      'feedbackJobs': results[7],
    };
  }

  void _refreshData() {
    if (kDebugMode) {
      print('🔄 Refreshing telecaller dashboard data');
    }
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Call Center Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: AppTheme.primaryColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.primaryColor),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else if (value == 'logout') {
                _showLogoutConfirmationDialog(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 18),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !_isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(child: Text('No data available.'));
              }

              final bookings = snapshot.data!['bookings']!;
              final pudoUsers = snapshot.data!['pudoUsers']!;
              final workload = snapshot.data!['workload']!;
              final serviceReminders = snapshot.data!['serviceReminders']!;
              final jobsAwaitingAssignment = snapshot.data!['jobsAwaitingAssignment']!;
              final executiveUsers = snapshot.data!['executiveUsers']!;
              final feedbackJobs = snapshot.data!['feedbackJobs']!;
              // pudoWorkload is fetched but used only when needed in dialogs

              // Categorize bookings by status
              final assignedBookings = bookings.where((b) => b['status'] == 'Assigned').toList();
              final jobCardCreatedBookings = bookings.where((b) => b['status'] == 'Job Card Created - Walk-in').toList();

              return Column(
                children: [
                  // Team Workload Card (always visible at top)
                  // Padding(
                  //   padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  //   child: _buildClickableWorkloadCard(context, workload).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideX(begin: -0.2, end: 0),
                  // ),
                  
                  // Create New Booking Card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                    child: _buildCreateBookingCard(context).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),
                  ),
                  
                  // Tab Bar
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: const Color(0xFF6B7280),
                      indicatorColor: AppTheme.primaryColor,
                      indicatorWeight: 3,
                      isScrollable: true,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_add_rounded, size: 18),
                              const SizedBox(width: 6),
                              Text('Assigned (${assignedBookings.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.assignment_ind_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text('Assign Executive (${jobsAwaitingAssignment.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 18),
                              const SizedBox(width: 6),
                              Text('Service Reminders (${serviceReminders.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.feedback_rounded, size: 18),
                              const SizedBox(width: 6),
                              Text('Send Feedback (${feedbackJobs.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Assigned Tab
                        RefreshIndicator(
                          onRefresh: () async => _refreshData(),
                          child: _buildBookingsTab(context, assignedBookings, pudoUsers, 'assigned'),
                        ),
                        // Assign Executive Tab (Post Pickup)
                        RefreshIndicator(
                          onRefresh: () async => _refreshData(),
                          child: _buildJobAssignmentTab(context, jobsAwaitingAssignment, executiveUsers, workload),
                        ),
                        // Service Reminders Tab
                        RefreshIndicator(
                          onRefresh: () async => _refreshData(),
                          child: _buildServiceRemindersTab(context, serviceReminders),
                        ),
                        // Send Feedback Tab
                        RefreshIndicator(
                          onRefresh: () async => _refreshData(),
                          child: _buildSendFeedbackTab(context, feedbackJobs),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // ✅ FIXED: Removed the `const` keyword.
          // The `if (_isLoading)` condition makes this a runtime decision,
          // so the widget inside cannot be a compile-time constant.
          if (_isLoading)
            LoadingOverlay(
              isLoading: _isLoading,
              child: Container(
                color: Colors.black54,
                child: const ModernLoadingIndicator(message: 'Creating Job Card...'),
              ),
            ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    // Commented out to reduce UI noise
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text(message), backgroundColor: Colors.green),
    // );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () async {
                await AuthHelper.logout(context);
                // No need to navigate here; the logout method handles it.
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreateBookingCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.phone_in_talk_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📞 New Customer Call',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Schedule a service appointment',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ModernButton(
              text: 'Create New Booking',
              icon: Icons.event_note_rounded,
              onPressed: () async {
                final result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => const _CreateBookingDialog(),
                );

                if (result != null && result['success'] == true) {
                  final action = result['action'];
                  final booking = result['booking'];
                  final customerName = booking['customer_name'] ?? 'Customer';

                  if (action == 'assign_pudo') {
                    if (!context.mounted) return;
                    // Fetch pudoUsers and pudoWorkload again
                    final pudoUsers = await SupabaseService().getPudoUsers();
                    final pudoWorkload = await SupabaseService().getPudoWorkload();
                    if (!context.mounted) return;

                    final assigned = await showDialog<bool>(
                      context: context,
                      builder: (_) => _AssignBookingDialog(
                        booking: booking,
                        pudoUsers: pudoUsers,
                        pudoWorkload: pudoWorkload,
                      ),
                    );

                    if (assigned == true) {
                      if (!context.mounted) return;
                      _showSuccessDialog(context, customerName, action);
                      _refreshData();
                    } else if (assigned == false) {
                      // User cancelled the assignment, delete the booking
                      try {
                        await Supabase.instance.client
                            .from('bookings')
                            .delete()
                            .eq('id', booking['id']);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Booking cancelled and deleted'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error deleting booking: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    }
                  } else if (action == 'create_job_card') {
                    if (!context.mounted) return;
                    // Fetch executive users and workload data
                    final executiveUsers = await SupabaseService().getExecutiveUsers();
                    final workload = await SupabaseService().getExecutiveWorkload();
                    if (!context.mounted) return;

                    final assigned = await _assignExecutiveToBooking(booking, executiveUsers, workload);
                    if (assigned && context.mounted) {
                      _showSuccessDialog(context, customerName, 'assign_executive');
                    } else if (!assigned && context.mounted) {
                      // User cancelled the executive assignment, delete the booking
                      try {
                        await Supabase.instance.client
                            .from('bookings')
                            .delete()
                            .eq('id', booking['id']);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Job Card creation cancelled and booking deleted'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error deleting booking: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsTab(BuildContext context, List<Map<String, dynamic>> bookings, 
      List<Map<String, dynamic>> pudoUsers, String tabType) {
    if (bookings.isEmpty) {
      return _buildEmptyState(tabType);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final status = booking['status'];
        final assignedUser = booking['assigned_pudo'];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ModernCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.all(0),
              childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking['customer_name'],
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking['customer_phone'],
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (booking['pickup_address'] != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF6B7280)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                booking['pickup_address'],
                                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (booking['scheduled_time'] != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF6B7280)),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd MMM, hh:mm a').format(DateTime.parse(booking['scheduled_time'])),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (status == 'Assigned' && assignedUser != null)
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            Text(
                              'Assigned to: ${assignedUser['username']}',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      // Call Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final phone = booking['customer_phone'];
                            final uri = Uri.parse('tel:$phone');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          icon: const Icon(Icons.phone_rounded, size: 18),
                          label: const Text('Call Customer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
        );
      },
    );
  }


  Future<bool> _assignExecutiveToBooking(
    Map<String, dynamic> booking,
    List<Map<String, dynamic>> executiveUsers,
    List<Map<String, dynamic>> workload,
  ) async {
    // Show dialog to assign executive to walk-in booking
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AssignExecutiveToBookingDialog(
        booking: booking,
        executiveUsers: executiveUsers,
        workload: workload,
      ),
    );

    if (result == null || result['confirmed'] != true) return false;

    var success = false;
    final executiveId = result['executiveId'] as int?;

    if (executiveId == null) return false;

    try {
      setState(() => _isLoading = true);

      // Update booking status only (we'll track assignment differently)
      await supabase.from('bookings').update({
        'status': 'Assigned to Executive - ${executiveUsers.firstWhere((e) => e['id'] == executiveId)['username']}',
      }).eq('id', booking['id']);

      if (mounted) {
        _showSuccessSnackBar('Booking assigned to executive successfully!');
        _refreshData();
      }

      success = true;
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to assign booking: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    return success;
  }

  Widget _buildClickableWorkloadCard(BuildContext context, List<Map<String, dynamic>> workload) {
    return Column(
      children: [
        // Clickable header card
        InkWell(
          onTap: () {
            setState(() {
              _isWorkloadExpanded = !_isWorkloadExpanded;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.engineering_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '👷 Team Workload',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Current job assignments per executive',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isWorkloadExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: const Color(0xFF6B7280),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        
        // Expandable table
        if (_isWorkloadExpanded) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Executive Name',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      Text(
                        'Active Jobs',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
                ...workload.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final jobCount = item['active_jobs_count'] as int;
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: index < workload.length - 1
                          ? const Border(
                              bottom: BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 1,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              item['username'][0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['username'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: jobCount == 0
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : jobCount <= 3
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            jobCount.toString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: jobCount == 0
                                  ? const Color(0xFF10B981)
                                  : jobCount <= 3
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildServiceRemindersTab(BuildContext context, List<Map<String, dynamic>> serviceReminders) {
    if (serviceReminders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Service Reminders Due',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'All customers are up to date with their service schedules',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: serviceReminders.length,
      itemBuilder: (context, index) {
        final reminder = serviceReminders[index];
        return ServiceReminderCard(
          reminder: reminder,
          onStatusUpdated: _refreshData,
        );
      },
    );
  }

  Widget _buildSendFeedbackTab(BuildContext context, List<Map<String, dynamic>> feedbackJobs) {
    if (feedbackJobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.feedback_outlined,
                  size: 48,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Feedback Pending',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Jobs completed less than 3 days ago will appear here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: feedbackJobs.length,
      itemBuilder: (context, index) {
        final job = feedbackJobs[index];
        final vehicleInfo = job['vehicles'];
        final vehicleModel = vehicleInfo?['vehicle_models'];
        final vehicleNo = vehicleInfo?['Vehicle Number'] ?? 'N/A';
        final brandModel = '${vehicleModel?['brand'] ?? ''} ${vehicleModel?['Model name'] ?? ''}'.trim();
        final customerName = job['client_phone'] ?? 'Customer';
        final customerPhone = job['client_phone'] ?? '';
        final completionDate = job['completed_at'] != null
            ? DateFormat('dd MMM, yyyy').format(DateTime.parse(job['completed_at']))
            : 'N/A';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ModernCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with vehicle info
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
                          ),
                          const SizedBox(height: 4),
                          Text(
                            brandModel.isNotEmpty ? brandModel : 'Vehicle',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Customer and completion info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Text(
                            'Customer: $customerName',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Text(
                            'Completed: $completionDate',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    // Call button
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.phone_rounded, size: 18),
                        label: const Text('Call'),
                        onPressed: customerPhone.isNotEmpty
                            ? () async {
                                final uri = Uri.parse('tel:$customerPhone');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send feedback button
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
                        label: const Text('Send Feedback'),
                        onPressed: customerPhone.isNotEmpty
                            ? () => _sendFeedbackMessage(job['id'], customerPhone, vehicleNo)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Sends feedback message via WhatsApp
  Future<void> _sendFeedbackMessage(int reportId, String customerPhone, String vehicleNo) async {
    final feedbackUrl = '${AppConstants.feedbackBaseUrl}$reportId';
    final message = 'Dear Customer,\n\n'
        'Thank you for choosing AutoFix for your vehicle $vehicleNo. '
        'We would be grateful if you could share your experience with us by clicking the link below:\n\n'
        '$feedbackUrl\n\n'
        'Your feedback helps us improve our service.\n\n'
        'Best regards,\nAutoFix Team';

    // Normalize phone to international format without '+' for WA
    final digits = customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    String phoneForWa;
    if (digits.startsWith('91') && digits.length >= 12) {
      // Already includes country code
      phoneForWa = digits;
    } else if (digits.length == 10) {
      // Local Indian number
      phoneForWa = '91$digits';
    } else if (digits.startsWith('0') && digits.length == 11) {
      // Leading zero local format
      phoneForWa = '91${digits.substring(1)}';
    } else {
      // Fallback: use digits as-is
      phoneForWa = digits;
    }

    // Try multiple WhatsApp URL schemes for better compatibility
    final encodedMessage = Uri.encodeComponent(message);
    final urls = [
      Uri.parse('whatsapp://send?phone=$phoneForWa&text=$encodedMessage'),
      Uri.parse('https://wa.me/$phoneForWa?text=$encodedMessage'),
      Uri.parse('https://api.whatsapp.com/send?phone=$phoneForWa&text=$encodedMessage'),
    ];

    bool launched = false;
    
    try {
      // Try each URL scheme until one works
      for (final url in urls) {
        try {
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
            launched = true;
            break;
          }
        } catch (e) {
          // Continue to next URL scheme
          continue;
        }
      }
      
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch WhatsApp. Please ensure it is installed.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching WhatsApp: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Builds the job assignment tab for jobs awaiting executive assignment
  Widget _buildJobAssignmentTab(BuildContext context, List<Map<String, dynamic>> jobs, 
      List<Map<String, dynamic>> executiveUsers, List<Map<String, dynamic>> workload) {
    if (jobs.isEmpty) {
      return _buildEmptyState('assign_executive');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final vehicleInfo = job['vehicles'];
        final vehicleModel = vehicleInfo?['vehicle_models'];
        final vehicleNo = vehicleInfo?['Vehicle Number'] ?? 'N/A';
        final brandModel = '${vehicleModel?['brand'] ?? ''} ${vehicleModel?['Model name'] ?? ''}'.trim();
        final createdBy = job['created_by_pudo']?['username'] ?? 'PUDO User';
        final createdAt = job['created_at'] != null 
            ? DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(job['created_at']))
            : 'N/A';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ModernCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with vehicle info and assign button
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
                          ),
                          const SizedBox(height: 4),
                          Text(
                            brandModel.isNotEmpty ? brandModel : 'Vehicle',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: const Text(
                        'Assign',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _showAssignExecutiveDialog(job, executiveUsers, workload),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Additional info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Text(
                            'Customer: ${job['client_phone'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Text(
                            'Phone: ${job['client_phone'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Text(
                            'Created by: $createdBy',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Text(
                            'Created: $createdAt',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shows dialog to assign executive to a job
  void _showAssignExecutiveDialog(Map<String, dynamic> job, 
      List<Map<String, dynamic>> executiveUsers, List<Map<String, dynamic>> workload) {
    showDialog(
      context: context,
      builder: (context) => _AssignExecutiveDialog(
        job: job,
        executiveUsers: executiveUsers,
        workload: workload,
        onAssigned: _refreshData,
      ),
    );
  }

  Widget _buildEmptyState(String tabType) {
    String message;
    String subtitle;
    IconData icon;

    switch (tabType) {
      case 'assigned':
        message = 'No assigned bookings';
        subtitle = 'Bookings assigned to pickup users will appear here';
        icon = Icons.person_add_rounded;
        break;
      case 'unassigned':
        message = 'No unassigned job cards';
        subtitle = 'Walk-in job cards will appear here';
        icon = Icons.assignment_outlined;
        break;
      case 'assign_executive':
        message = 'No jobs awaiting assignment';
        subtitle = 'Jobs created by pickup users will appear here for executive assignment';
        icon = Icons.assignment_ind_outlined;
        break;
      default:
        message = 'No data available';
        subtitle = 'Pull down to refresh';
        icon = Icons.info_outline;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// Dialog for creating a new booking
class _CreateBookingDialog extends StatefulWidget {
  const _CreateBookingDialog();

  @override
  State<_CreateBookingDialog> createState() => _CreateBookingDialogState();
}

class _CreateBookingDialogState extends State<_CreateBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _timeController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _isLoading = false;

  // NEW: Track what action to take after saving
  String _bookingAction = 'assign_pudo'; // Options: 'assign_pudo', 'create_job_card'
  
  @override
  void initState() {
    super.initState();
    // Set default booking action based on PUDO module availability
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminSettings = Provider.of<AdminSettingsProvider>(context, listen: false);
      if (!adminSettings.featurePudoModule) {
        setState(() {
          _bookingAction = 'create_job_card';
        });
      }
    });
  }


  Future<void> _createBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final telecaller = Provider
        .of<UserProvider>(context, listen: false)
        .user;
    if (telecaller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error: Could not identify current user.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2)),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Create the booking
      final response = await Supabase.instance.client
          .from('bookings')
          .insert({
            'customer_name': _nameController.text,
            'customer_phone': _phoneController.text,
            'pickup_address': _addressController.text.isNotEmpty
                ? _addressController.text
                : null,
            'scheduled_time': _selectedDateTime?.toIso8601String(),
            'created_by_telecaller_id': telecaller['id'],
            'status': 'Pending',
          })
          .select()
          .single();

       if (!mounted) return;

       // Return booking data and selected action
      Navigator.of(context).pop({
        'success': true,
        'action': _bookingAction,
        'booking': response,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create booking: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.event_note,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Create New Booking',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Customer Name
                const FormLabel(text: 'Customer Name', isRequired: true),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter customer name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),

                // Customer Phone
                const FormLabel(text: 'Customer Phone', isRequired: true),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    hintText: 'Enter 10-digit phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (value) {
                    if (value!.isEmpty) return 'Please enter a phone number';
                    if (value.length != 10) return 'Phone must be 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Pickup Address
                const FormLabel(text: 'Pickup Address (Optional)'),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    hintText: 'Enter pickup address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Scheduled Time
                const FormLabel(text: 'Scheduled Time (Optional)'),
                TextFormField(
                  controller: _timeController,
                  decoration: const InputDecoration(
                    hintText: 'Select date and time',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date == null) return;

                    if (!context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time == null) return;

                    setState(() {
                      _selectedDateTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                      _timeController.text = DateFormat('dd MMM yyyy, hh:mm a')
                          .format(_selectedDateTime!);
                    });
                  },
                ),
                const SizedBox(height: 24),

                 // NEW: Next Action Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMd),
                    border: Border.all(color: AppTheme.primaryLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.task_alt, color: AppTheme.primaryColor, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'What happens next?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                                             // Option 1: Assign to PUDO (only show if PUDO module is enabled)
                      Consumer<AdminSettingsProvider>(
                        builder: (context, adminSettings, _) {
                          if (!adminSettings.featurePudoModule) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            children: [
                              RadioMenuButton<String>(
                                value: 'assign_pudo',
                                groupValue: _bookingAction,
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _bookingAction = value);
                                },
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.person_add, size: 18, color: AppTheme.primaryColor),
                                        SizedBox(width: 8),
                                        Text('Assign to PUDO for Pickup'),
                                      ],
                                    ),
                                    SizedBox(height: 2),
                                Text(
                                  'Vehicle will be picked up by assigned user',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                              const Divider(height: 8),
                            ],
                          );
                        },
                      ),
                      RadioMenuButton<String>(
                        value: 'create_job_card',
                        groupValue: _bookingAction,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _bookingAction = value);
                        },
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.assignment, size: 18, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Create Job Card (Walk-in)'),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Customer brings vehicle themselves',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createBooking,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Booking'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// Dialog for assigning a booking
class _AssignBookingDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  final List<Map<String, dynamic>> pudoUsers;
  final List<Map<String, dynamic>> pudoWorkload;

  const _AssignBookingDialog({required this.booking, required this.pudoUsers, required this.pudoWorkload});

  @override
  State<_AssignBookingDialog> createState() => _AssignBookingDialogState();
}

class _AssignBookingDialogState extends State<_AssignBookingDialog> {
  int? _selectedPudoId;
  bool _isLoading = false;

  Future<void> _assignBooking() async {
    if (_selectedPudoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user to assign.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      await SupabaseService().assignBooking(
          widget.booking['id'], _selectedPudoId!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign booking: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Booking for ${widget.booking['customer_name']}'),
      content: DropdownButtonFormField<int>(
        initialValue: _selectedPudoId,
        hint: const Text('Select Pick-up User'),
        items: (() {
          // Create a list of users with their workload data
          final usersWithWorkload = widget.pudoUsers.map((user) {
            final workloadEntry = widget.pudoWorkload.firstWhere(
              (entry) => entry['id'] == user['id'],
              orElse: () => {'id': user['id'], 'username': user['username'], 'active_bookings_count': 0},
            );
            final bookingCount = workloadEntry['active_bookings_count'] as int? ?? 0;
            return {
              'user': user,
              'workload': bookingCount,
            };
          }).toList();
          
          // Sort by workload in ascending order
          usersWithWorkload.sort((a, b) => (a['workload'] as int).compareTo(b['workload'] as int));
          
          return usersWithWorkload.map((entry) {
            final user = entry['user'] as Map<String, dynamic>;
            final bookingCount = entry['workload'] as int;
            
            return DropdownMenuItem<int>(
              value: user['id'],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(user['username']),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: bookingCount == 0
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : bookingCount <= 3
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                              : const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      bookingCount.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: bookingCount == 0
                            ? const Color(0xFF10B981)
                            : bookingCount <= 3
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        })(),
        onChanged: (value) {
          setState(() {
            _selectedPudoId = value;
          });
        },
        validator: (value) => value == null ? 'Please select a user' : null,
      ),
      actions: [
        TextButton(
          onPressed: () async {
            // Show confirmation dialog when canceling
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Assignment'),
                content: const Text('Are you sure you want to cancel? This booking will not be saved.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
            );
            
            if (confirmed == true) {
              if (mounted) {
                Navigator.of(context).pop(false); // Return false to indicate cancellation
              }
            }
            // If confirmed == false or null, stay on the PUDO selection dialog
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _assignBooking,
          child: _isLoading ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ) : const Text('Assign'),
        ),
      ],
    );
  }
}

// Dialog for assigning executive to a job
class _AssignExecutiveDialog extends StatefulWidget {
  final Map<String, dynamic> job;
  final List<Map<String, dynamic>> executiveUsers;
  final List<Map<String, dynamic>> workload;
  final VoidCallback onAssigned;

  const _AssignExecutiveDialog({
    required this.job,
    required this.executiveUsers,
    required this.workload,
    required this.onAssigned,
  });

  @override
  State<_AssignExecutiveDialog> createState() => _AssignExecutiveDialogState();
}

class _AssignExecutiveDialogState extends State<_AssignExecutiveDialog> {
  int? _selectedExecutiveId;
  bool _isLoading = false;

  Future<void> _assignExecutive() async {
    if (_selectedExecutiveId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an executive to assign.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (kDebugMode) {
      print('🔄 Starting job assignment: Job ${widget.job['id']} to Executive $_selectedExecutiveId');
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService().assignJobToExecutive(widget.job['id'], _selectedExecutiveId!);
      
      if (kDebugMode) {
        print('✅ Job assignment completed successfully');
      }
      
      if (mounted) {
        Navigator.of(context).pop();
        // Commented out to reduce UI noise
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('✓ Job assigned successfully!'),
        //     backgroundColor: Colors.green,
        //   ),
        // );
        
        if (kDebugMode) {
          print('🔄 Calling onAssigned callback');
        }
        widget.onAssigned();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Job assignment failed: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign job: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleNo = widget.job['vehicles']?['Vehicle Number'] ?? 'N/A';
    
    return AlertDialog(
      title: Text('Assign Executive for $vehicleNo'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer: ${widget.job['client_phone'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
            value: _selectedExecutiveId,
            hint: const Text('Select Executive'),
            items: (() {
              // Create a list of executives with their workload data
              final executivesWithWorkload = widget.executiveUsers.map((executive) {
                final workloadEntry = widget.workload.firstWhere(
                  (entry) => entry['id'] == executive['id'],
                  orElse: () => {'id': executive['id'], 'username': executive['username'], 'active_jobs_count': 0},
                );
                final jobCount = workloadEntry['active_jobs_count'] as int? ?? 0;
                return {
                  'executive': executive,
                  'workload': jobCount,
                };
              }).toList();

              // Sort by workload (ascending - least busy first)
              executivesWithWorkload.sort((a, b) => (a['workload'] as int).compareTo(b['workload'] as int));

              return executivesWithWorkload.map<DropdownMenuItem<int>>((item) {
                final executive = item['executive'] as Map<String, dynamic>;
                final jobCount = item['workload'] as int;
                return DropdownMenuItem<int>(
                  value: executive['id'],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          executive['username'],
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: jobCount == 0
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : jobCount <= 3
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          jobCount.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: jobCount == 0
                                ? const Color(0xFF10B981)
                                : jobCount <= 3
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            })(),
            onChanged: (value) {
              setState(() {
                _selectedExecutiveId = value;
              });
            },
            validator: (value) => value == null ? 'Please select an executive' : null,
          ),
        ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _assignExecutive,
          child: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign'),
        ),
      ],
    );
  }
}

// Dialog for assigning executives to walk-in bookings
class _AssignExecutiveToBookingDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  final List<Map<String, dynamic>> executiveUsers;
  final List<Map<String, dynamic>> workload;

  const _AssignExecutiveToBookingDialog({
    required this.booking,
    required this.executiveUsers,
    required this.workload,
  });

  @override
  State<_AssignExecutiveToBookingDialog> createState() => _AssignExecutiveToBookingDialogState();
}

class _AssignExecutiveToBookingDialogState extends State<_AssignExecutiveToBookingDialog> {
  int? _selectedExecutiveId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final customerName = widget.booking['customer_name'] ?? 'Customer';
    
    return AlertDialog(
      title: Text('Assign Executive for $customerName'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select an executive to handle this walk-in booking. The booking will appear in their "Direct Bookings" tab.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedExecutiveId,
              hint: const Text('Select Executive'),
              items: (() {
                // Create a list of executives with their workload data
                final executivesWithWorkload = widget.executiveUsers.map((executive) {
                  final workloadEntry = widget.workload.firstWhere(
                    (entry) => entry['id'] == executive['id'],
                    orElse: () => {'id': executive['id'], 'username': executive['username'], 'active_jobs_count': 0},
                  );
                  final jobCount = workloadEntry['active_jobs_count'] as int? ?? 0;
                  return {
                    'executive': executive,
                    'workload': jobCount,
                  };
                }).toList();

                // Sort by workload (ascending - least busy first)
                executivesWithWorkload.sort((a, b) => (a['workload'] as int).compareTo(b['workload'] as int));

                return executivesWithWorkload.map<DropdownMenuItem<int>>((item) {
                  final executive = item['executive'] as Map<String, dynamic>;
                  final jobCount = item['workload'] as int;
                  return DropdownMenuItem<int>(
                    value: executive['id'],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            executive['username'],
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: jobCount == 0
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : jobCount <= 3
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            jobCount.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: jobCount == 0
                                  ? const Color(0xFF10B981)
                                  : jobCount <= 3
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              })(),
              onChanged: (value) {
                setState(() {
                  _selectedExecutiveId = value;
                });
              },
              validator: (value) => value == null ? 'Please select an executive' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            // Show confirmation dialog when canceling
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Assignment'),
                content: const Text('Are you sure you want to cancel? This booking will not be saved.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
            );
            
            if (confirmed == true) {
              if (mounted) {
                Navigator.of(context).pop(); // Return null to indicate cancellation
              }
            }
            // If confirmed == false or null, stay on the executive selection dialog
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () {
            if (_selectedExecutiveId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an executive to assign.'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            
            Navigator.of(context).pop({
              'confirmed': true,
              'executiveId': _selectedExecutiveId,
            });
          },
          child: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign'),
        ),
      ],
    );
  }
}