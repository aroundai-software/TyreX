// lib/screens/accountant/accountant_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../providers/user_provider.dart';
import '../../services/company_service.dart';
import '../login_screen.dart';
import 'invoice_detail_screen.dart';

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
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Fetch completed, not yet billed (NULL or Draft)
      final pendingRes = await supabase
          .from('reports')
          .select('''
            id, job_card_id, status, billing_status,
            complaint, suggested, labour_cost, created_at, completed_at,
            gst_percent, discount_amount, discount_type, extra_charge_amount, extra_charge_label,
            "Owner name", client_phone,
            vehicles!reports_vehicle_fk("Vehicle Number", vehicle_models(brand, "Model name")),
            bookings(customer_name, customer_phone)
          ''')
          .eq('status', AppConstants.statusCompleted)
          .or('billing_status.is.null,billing_status.eq.${AppConstants.statusDraft}')
          .order('completed_at', ascending: false);

      // Fetch billed (unpaid) invoices
      final billedRes = await supabase
          .from('reports')
          .select('''
            id, job_card_id, status, billing_status,
            complaint, suggested, labour_cost, created_at, completed_at,
            billed_at, paid_at, payment_method,
            gst_percent, discount_amount, discount_type, extra_charge_amount, extra_charge_label,
            "Owner name", client_phone,
            vehicles!reports_vehicle_fk("Vehicle Number", vehicle_models(brand, "Model name")),
            bookings(customer_name, customer_phone)
          ''')
          .eq('billing_status', AppConstants.statusBilled)
          .order('billed_at', ascending: false);

      // Fetch paid invoices
      final paidRes = await supabase
          .from('reports')
          .select('''
            id, job_card_id, status, billing_status,
            complaint, suggested, labour_cost, created_at, completed_at,
            billed_at, paid_at, payment_method,
            gst_percent, discount_amount, discount_type, extra_charge_amount, extra_charge_label,
            "Owner name", client_phone,
            vehicles!reports_vehicle_fk("Vehicle Number", vehicle_models(brand, "Model name")),
            bookings(customer_name, customer_phone)
          ''')
          .eq('billing_status', AppConstants.statusPaid)
          .order('paid_at', ascending: false);

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

      // Decode complaint list (may be a JSON string or already a List)
      dynamic rawComplaints = job['complaint'];
      List<dynamic> complaints = [];
      if (rawComplaints is List) {
        complaints = rawComplaints;
      } else if (rawComplaints is String && rawComplaints.trim().startsWith('[')) {
        try { complaints = jsonDecode(rawComplaints); } catch (_) {}
      }
      for (final c in complaints) {
        if (c is Map) total += ((c['amount'] ?? 0) as num).toDouble();
      }

      // Decode suggested list (may be a JSON string or already a List)
      dynamic rawSuggested = job['suggested'];
      List<dynamic> suggested = [];
      if (rawSuggested is List) {
        suggested = rawSuggested;
      } else if (rawSuggested is String && rawSuggested.trim().startsWith('[')) {
        try { suggested = jsonDecode(rawSuggested); } catch (_) {}
      }
      for (final s in suggested) {
        if (s is Map && s['type'] != AppConstants.typeComplaint) {
          total += ((s['amount'] ?? 0) as num).toDouble();
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Metrics strip
                _buildMetricsStrip(),
                // Tab views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPendingList(),
                      _buildBilledList(),
                      _buildCompletedList(),
                    ],
                  ),
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
    if (_pendingBills.isEmpty) {
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
        padding: const EdgeInsets.all(16),
        itemCount: _pendingBills.length,
        itemBuilder: (context, i) => _buildJobCard(_pendingBills[i], isPending: true),
      ),
    );
  }

  Widget _buildBilledList() {
    if (_billed.isEmpty) {
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
        padding: const EdgeInsets.all(16),
        itemCount: _billed.length,
        itemBuilder: (context, i) => _buildJobCard(_billed[i], isPending: false),
      ),
    );
  }

  Widget _buildCompletedList() {
    if (_paid.isEmpty) {
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
        padding: const EdgeInsets.all(16),
        itemCount: _paid.length,
        itemBuilder: (context, i) => _buildJobCard(_paid[i], isPending: false),
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
                        Text(
                          job['job_card_id'] ?? '#${job['id']}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 3),
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
