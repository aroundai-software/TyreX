// lib/screens/pudo_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/user_provider.dart';
import '../services/supabase_service.dart';
import '../services/auth_helper.dart';
import '../theme/app_theme.dart';
import 'pudo_job_card_screen.dart';
import 'profile_screen.dart';

class PudoDashboardScreen extends StatefulWidget {
  const PudoDashboardScreen({super.key});

  @override
  State<PudoDashboardScreen> createState() => _PudoDashboardScreenState();
}

class _PudoDashboardScreenState extends State<PudoDashboardScreen> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _assignedPickupsFuture;
  late Future<List<Map<String, dynamic>>> _myCreatedJobsFuture;
  final _supabaseService = SupabaseService();
  String _searchQuery = '';
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
          _searchQuery = ''; // Clear search when switching tabs
        });
      }
    });
    _assignedPickupsFuture = _fetchAssignedPickups();
    _myCreatedJobsFuture = _fetchMyCreatedJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchAssignedPickups() {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      // This is a new function we will add to SupabaseService
      return _supabaseService.getAssignedPickups(user['id'] as int);
    }
    return Future.value([]); // Return empty list if no user
  }

  Future<List<Map<String, dynamic>>> _fetchMyCreatedJobs() {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      return _supabaseService.getJobsCreatedByPudo(user['id'] as int); // ✅ Pass as int
    }
    return Future.value([]);
  }

  void _refresh() {
    setState(() {
      _assignedPickupsFuture = _fetchAssignedPickups();
      _myCreatedJobsFuture = _fetchMyCreatedJobs();
    });
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
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () async {
                await AuthHelper.logout(context);
              },
            ),
          ],
        );
      },
    );
  }

  Color get _backgroundColor => const Color(0xFFE3F2FD);
  Color get _cardColor => Colors.white;
  Color get _textPrimary => const Color(0xFF1A237E);
  Color get _textSecondary => const Color(0xFF5C6BC0);
  Color get _borderColor => const Color(0xFFBBDEFB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          const Text(
                            'PUDO Dashboard',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 26,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 18),
                          FutureBuilder<List<List<Map<String, dynamic>>>>(
                            future: Future.wait([_myCreatedJobsFuture, _assignedPickupsFuture]),
                            builder: (context, snapshot) {
                              final myJobs = snapshot.data != null && snapshot.data!.isNotEmpty ? snapshot.data![0] : <Map<String, dynamic>>[];
                              final pickups = snapshot.data != null && snapshot.data!.length > 1 ? snapshot.data![1] : <Map<String, dynamic>>[];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernStatCard('Active Jobs', myJobs.length, Icons.work_outline),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.white.withValues(alpha: 0.2),
                                      margin: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    Expanded(
                                      child: _buildModernStatCard('Pick-ups', pickups.length, Icons.local_shipping_outlined),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _refresh,
                  tooltip: 'Refresh',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'profile') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    } else if (value == 'logout') {
                      _showLogoutConfirmationDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 20),
                          SizedBox(width: 12),
                          Text('Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 20),
                          SizedBox(width: 12),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                Container(
                  color: _backgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: _borderColor),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: _textSecondary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                size: 18,
                                color: _currentTabIndex == 0 ? Colors.white : _textSecondary,
                              ),
                              const SizedBox(width: 6),
                              const Text('Pick-ups'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.work_outline,
                                size: 18,
                                color: _currentTabIndex == 1 ? Colors.white : _textSecondary,
                              ),
                              const SizedBox(width: 6),
                              const Text('My Jobs'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: _currentTabIndex == 0
                        ? 'Search pick-ups by customer, address...'
                        : 'Search jobs by vehicle, client...',
                    hintStyle: TextStyle(fontSize: 14, color: _textSecondary.withValues(alpha: 0.5), fontWeight: FontWeight.w400),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(Icons.search_rounded, color: AppTheme.primaryColor, size: 24),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: _textSecondary, size: 20),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    isDense: false,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPickupsTab(),
                  _buildMyJobsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 8),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PudoJobCardScreen()))
                .then((_) => _refresh());
          },
          label: const Text('New Job Card', style: TextStyle(fontWeight: FontWeight.w600)),
          icon: const Icon(Icons.add_circle_outline),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryColor,
          elevation: 4,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildModernStatCard(String label, int count, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMyJobsTab() {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _myCreatedJobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final myJobs = snapshot.data ?? [];
          final q = _searchQuery.toLowerCase();
          final filteredMyJobs = q.isEmpty
              ? myJobs
              : myJobs.where((job) {
                  final vehicle = job['vehicles'];
                  final models = vehicle?['vehicle_models'];
                  final parts = <String>[
                    '${vehicle?['Vehicle Number'] ?? ''}',
                    '${models?['brand'] ?? ''}',
                    '${models?['Model name'] ?? ''}',
                    '${job['client_phone'] ?? ''}',
                    '${job['client_phone'] ?? ''}',
                  ].join(' ').toLowerCase();
                  return parts.contains(q);
                }).toList();

          if (filteredMyJobs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(32),
              children: [
                const SizedBox(height: 60),
                Icon(
                  Icons.inbox_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 20),
                Text(
                  q.isEmpty ? 'No job cards yet' : 'No matching job cards',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  q.isEmpty ? 'Create your first job card using the + button' : 'Try a different search term',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: _textSecondary),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: filteredMyJobs.length,
            itemBuilder: (context, index) => _buildJobCard(filteredMyJobs[index]),
          );
        },
      ),
    );
  }

  Widget _buildPickupsTab() {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _assignedPickupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final pickups = snapshot.data ?? [];
          final q = _searchQuery.toLowerCase();
          final filteredPickups = q.isEmpty
              ? pickups
              : pickups.where((p) {
                  final parts = <String>[
                    '${p['customer_name'] ?? ''}',
                    '${p['customer_phone'] ?? ''}',
                    '${p['pickup_address'] ?? ''}',
                  ].join(' ').toLowerCase();
                  return parts.contains(q);
                }).toList();

          if (filteredPickups.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(32),
              children: [
                const SizedBox(height: 60),
                Icon(
                  Icons.local_shipping_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 20),
                Text(
                  q.isEmpty ? 'No assigned pick-ups' : 'No matching pick-ups',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  q.isEmpty ? 'Pick-ups will appear here when assigned' : 'Try a different search term',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: _textSecondary),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: filteredPickups.length,
            itemBuilder: (context, index) => _buildPickupCard(filteredPickups[index]),
          );
        },
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final vehicle = job['vehicles'];
    final vehicleModels = vehicle?['vehicle_models'];
    final status = job['status'] ?? 'not_started';
    final statusDisplay = status.toString().replaceAll('_', ' ');
    final progress = _getProgressFromStatus(status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${vehicleModels?['brand'] ?? 'N/A'} ${vehicleModels?['Model name'] ?? 'N/A'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vehicle?['Vehicle Number'] ?? 'No Registration',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: _textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Client: ${job['client_phone'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 13, color: _textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  statusDisplay,
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${progress.toInt()}%',
                  style: TextStyle(
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(status)),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getProgressFromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'not_started':
      case 'not started':
        return 0;
      case 'ongoing':
        return 50;
      case 'inspection':
        return 60;
      case 'washing':
        return 80;
      case 'completed':
        return 100;
      default:
        return 0;
    }
  }

// ✅ Update color mapping to match actual status values
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'not started':
        return Colors.blue;
      case 'ongoing':
        return Colors.orange;
      case 'inspection':
        return Colors.purple;
      case 'washing':
        return Colors.cyan;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPickupCard(Map<String, dynamic> pickup) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickup['customer_name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.call, size: 14, color: _textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            pickup['customer_phone'],
                            style: TextStyle(color: _textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (pickup['pickup_address'] != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.home_outlined, size: 16, color: _textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      pickup['pickup_address'],
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (pickup['scheduled_time'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: _textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM, hh:mm a').format(DateTime.parse(pickup['scheduled_time'])),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final phone = pickup['customer_phone'];
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone_rounded, size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              const Text(
                                'Call',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final address = pickup['pickup_address'];
                          if (address == null || address.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('No address available for navigation'),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                            return;
                          }
                          final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.navigation_rounded, size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              const Text(
                                'Navigate',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PudoJobCardScreen(
                          bookingId: pickup['id'],
                        ),
                      ),
                    ).then((_) => _refresh());
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          'Mark as Picked Up',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sticky Tab Bar Delegate for pinned tabs
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate(this.child);

  final Widget child;

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
}