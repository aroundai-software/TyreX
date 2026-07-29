// COMPLETE REPLACEMENT for reports_analytics_screen.dart
// This fixes the single-column display issue

// lib/screens/admin/reports_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:io' as io;
import 'package:universal_html/html.dart' as html;
import '../../theme/app_theme.dart';
import '../../providers/admin_settings_provider.dart';
import 'package:provider/provider.dart';
import '../../widgets/modern_card.dart';
import '../../widgets/modern_input.dart';
import '../../widgets/modern_button.dart';
import '../../widgets/modern_loading.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _allReports = [];
  List<Map<String, dynamic>> _filteredReports = [];
  bool _isLoading = false;

  // Filter controllers
  final _vehicleNoController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _executiveController = TextEditingController();
  final _fromDateController = TextEditingController();
  final _toDateController = TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedStatus;

  // Scroll controllers
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Pagination
  static const int _pageSize = 50;
  int _currentPage = 1;
  int get _totalPages => (_filteredReports.length / _pageSize).ceil();
  List<Map<String, dynamic>> get _paginatedReports {
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize;
    return _filteredReports.sublist(
      startIndex,
      endIndex > _filteredReports.length ? _filteredReports.length : endIndex,
    );
  }

  Future<void> _exportCsv() async {
    try {
      if (_filteredReports.isEmpty) {
        _showError('No reports to export.');
        return;
      }

      // Determine visible columns similarly to table
      List<String> visibleColumns = [];
      try {
        final settingsProvider = context.read<AdminSettingsProvider>();
        visibleColumns = settingsProvider.visibleReportColumns;
      } catch (_) {
        visibleColumns = [
          'vehicle_no',
          'vehicle_name',
          'client_name',
          'executive',
          'date_time',
          'status',
          'complaint',
          'approved',
        ];
      }
      if (visibleColumns.isEmpty) {
        visibleColumns = [
          'vehicle_no',
          'vehicle_name',
          'client_name',
          'executive',
          'date_time',
          'status',
          'complaint',
          'approved',
        ];
      }

      // Header labels mapping
      final Map<String, String> headerLabels = {
        'vehicle_no': 'Vehicle No',
        'vehicle_name': 'Vehicle Name',
        'model': 'Model',
        'brand': 'Brand',
        'client_name': 'Owner Name',
        'client_phone': 'Client Phone',
        'executive': 'Executive',
        'date_time': 'Date & Time',
        'status': 'Status',
        'complaint': 'Complaint',
        'approved': 'Approved',
        'media': 'Media',
      };

      final headers = visibleColumns
          .where((k) => headerLabels.containsKey(k))
          .map((k) => headerLabels[k]!)
          .toList();

      final List<List<dynamic>> rows = [headers];

      for (final report in _filteredReports) {
        final vehicle = report['vehicles'];
        final model = vehicle?['vehicle_models'];
        final Map<String, dynamic> values = {
          'vehicle_no': vehicle?['Vehicle Number'],
          'vehicle_name': vehicle?['vehicle_name'],
          'model': model?['Model name'],
          'brand': model?['brand'],
          'client_name': report['Owner name'],
          'client_phone': report['client_phone'],
          'executive': report['executive']?['username'],
          'date_time': DateFormat('dd/MM/yy HH:mm')
              .format(DateTime.parse(report['created_at'])),
          'status': _formatStatus(report['status']),
          'complaint': _formatJsonCell(report['complaint']),
          'approved': _formatJsonCell(report['approved']),
          'media': 'Local',
        };

        rows.add(visibleColumns
            .where((k) => headerLabels.containsKey(k))
            .map((k) => values[k] ?? '')
            .toList());
      }

      final String csv = const ListToCsvConverter().convert(rows);
      final filename = 'reports_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
      if (kIsWeb) {
        final blob = html.Blob([csv], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final file = io.File('${dir.path}/$filename');
        await file.writeAsString(csv, flush: true);
        await Share.shareXFiles([XFile(file.path, name: filename, mimeType: 'text/csv')]);
      }
    } catch (e) {
      _showError('Export failed: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _vehicleNoController.dispose();
    _clientNameController.dispose();
    _executiveController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      final response = await supabase.from('reports').select('''
            id, created_at, status, complaint, suggested, approved,
            "Owner name", client_phone, odometer_reading,
            customer_feedback_text, customer_feedback_audio,
            marks, gdrive_folder_url,
            vehicles!reports_vehicle_fk(
              "Guid", "Vehicle Number", vehicle_name, "Color", "Engine Number", "Chasis Number",
              vehicle_models!inner(brand, "Model name")
            ),
            executive:executive_id(username),
            inspector:inspector_id(username)
          ''').order('created_at', ascending: false);

      setState(() {
        _allReports = List<Map<String, dynamic>>.from(response);
        _filteredReports = _allReports;
      });
    } catch (e) {
      _showError('Failed to load reports: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allReports);

    // Vehicle number filter
    if (_vehicleNoController.text.isNotEmpty) {
      final searchTerm = _vehicleNoController.text.toUpperCase();
      filtered = filtered.where((report) {
        final vehicleNo =
            report['vehicles']?['Vehicle Number']?.toString().toUpperCase() ?? '';
        return vehicleNo.contains(searchTerm);
      }).toList();
    }

    // Client name filter
    if (_clientNameController.text.isNotEmpty) {
      final searchTerm = _clientNameController.text.toLowerCase();
      filtered = filtered.where((report) {
        final clientName =
            report['client_phone']?.toString().toLowerCase() ?? '';
        return clientName.contains(searchTerm);
      }).toList();
    }

    // Executive filter
    if (_executiveController.text.isNotEmpty) {
      final searchTerm = _executiveController.text.toLowerCase();
      filtered = filtered.where((report) {
        final executive =
            report['executive']?['username']?.toString().toLowerCase() ?? '';
        return executive.contains(searchTerm);
      }).toList();
    }

    // Status filter
    if (_selectedStatus != null && _selectedStatus != 'All') {
      filtered = filtered
          .where((report) => report['status'] == _selectedStatus)
          .toList();
    }

    // Date range filter
    if (_fromDate != null) {
      filtered = filtered.where((report) {
        final reportDate = DateTime.parse(report['created_at']);
        return !reportDate.isBefore(_fromDate!);
      }).toList();
    }

    if (_toDate != null) {
      final endOfDay =
          DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
      filtered = filtered.where((report) {
        final reportDate = DateTime.parse(report['created_at']);
        return !reportDate.isAfter(endOfDay);
      }).toList();
    }

    setState(() {
      _filteredReports = filtered;
      _currentPage = 1; // Reset to first page
    });
  }

  void _clearFilters() {
    setState(() {
      _vehicleNoController.clear();
      _clientNameController.clear();
      _executiveController.clear();
      _fromDateController.clear();
      _toDateController.clear();
      _fromDate = null;
      _toDate = null;
      _selectedStatus = null;
      _filteredReports = _allReports;
      _currentPage = 1;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? (_fromDate ?? DateTime.now())
          : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          _fromDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        } else {
          _toDate = picked;
          _toDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        }
      });
      _applyFilters();
    }
  }

  String _formatJsonCell(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty || jsonString == '[]') {
      return 'N/A';
    }
    try {
      final list = jsonDecode(jsonString) as List;
      if (list.isEmpty) return 'N/A';
      return list.map((item) {
        if (item is Map) {
          return item['text']?.toString() ?? item.toString();
        }
        return item.toString();
      }).join(', ');
    } catch (e) {
      return 'Invalid Data';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Ongoing':
        return Colors.orange;
      case 'Not Started':
        return Colors.red;
      case 'pending_inspection':
        return Colors.blue;
      case 'inspection_approved':
        return Colors.teal;
      case 'rejected':
        return Colors.red.shade700;
      case 'Sent To Wash':
        return Colors.purple;
      case 'Wash Completed':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatStatus(String? status) {
    if (status == null) return 'N/A';
    // Convert snake_case to Title Case
    return status
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Reports & Service History'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCards(),
            const SizedBox(height: 16),
            _buildFiltersCard(),
            const SizedBox(height: 16),
            _buildReportsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalReports = _allReports.length;
    final completedReports =
        _allReports.where((r) => r['status'] == 'Completed').length;
    final ongoingReports =
        _allReports.where((r) => r['status'] == 'Ongoing').length;
    final pendingReports =
        _allReports.where((r) => r['status'] == 'Not Started').length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Reports',
            totalReports.toString(),
            Icons.assessment,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Completed',
            completedReports.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Ongoing',
            ongoingReports.toString(),
            Icons.pending,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Not Started',
            pendingReports.toString(),
            Icons.schedule,
            Colors.red,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return ModernCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ).animate().fadeIn(duration: 400.ms).scale(),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear All'),
              ),
            ],
          ),
          const Divider(height: 24),

          // Date Range
          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  controller: _fromDateController,
                  label: 'From Date',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 20),
                    onPressed: () => _selectDate(context, true),
                  ),
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ModernTextField(
                  controller: _toDateController,
                  label: 'To Date',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 20),
                    onPressed: () => _selectDate(context, false),
                  ),
                  readOnly: true,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 16),

          // Search Fields
          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  controller: _vehicleNoController,
                  label: 'Vehicle Number',
                  prefixIcon: const Icon(Icons.directions_car, size: 20),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ModernTextField(
                  controller: _clientNameController,
                  label: 'Client Name',
                  prefixIcon: const Icon(Icons.person, size: 20),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 16),

          // Executive and Status
          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  controller: _executiveController,
                  label: 'Executive',
                  prefixIcon: const Icon(Icons.manage_accounts, size: 20),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Consumer<AdminSettingsProvider>(
                    builder: (context, adminSettings, _) {
                      // Build status dropdown items dynamically based on enabled modules
                      List<DropdownMenuItem<String>> statusItems = [
                        const DropdownMenuItem(value: null, child: Text('All Statuses')),
                        const DropdownMenuItem(value: 'Not Started', child: Text('Not Started')),
                        const DropdownMenuItem(value: 'Ongoing', child: Text('Ongoing')),
                      ];
                      
                      // Add inspection-related statuses only if inspection module is enabled
                      if (adminSettings.featureInspectionModule) {
                        statusItems.addAll([
                          const DropdownMenuItem(value: 'pending_inspection', child: Text('Pending Inspection')),
                          const DropdownMenuItem(value: 'inspection_approved', child: Text('Inspection Approved')),
                          const DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                        ]);
                      }
                      
                      // Add wash-related statuses only if wash module is enabled
                      if (adminSettings.featureWashModule) {
                        statusItems.addAll([
                          const DropdownMenuItem(value: 'Sent To Wash', child: Text('Sent To Wash')),
                          const DropdownMenuItem(value: 'Wash Completed', child: Text('Wash Completed')),
                        ]);
                      }
                      
                      statusItems.add(const DropdownMenuItem(value: 'Completed', child: Text('Completed')));
                      
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(Icons.filter_list, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        items: statusItems,
                        onChanged: (value) {
                          setState(() => _selectedStatus = value);
                          _applyFilters();
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 16),

          // Results summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Showing ${_filteredReports.length} of ${_allReports.length} reports',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.2, end: 0);
  }

  Widget _buildReportsTable() {
    if (_isLoading) {
      return const ModernLoadingIndicator(message: 'Loading reports...');
    }

    if (_filteredReports.isEmpty) {
      return ModernCard(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No reports found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try adjusting your filters',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // FIXED: Get visible columns with proper fallback
    List<String> visibleColumns = [];
    try {
      final settingsProvider = context.watch<AdminSettingsProvider>();
      visibleColumns = settingsProvider.visibleReportColumns;
      debugPrint('📊 Loaded visible columns from settings: $visibleColumns');
    } catch (e) {
      debugPrint('⚠️ Could not load settings provider: $e');
      // Use hardcoded default if provider fails
      visibleColumns = [
        'vehicle_no',
        'vehicle_name',
        'client_name',
        'executive',
        'date_time',
        'status',
        'complaint',
        'approved',
        'media'
      ];
    }

    // Ensure we have at least some columns
    if (visibleColumns.isEmpty) {
      visibleColumns = [
        'vehicle_no',
        'vehicle_name',
        'client_name',
        'executive',
        'date_time',
        'status',
        'complaint',
        'approved',
        'media'
      ];
      debugPrint('⚠️ No columns configured, using defaults');
    }

    return ModernCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Service History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    // Pagination controls
                    if (_totalPages > 1) ...[
                      Text(
                        'Page $_currentPage of $_totalPages',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentPage > 1
                            ? () => setState(() => _currentPage--)
                            : null,
                        iconSize: 20,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentPage < _totalPages
                            ? () => setState(() => _currentPage++)
                            : null,
                        iconSize: 20,
                      ),
                      const SizedBox(width: 16),
                    ],
                    Consumer<AdminSettingsProvider>(
                      builder: (context, adminSettings, _) {
                        if (!adminSettings.featureJobCardDownload) {
                          return const SizedBox.shrink();
                        }
                        return IconButton(onPressed: _exportCsv, icon: Icon(Icons.download,color: Colors.green,));
                      },
                    ),
                    SizedBox(width: 20,)
                  ],
                ),
              ],
            ),
          ),

          // Table with proper constraints
          Container(
            height: 600,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Scrollbar(
              controller: _verticalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: _buildDataTable(visibleColumns),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0);
  }

  DataTable _buildDataTable(List<String> visibleColumns) {
    debugPrint(
        '🏗️ Building DataTable with ${visibleColumns.length} columns: $visibleColumns');

    // Define ALL possible columns with proper widths
    final Map<String, DataColumn> allColumnDefinitions = {
      'vehicle_no': DataColumn(
        label: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Vehicle No.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      'vehicle_name': DataColumn(
        label: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Vehicle Name',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      'model': DataColumn(
        label: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Model',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      'brand': DataColumn(
        label: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Brand',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      'client_name': DataColumn(
        label: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Client Name',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      'client_phone': DataColumn(
        label: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Client Phone',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      'executive': DataColumn(
        label: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Executive',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      'date_time': DataColumn(
        label: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Date & Time',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      'status': DataColumn(
        label: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Status',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      'complaint': DataColumn(
        label: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Complaint',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      'approved': DataColumn(
        label: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Approved',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      'media': DataColumn(
        label: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            'Media',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    };

    // Build columns list based on visible columns setting
    final List<DataColumn> columns = [];
    for (final columnKey in visibleColumns) {
      if (allColumnDefinitions.containsKey(columnKey)) {
        columns.add(allColumnDefinitions[columnKey]!);
      } else {
        debugPrint('⚠️ Unknown column key: $columnKey');
      }
    }

    debugPrint('✅ Created ${columns.length} DataColumn widgets');

    return DataTable(
      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
      columnSpacing: 24,
      horizontalMargin: 16,
      dataRowMinHeight: 56,
      dataRowMaxHeight: 80,
      columns: columns,
      rows: _paginatedReports
          .map((report) => _buildDataRow(report, visibleColumns))
          .toList(),
    );
  }

  DataRow _buildDataRow(
      Map<String, dynamic> report, List<String> visibleColumns) {
    final vehicle = report['vehicles'];
    final model = vehicle?['vehicle_models'];

    // Define all possible cells
    final Map<String, DataCell> allCellDefinitions = {
      'vehicle_no': DataCell(
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            vehicle?['Vehicle Number']?.toString() ?? 'N/A',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
      'vehicle_name': DataCell(
        Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            vehicle?['vehicle_name']?.toString() ?? 'N/A',
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      'model': DataCell(
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            model?['Model name']?.toString() ?? 'N/A',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
      'brand': DataCell(
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            model?['brand']?.toString() ?? 'N/A',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
      'client_name': DataCell(
        Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            report['Owner name']?.toString() ?? 'N/A',
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      'client_phone': DataCell(
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            report['client_phone']?.toString() ?? 'N/A',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
      'executive': DataCell(
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            report['executive']?['username']?.toString() ?? 'N/A',
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      'date_time': DataCell(
        Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            DateFormat('dd/MM/yy HH:mm')
                .format(DateTime.parse(report['created_at'])),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
      'status': DataCell(
        Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Chip(
            label: Text(
              _formatStatus(report['status']),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            backgroundColor: _getStatusColor(report['status']),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      'complaint': DataCell(
        Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _formatJsonCell(report['complaint']),
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ),
      'approved': DataCell(
        Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _formatJsonCell(report['approved']),
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ),
      'media': DataCell(
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: (report['gdrive_folder_url'] as String?)?.isNotEmpty == true
              ? TextButton(
                  onPressed: () async {
                    final url = Uri.parse(report['gdrive_folder_url']);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('View Files'),
                )
              : const Text(
                  'N/A',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
        ),
      ),
    };

    // Build cells list based on visible columns
    final List<DataCell> cells = [];
    for (final columnKey in visibleColumns) {
      if (allCellDefinitions.containsKey(columnKey)) {
        cells.add(allCellDefinitions[columnKey]!);
      }
    }

    return DataRow(cells: cells);
  }
}
