// lib/screens/inspector_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';
import '../providers/admin_settings_provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_helper.dart';
import '../utils/app_constants.dart';
import 'profile_screen.dart';
// Import EmptyDisplay


class InspectorScreen extends StatefulWidget {
  const InspectorScreen({super.key});

  @override
  State<InspectorScreen> createState() => _InspectorScreenState();
}

class _InspectorScreenState extends State<InspectorScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allInspectionQueue = []; // Store original list
  List<Map<String, dynamic>> _filteredInspectionQueue = []; // List to display
  bool _isLoading = false;

  // ✅ Add Search Controller
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInspectionQueue();
    // ✅ Add listener for search
    _searchController.addListener(_filterQueue);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterQueue); // ✅ Remove listener
    _searchController.dispose(); // ✅ Dispose controller
    super.dispose();
  }

  Future<void> _loadInspectionQueue() async {
    setState(() => _isLoading = true); // Set loading state at the beginning

    try {
      final response = await supabase
          .from('reports')
          .select('''
            id,
            complaint,
            suggested,
            approved,
            inspection_remarks,
            vehicles!reports_vehicle_fk("Guid", "Vehicle Number", vehicle_name),
            executive:executive_id(username)
          ''')
          .eq('status', 'pending_inspection')
          .order('created_at', ascending: true);

      setState(() {
        _allInspectionQueue = List<Map<String, dynamic>>.from(response);
        _filteredInspectionQueue = _allInspectionQueue; // Initially show all
        _isLoading = false; // Set loading false here
      });
    } catch (e) {
      _showError('Could not fetch inspection queue: $e');
      if (mounted) setState(() => _isLoading = false);
    }
    // Remove finally block that sets loading false, it's done above now
  }

  // ✅ New method to filter the list
  void _filterQueue() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredInspectionQueue = _allInspectionQueue;
      } else {
        _filteredInspectionQueue = _allInspectionQueue.where((report) {
          final vehicleNo = report['vehicles']?['Vehicle Number']?.toString().toLowerCase() ?? '';
          final executiveName = report['executive']?['username']?.toString().toLowerCase() ?? '';
          return vehicleNo.contains(query) || executiveName.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _handleInspection(int reportId, String outcome, String vehicleNo) async {
    if (outcome == 'rejected') {
      _showRemarksDialog(reportId, vehicleNo);
    } else {
      _confirmApproval(reportId, vehicleNo);
    }
  }

  void _showRemarksDialog(int reportId, String vehicleNo) {
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inspection Remarks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm rejection for vehicle $vehicleNo.'),
            const SizedBox(height: 16),
            TextField(
              controller: remarksController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Remarks (Required)',
                hintText: 'Enter remarks...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final remarks = remarksController.text.trim();
              if (remarks.isEmpty) {
                _showError('Remarks are required when rejecting a job.');
                return;
              }
              Navigator.pop(context);
              _executeInspection(reportId, 'rejected', remarks);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  /// Determines the next status after inspection approval based on enabled modules
  String _getPostInspectionStatus(AdminSettingsProvider adminSettings) {
    // If wash module is enabled, go to wash after inspection
    if (adminSettings.featureWashModule) {
      return 'inspection_approved'; // This will show in "Not Washed" section for wash decision
    }
    // If wash is disabled, mark as completed
    else {
      return AppConstants.statusCompleted;
    }
  }

  Future<void> _confirmApproval(int reportId, String vehicleNo) async {
    final confirmed = await _showConfirmDialog(
      'Approve Inspection',
      'Confirm approval for vehicle $vehicleNo?',
      confirmColor: Colors.green,
    );

    if (confirmed == true) {
      final adminSettings = Provider.of<AdminSettingsProvider>(context, listen: false);
      final nextStatus = _getPostInspectionStatus(adminSettings);
      _executeInspection(reportId, nextStatus, '');
    }
  }

  Future<void> _executeInspection(int reportId, String outcome, String remarks) async {
    // Get the current user from the provider instead of a global variable.
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;

    if (currentUser == null) {
      _showError('Session expired. Please log in again.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final updateData = {
        'status': outcome,
        'inspector_id': currentUser['id'], // Use the ID from the provider
        'inspection_remarks': remarks,
        'inspection_date': DateTime.now().toIso8601String(),
      };

      await supabase.from('reports').update(updateData).eq('id', reportId);

      final message = outcome == AppConstants.statusCompleted
          ? 'Inspection approved. Job marked as completed.'
          : outcome == 'inspection_approved'
              ? 'Inspection approved. Vehicle sent for wash decision.'
              : 'Inspection rejected. Vehicle sent back to executive.';

      _showSuccess(message);
      _loadInspectionQueue();
    } catch (e) {
      _showError('Failed to update status: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showJobDetails(Map<String, dynamic> report) {
    final vehicleNo = report['vehicles']?['Vehicle Number'] ?? 'N/A';
    final executiveName = report['executive']?['username'] ?? 'N/A';

    List<Map<String, dynamic>> approvedItems = [];
    try {
      if (report['approved'] != null && report['approved'] != '[]') {
        final approved = jsonDecode(report['approved']) as List;
        approvedItems = approved.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      // Handle parsing error
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  mainAxisSize: MainAxisSize.min,
  children: [
    SizedBox(width: 48), // Matches the width of IconButton to keep text centered
    const Text('Inspection Details'),
    Padding(
      padding: const EdgeInsets.only(right: 2),
      child: IconButton(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: Icon(Icons.close_rounded,),
      ),
    ),
  ],
),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Vehicle Number', vehicleNo),
              const SizedBox(height: 8),
              _buildDetailRow('Executive', executiveName),
              const Divider(height: 24),
              const Text(
                'Customer Approved Repairs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (approvedItems.isEmpty)
                const Text(
                  'No services were approved by the customer for this job.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: approvedItems.map((item) {
                      final text = item['text'] ?? 'N/A';
                      final amount = (item['amount'] ?? 0).toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $text (₹${amount.toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
        ),
        actions: [
          // TextButton(
          //   onPressed: () => Navigator.pop(context),
          //   child: const Text('Close'),
          // ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleInspection(report['id'], 'rejected', vehicleNo);
            },
            
            child: const Text('Reject',style: TextStyle(
              color: Colors.red
            ),),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleInspection(report['id'], 'inspection_approved', vehicleNo);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    final buttonText = await AuthHelper.getLogoutButtonText();

    final confirmed = await _showConfirmDialog(
      buttonText,
      'Are you sure?',
    );

    if (confirmed != true) return;

    if (mounted) {
      await AuthHelper.logout(context);
    }
  }

  Future<bool?> _showConfirmDialog(
      String title,
      String message, {
        Color confirmColor = AppTheme.primaryColor,
      }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    // Commented out to reduce UI noise
    // if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     backgroundColor: Colors.green,
    //     behavior: SnackBarBehavior.floating,
    //     shape: RoundedRectangleBorder(
    //       borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
    //     ),
    //     margin: const EdgeInsets.all(16),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Inspector',
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.primaryColor),
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else if (value == 'logout') {
                await _logout();
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
      body: RefreshIndicator(
        onRefresh: _loadInspectionQueue,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator()) // Keep loader as is
            : Column(
                // Wrap in Column to add Search Bar
                // ✅ Wrap in Column to add Search Bar
                children: [
                  // ✅ Add Search Bar
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMd)
                        .copyWith(bottom: AppTheme.spacingSm), // Adjust padding
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by Vehicle No or Executive...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  // _filterQueue will be called by listener
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  // ✅ Existing List content inside Expanded
                  Expanded(
                    child: _filteredInspectionQueue.isEmpty
                        ? _buildEmptyState(_searchController.text.isNotEmpty) // Pass search status
                        : _buildInspectionList(),
                  ),
                ],
              ),
      ),
    );
  }

  // ✅ Modify empty state to show different message if searching
  Widget _buildEmptyState(bool isSearching) {
    return Center(
      child: Padding(
        // Added padding
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.fact_check, // Different icon
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? 'No vehicles found matching your search' // Search message
                  : 'No vehicles in inspection queue', // Default message
              textAlign: TextAlign.center, // Center align text
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching ? 'Try a different search term.' : 'Pull down to refresh', // Different subtitle
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildInspectionList() {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16), // Adjust padding
      // Use filtered list
      itemCount: _filteredInspectionQueue.length,
      itemBuilder: (context, index) {
        final report = _filteredInspectionQueue[index];
        final vehicle = report['vehicles'];
        final executive = report['executive'];

        final vehicleNo = vehicle?['Vehicle Number'] ?? 'N/A';
        final vehicleName = vehicle?['vehicle_name'] ?? '';
        final executiveName = executive?['username'] ?? 'N/A';

        // Check if it's a re-inspection
        final isReinspection = report['inspection_remarks'] != null &&
            report['inspection_remarks'].toString().isNotEmpty;

        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              vehicleNo,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (isReinspection)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Re-inspection',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (vehicleName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              vehicleName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'From: $executiveName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showJobDetails(report),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}