// lib/screens/accountant/accountant_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/date_utils.dart';
import '../../providers/user_provider.dart';
import '../../services/company_service.dart';
import '../login_screen.dart';
import 'invoice_detail_screen.dart';
import 'payment_screen.dart';

class AccountantDashboardScreen extends StatefulWidget {
  const AccountantDashboardScreen({super.key});

  @override
  State<AccountantDashboardScreen> createState() => _AccountantDashboardScreenState();
}

class _AccountantDashboardScreenState extends State<AccountantDashboardScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _pendingBills = [];
  List<Map<String, dynamic>> _billed = [];
  List<Map<String, dynamic>> _paid = [];
  bool _isLoading = true;
  DateTime? _selectedSingleDate;
  DateTimeRange? _selectedCustomRange;
  String _selectedFilter = 'Today';
  final List<String> _filterOptions = ['Today', 'This Week', 'This Month', 'Custom Range', 'All Time'];
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Metrics
  int _pendingCount = 0;
  double _totalBilledAmount = 0;
  double _totalPaidAmount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterJobs(List<Map<String, dynamic>> jobs) {
    if (_searchQuery.isEmpty) return jobs;
    final q = _searchQuery.toLowerCase();
    return jobs.where((job) {
      final String jobId = (job['job_card_id'] ?? '#${job['id']}').toString().toLowerCase();
      final String customerName = _getCustomerName(job).toLowerCase();
      final String vehicleNo = _getVehicleNo(job).toLowerCase();
      
      final String clientPhone = (job['bookings']?['customer_phone'] ?? job['client_phone'] ?? '').toString().toLowerCase();

      return jobId.contains(q) || customerName.contains(q) || vehicleNo.contains(q) || clientPhone.contains(q);
    }).toList();
  }

  DateTime? _getStartDate() {
    if (_selectedSingleDate != null) {
      final d = _selectedSingleDate!;
      return DateTime(d.year, d.month, d.day, 0, 0, 0);
    }
    if (_selectedCustomRange != null) {
      final d = _selectedCustomRange!.start;
      return DateTime(d.year, d.month, d.day, 0, 0, 0);
    }

    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Today':
        return DateTime(now.year, now.month, now.day, 0, 0, 0);
      case 'This Week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
      case 'This Month':
        return DateTime(now.year, now.month, 1, 0, 0, 0);
      case 'All Time':
      default:
        return null;
    }
  }

  DateTime? _getEndDate() {
    if (_selectedSingleDate != null) {
      final d = _selectedSingleDate!;
      return DateTime(d.year, d.month, d.day, 23, 59, 59);
    }
    if (_selectedCustomRange != null) {
      final d = _selectedCustomRange!.end;
      return DateTime(d.year, d.month, d.day, 23, 59, 59);
    }
    return null;
  }

  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedSingleDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedSingleDate = picked;
        _selectedCustomRange = null;
        _selectedFilter = DateFormat('dd MMM yyyy').format(picked);
      });
      _loadData();
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedCustomRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedCustomRange = picked;
        _selectedSingleDate = null;
        _selectedFilter = 'Custom Range';
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final startDate = _getStartDate();
      final startDateIso = startDate?.toIso8601String();
      final endDate = _getEndDate();
      final endDateIso = endDate?.toIso8601String();
      final companyName = CompanyService().companyName;

      // Fetch completed, not yet billed (NULL or Draft)
      var pendingQuery = supabase
          .from('reports')
          .select('''
            id, job_card_id, status, billing_status,
            complaint, suggested, labour_cost, created_at, completed_at, marks,
            gst_percent, discount_amount, discount_type, extra_charge_amount, extra_charge_label,
            "Owner name", client_phone,
            vehicles!reports_vehicle_fk("Vehicle Number", vehicle_models(brand, "Model name")),
            bookings(customer_name, customer_phone),
            executive:executive_id(username)
          ''')
          .eq('status', AppConstants.statusCompleted)
          .or('billing_status.is.null,billing_status.eq.${AppConstants.statusDraft}');
      if (companyName != null && companyName.isNotEmpty) pendingQuery = pendingQuery.eq('company_name', companyName);
      if (startDateIso != null && endDateIso != null) {
        pendingQuery = pendingQuery.or('and(completed_at.gte.$startDateIso,completed_at.lte.$endDateIso),and(completed_at.is.null,created_at.gte.$startDateIso,created_at.lte.$endDateIso)');
      } else if (startDateIso != null) {
        pendingQuery = pendingQuery.or('completed_at.gte.$startDateIso,and(completed_at.is.null,created_at.gte.$startDateIso)');
      }
      final pendingRes = await pendingQuery.order('id', ascending: false);

      // Fetch billed (unpaid) invoices
      var billedQuery = supabase
          .from('reports')
          .select('''
            id, job_card_id, status, billing_status,
            complaint, suggested, labour_cost, created_at, completed_at, marks,
            billed_at, paid_at, payment_method,
            gst_percent, discount_amount, discount_type, extra_charge_amount, extra_charge_label,
            "Owner name", client_phone,
            vehicles!reports_vehicle_fk("Vehicle Number", vehicle_models(brand, "Model name")),
            bookings(customer_name, customer_phone),
            executive:executive_id(username),
            payments(method, amount, transaction_id)
          ''')
          .eq('billing_status', AppConstants.statusBilled);
      if (companyName != null && companyName.isNotEmpty) billedQuery = billedQuery.eq('company_name', companyName);
      if (startDateIso != null) billedQuery = billedQuery.gte('billed_at', startDateIso);
      if (endDateIso != null) billedQuery = billedQuery.lte('billed_at', endDateIso);
      final billedRes = await billedQuery.order('id', ascending: false);

      // Fetch paid invoices
      var paidQuery = supabase
          .from('reports')
          .select('''
            id, job_card_id, status, billing_status,
            complaint, suggested, labour_cost, created_at, completed_at, marks,
            billed_at, paid_at, payment_method,
            gst_percent, discount_amount, discount_type, extra_charge_amount, extra_charge_label,
            "Owner name", client_phone,
            vehicles!reports_vehicle_fk("Vehicle Number", vehicle_models(brand, "Model name")),
            bookings(customer_name, customer_phone),
            executive:executive_id(username),
            payments(method, amount, transaction_id)
          ''')
          .eq('billing_status', AppConstants.statusPaid);
      if (companyName != null && companyName.isNotEmpty) paidQuery = paidQuery.eq('company_name', companyName);
      if (startDateIso != null) paidQuery = paidQuery.gte('paid_at', startDateIso);
      if (endDateIso != null) paidQuery = paidQuery.lte('paid_at', endDateIso);
      final paidRes = await paidQuery.order('id', ascending: false);

      if (!mounted) return;

      double billedTotal = 0;
      double paidTotal = 0;

      for (final inv in billedRes) {
        billedTotal += _calcTotal(inv);
      }
      for (final inv in paidRes) {
        paidTotal += _calcTotal(inv);
        billedTotal += _calcTotal(inv); // Optionally include paid in total billed, or keep separate. Let's keep separate as per current logic.
      }
      // Re-adjusting logic to match exactly: totalBilled is everything billed+paid, totalPaid is just paid.
      billedTotal = 0;
      for (final inv in billedRes) billedTotal += _calcTotal(inv);
      for (final inv in paidRes) billedTotal += _calcTotal(inv);

      setState(() {
        _pendingBills = List<Map<String, dynamic>>.from(pendingRes);
        _billed = List<Map<String, dynamic>>.from(billedRes);
        _paid = List<Map<String, dynamic>>.from(paidRes);
        _pendingCount = _pendingBills.length;
        _totalBilledAmount = billedTotal;
        _totalPaidAmount = paidTotal;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  double _calcTotal(Map<String, dynamic> job) {
    double total = 0;
    try {
      final labour = (job['labour_cost'] ?? 0).toDouble();
      total += labour;

      final marksObj = job['marks'];
      bool isCourier = false;
      Map<String, dynamic>? marksMap;
      if (marksObj != null) {
        if (marksObj is String) {
          try {
            final decoded = jsonDecode(marksObj);
            if (decoded is Map<String, dynamic>) marksMap = decoded;
          } catch (_) {}
        } else if (marksObj is Map) {
          marksMap = Map<String, dynamic>.from(marksObj);
        }
        if (marksMap != null && marksMap['is_courier'] == true) {
          isCourier = true;
        }
      }

      // Decode complaint list
      dynamic rawComplaints = job['complaint'];
      List<dynamic> complaints = [];
      if (rawComplaints is List) {
        complaints = rawComplaints;
      } else if (rawComplaints is String && rawComplaints.trim().startsWith('[')) {
        try { complaints = jsonDecode(rawComplaints); } catch (_) {}
      }

      // Decode suggested list
      dynamic rawSuggested = job['suggested'];
      List<dynamic> suggested = [];
      if (rawSuggested is List) {
        suggested = rawSuggested;
      } else if (rawSuggested is String && rawSuggested.trim().startsWith('[')) {
        try { suggested = jsonDecode(rawSuggested); } catch (_) {}
      }

      if (isCourier) {
        double complaintTotal = 0;
        for (final c in complaints) {
          if (c is Map) complaintTotal += ((c['amount'] ?? 0) as num).toDouble();
        }

        if (complaintTotal > 0) {
          total += complaintTotal;
        } else {
          final products = marksMap?['products'] as List<dynamic>?;
          if (products != null) {
            for (final p in products) {
              if (p is Map) {
                final qty = (p['qty'] ?? 1) as num;
                final unitPrice = ((p['price'] ?? p['amount'] ?? 0) as num).toDouble();
                total += unitPrice * qty;
              }
            }
          }
        }
      } else {
        for (final c in complaints) {
          if (c is Map) total += ((c['amount'] ?? 0) as num).toDouble();
        }
        for (final s in suggested) {
          if (s is Map && s['type'] != AppConstants.typeComplaint) {
            total += ((s['amount'] ?? 0) as num).toDouble();
          }
        }
      }

      // Apply discount
      if (job['discount_amount'] != null) {
        final dVal = (job['discount_amount'] as num).toDouble();
        final dType = job['discount_type'] ?? 'flat';
        if (dType == 'percent') {
          total -= total * (dVal / 100);
        } else {
          total -= dVal;
        }
      }

      // Apply extra charges
      if (job['extra_charge_amount'] != null) {
        total += (job['extra_charge_amount'] as num).toDouble();
      }

      // Apply GST
      if (job['gst_percent'] != null) {
        final gst = (job['gst_percent'] as num).toDouble();
        total += total * (gst / 100);
      }

    } catch (_) {}
    return total;
  }

  String _getCustomerName(Map<String, dynamic> job) {
    return job['bookings']?['customer_name'] ??
           job['Owner name'] ?? 
           'Walk-in Customer';
  }

  String _getVehicleNo(Map<String, dynamic> job) {
    return job['vehicles']?['Vehicle Number'] ?? 'No Reg.';
  }

  String _getBrandModel(Map<String, dynamic> job) {
    final brand = job['vehicles']?['vehicle_models']?['brand'] ?? '';
    final model = job['vehicles']?['vehicle_models']?['Model name'] ?? '';
    return '$brand $model'.trim();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final parsed = AppDateUtils.parseUtcToLocal(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
    } catch (_) {
      return 'Invalid Date';
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.cacheKeyCurrentUser);
    if (!mounted) return;
    Provider.of<UserProvider>(context, listen: false).setUser(null);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Accountant Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (CompanyService().companyName != null && CompanyService().companyName!.isNotEmpty)
              Text(
                CompanyService().companyName!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) { if (v == 'logout') _logout(); },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Logout')]),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildFilterStrip(),
                        _buildMetricsStrip(),
                      ],
                    ),
                  ),
                  SliverAppBar(
                    pinned: true,
                    floating: false,
                    automaticallyImplyLeading: false,
                    backgroundColor: const Color(0xFFF8FAFC),
                    surfaceTintColor: Colors.transparent,
                    elevation: 2,
                    shadowColor: Colors.black12,
                    toolbarHeight: 68,
                    titleSpacing: 0,
                    title: _buildSearchBar(),
                    bottom: TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primaryColor,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      tabs: [
                        Tab(text: 'Pending ($_pendingCount)'),
                        Tab(text: 'Billed (${_billed.length})'),
                        Tab(text: 'Completed (${_paid.length})'),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildPendingList(),
                  _buildBilledList(),
                  _buildCompletedList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search by Name, Vehicle, Phone, or ID...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterStrip() {
    final hasSingleDate = _selectedSingleDate != null;
    final hasCustomRange = _selectedCustomRange != null;
    final activeDateLabel = hasSingleDate
        ? DateFormat('dd MMM yyyy').format(_selectedSingleDate!)
        : hasCustomRange
            ? '${DateFormat('dd MMM').format(_selectedCustomRange!.start)} - ${DateFormat('dd MMM').format(_selectedCustomRange!.end)}'
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Date Filter:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(
                  Icons.calendar_month_rounded,
                  color: (hasSingleDate || hasCustomRange) ? AppTheme.primaryColor : Colors.grey.shade700,
                  size: 22,
                ),
                tooltip: 'Filter by Single Date',
                onPressed: _pickSingleDate,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (activeDateLabel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activeDateLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSingleDate = null;
                            _selectedCustomRange = null;
                            _selectedFilter = 'Today';
                          });
                          _loadData();
                        },
                        child: const Icon(Icons.close, size: 14, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          DropdownButton<String>(
            value: _filterOptions.contains(_selectedFilter) ? _selectedFilter : null,
            hint: _filterOptions.contains(_selectedFilter) ? null : Text(_selectedFilter, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryColor),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            items: _filterOptions.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) async {
              if (v == 'Custom Range') {
                await _pickCustomRange();
              } else if (v != null) {
                setState(() {
                  _selectedSingleDate = null;
                  _selectedCustomRange = null;
                  _selectedFilter = v;
                });
                _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsStrip() {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _metricChip(Icons.pending_actions, 'Pending', '$_pendingCount jobs', Colors.orange),
          const SizedBox(width: 10),
          _metricChip(Icons.receipt_long, 'Billed', currency.format(_totalBilledAmount), Colors.blue),
          const SizedBox(width: 10),
          _metricChip(Icons.check_circle, 'Collected', currency.format(_totalPaidAmount), Colors.green),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label, 
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    final filtered = _filterJobs(_pendingBills);
    if (filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No pending billing', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
            SizedBox(height: 8),
            Text('All completed jobs have been billed!', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
        itemCount: filtered.length,
        itemBuilder: (context, i) => _buildJobCard(filtered[i], isPending: true),
      ),
    );
  }

  Widget _buildBilledList() {
    final filtered = _filterJobs(_billed);
    if (filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('No pending payments', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
        itemCount: filtered.length,
        itemBuilder: (context, i) => _buildJobCard(filtered[i], isPending: false),
      ),
    );
  }

  Widget _buildCompletedList() {
    final filtered = _filterJobs(_paid);
    if (filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('No completed payments yet', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
        itemCount: filtered.length,
        itemBuilder: (context, i) => _buildJobCard(filtered[i], isPending: false),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, {required bool isPending}) {
    final total = _calcTotal(job);
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final billingStatus = job['billing_status'] as String?;
    final isPaid = billingStatus == AppConstants.statusPaid;
    final isBilled = billingStatus == AppConstants.statusBilled;

    // Border color driven by highest status reached
    final Color borderColor = isPaid
        ? Colors.green.withValues(alpha: 0.3)
        : isBilled
            ? Colors.blue.withValues(alpha: 0.3)
            : Colors.orange.withValues(alpha: 0.25);

    // Amount color
    final Color amountColor = isPaid
        ? Colors.green
        : isBilled
            ? Colors.blue
            : Colors.orange;

    final marksObj = job['marks'];
    bool isCourier = false;
    String? courierSubtitle;
    String? courierDetails;
    
    if (marksObj != null) {
      Map<String, dynamic>? marksMap;
      if (marksObj is String) {
        try {
          final decoded = jsonDecode(marksObj);
          if (decoded is Map<String, dynamic>) marksMap = decoded;
        } catch (_) {}
      } else if (marksObj is Map) {
        marksMap = Map<String, dynamic>.from(marksObj);
      }
      
      if (marksMap != null && marksMap['is_courier'] == true) {
        isCourier = true;
        
        final products = marksMap['products'] as List<dynamic>?;
        if (products != null && products.isNotEmpty) {
           courierSubtitle = products[0]['name']?.toString() ?? 'Courier Package';
           courierDetails = '${products.length} Product(s)';
        } else {
           courierSubtitle = 'Courier Package';
           courierDetails = 'No Products';
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoiceDetailScreen(job: job, isPending: isPending),
            ),
          );
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Job info + Amount & Pills
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                job['job_card_id'] ?? '#${job['id']}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCourier) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: const Text(
                                  'Courier',
                                  style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        if (isCourier) ...[
                          Row(
                            children: [
                              const Icon(Icons.inventory_2, size: 14, color: AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  courierSubtitle ?? 'Courier Package',
                                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Text(
                              courierDetails ?? 'Details',
                              style: TextStyle(fontSize: 12, color: Colors.purple.shade700, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ] else ...[
                          Text(
                            _getBrandModel(job),
                            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getVehicleNo(job),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currency.format(total),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: amountColor),
                      ),
                      const SizedBox(height: 6),
                      // Dynamic pills based on billing_status
                      _buildStatusPills(billingStatus),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 15, color: AppTheme.textSecondary),
                  const SizedBox(width: 5),
                  Expanded(child: Text(_getCustomerName(job), style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary))),
                  const Icon(Icons.arrow_forward_ios, size: 13, color: AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    isPaid ? _formatDate(job['paid_at']) 
                    : isBilled ? _formatDate(job['billed_at']) 
                    : (isCourier ? _formatDate(job['created_at']) : _formatDate(job['completed_at'])), 
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)
                  ),
                  const Spacer(),
                  const Icon(Icons.engineering, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 5),
                  Text(job['executive']?['username'] ?? 'Unknown', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
              if (isBilled && !isPaid) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(job: job, grandTotal: total),
                        ),
                      );
                      _loadData();
                    },
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPills(String? billingStatus) {
    final isPaid = billingStatus == AppConstants.statusPaid;
    final isBilled = billingStatus == AppConstants.statusBilled || isPaid;
    final isDraft = billingStatus == AppConstants.statusDraft;

    if (isPaid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _pill('Billed', Colors.blue, Icons.receipt_long),
          const SizedBox(height: 4),
          _pill('Payment Received', Colors.green, Icons.check_circle),
        ],
      );
    } else if (isBilled) {
      return _pill('Billed', Colors.blue, Icons.receipt_long);
    } else if (isDraft) {
      return _pill('Saved as Draft', Colors.purple, Icons.edit_note);
    } else {
      return _pill('Pending Billing', Colors.orange, Icons.pending_actions);
    }
  }

  Widget _pill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
