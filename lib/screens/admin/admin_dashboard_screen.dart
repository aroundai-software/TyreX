import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import 'app_settings_screen.dart';
import 'vehicle_management_screen.dart';
import 'service_catalog_screen.dart';
import 'tyre_catalog_screen.dart';
import '../login_screen.dart';
import 'user_management_screen.dart';
import 'reports_analytics_screen.dart';
import 'app_settings_screen.dart';
import 'analytics_screen.dart';
import '../../widgets/quick_access_dialog.dart';
import '../../widgets/modern_page_route.dart';
import '../../widgets/modern_card.dart';
import '../../widgets/modern_loading.dart';
import '../../utils/haptic_utils.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'dart:convert';
import '../profile_screen.dart';
import '../../services/company_service.dart';
import '../update_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final supabase = Supabase.instance.client;
  
  // Metrics
  int _todayJobs = 0;
  double _amountReceived = 0.0;
  bool _isLoadingMetrics = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final String? companyName = CompanyService().companyName;
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      
      // Build queries with company isolation
      var jobsQuery = supabase.from('reports').select('id').gte('created_at', todayStr);
      var paymentsQuery = supabase.from('payments').select('amount, reports!inner(company_name)').gte('paid_at', todayStr);
      
      // Apply company filter if available
      if (companyName != null && companyName.isNotEmpty) {
        jobsQuery = jobsQuery.eq('company_name', companyName);
        paymentsQuery = paymentsQuery.eq('reports.company_name', companyName);
      }
      
      final jobsResult = await jobsQuery.count();
      final paymentsResult = await paymentsQuery;

      double amountReceived = 0.0;
      for (var p in paymentsResult as List<dynamic>) {
        amountReceived += ((p as Map)['amount'] ?? 0.0) as num;
      }

      if (mounted) {
        setState(() {
          _todayJobs = jobsResult.count;
          _amountReceived = amountReceived;
          _isLoadingMetrics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMetrics = false);
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final originalAdminJson = prefs.getString('originalAdmin');

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (originalAdminJson != null) {
      // Return from Quick Access to original admin
      final originalAdmin = jsonDecode(originalAdminJson) as Map<String, dynamic>;

      // Update provider
      userProvider.switchToUser(originalAdmin); // or restoreOriginalAdmin if you have that method

      // Clean up session markers
      await prefs.setString('currentUser', originalAdminJson);
      await prefs.remove('originalAdmin');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Returned to admin dashboard'),
          backgroundColor: Colors.green,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
      return;
    }

    // Full logout: clear session and go to login
    await prefs.remove('currentUser');
    if (!mounted) return;
    userProvider.setUser(null); // or userProvider.logout() if you have such a method

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    context.pushModern(
      screen,
      transition: RouteTransitionType.slideUp,
    );
  }

  void _showQuickAccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const QuickAccessDialog(), // USE THE NEW DIALOG
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            color: Colors.grey.shade300,
            height: 0.5,
          ),
        ),
        title: Column(
          children: [
            const Text(
              'Admin Dashboard',
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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else if (value == 'logout') {
                _logout();
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMetrics,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 600;
              final double gap = isDesktop ? 12.0 : 8.0;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24.0 : 4.0,
                  vertical: isDesktop ? 24.0 : 16.0,
                ),
                child: Container(
                  decoration: isDesktop ? null : BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Metrics Section
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Overview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      _isLoadingMetrics
                          ? const ModernLoadingIndicator(message: 'Loading metrics...')
                          : AnimationLimiter(
                              child: isDesktop
                                ? IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(child: _buildMetricCard('Total Jobs Today', _todayJobs.toString(), Icons.work, Colors.blue)),
                                        SizedBox(width: gap),
                                        Expanded(child: _buildMetricCard('Amount Received Today', NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(_amountReceived), Icons.currency_rupee, Colors.green)),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: [
                                      IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(child: _buildMetricCard('Total Jobs Today', _todayJobs.toString(), Icons.work, Colors.blue)),
                                            SizedBox(width: gap),
                                            Expanded(child: _buildMetricCard('Amount Received Today', NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(_amountReceived), Icons.currency_rupee, Colors.green)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              AnimationLimiter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 600;
                    final double gap = isDesktop ? 12.0 : 8.0;
                    final int crossAxisCount = isDesktop ? 3 : 2;
                    final double itemWidth = (constraints.maxWidth - (gap * (crossAxisCount - 1))) / crossAxisCount;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 375),
                        childAnimationBuilder: (widget) => SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(child: widget),
                        ),
                        children: [
                          _buildDashboardCard(
                            context,
                            width: itemWidth,
                            title: 'Live Job Board',
                            icon: Icons.dashboard_customize,
                            color: AppTheme.primaryColor,
                            onTap: () {
                              HapticUtils.light();
                              Navigator.push(
                                context,
                                ModernPageRoute(page: const UpdateScreen(isAdminMode: true)),
                              );
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            width: itemWidth,
                            title: 'Reports & History',
                            icon: Icons.assessment,
                            color: AppTheme.primaryColor,
                            onTap: () {
                              HapticUtils.light();
                              _navigateTo(context, const ReportsAnalyticsScreen());
                            },
                          ),
                          /*
                          _buildDashboardCard(
                            context,
                            width: itemWidth,
                            title: 'Analytics',
                            icon: Icons.bar_chart,
                            color: AppTheme.primaryColor,
                            onTap: () {
                              HapticUtils.light();
                              _navigateTo(context, const AnalyticsScreen());
                            },
                          ),
                          */
                          _buildDashboardCard(
                            context,
                            width: itemWidth,
                            title: 'Vehicle Management',
                            icon: Icons.directions_car,
                            color: Colors.orange,
                            onTap: () {
                              HapticUtils.light();
                              _navigateTo(context, const VehicleManagementScreen());
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            width: itemWidth,
                            title: 'Service Catalog',
                            icon: Icons.design_services,
                            color: Colors.teal,
                            onTap: () {
                              HapticUtils.light();
                              _navigateTo(context, const ServiceCatalogScreen());
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            width: itemWidth,
                            title: 'Tyre Catalog',
                            icon: Icons.tire_repair,
                            color: Colors.teal,
                            onTap: () {
                              HapticUtils.light();
                              _navigateTo(context, const TyreCatalogScreen());
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            width: itemWidth,
                            title: 'User Management',
                            icon: Icons.people_alt,
                            color: Colors.purple,
                            onTap: () {
                              HapticUtils.light();
                              _navigateTo(context, const UserManagementScreen());
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            width: itemWidth,
                            title: 'App Settings',
                            icon: Icons.settings,
                            color: Colors.grey.shade700,
                            onTap: () {
                              HapticUtils.light();
                              _navigateTo(context, const AppSettingsScreen());
                            },
                          ),
                          /*
                          _buildDashboardCard(
                            context,
                            width: itemWidth,
                            title: 'Quick Access',
                            icon: Icons.switch_account,
                            color: Colors.purple,
                            onTap: () {
                              HapticUtils.light();
                              _showQuickAccessDialog(context);
                            },
                          ),
                          */
                        ],
                      ),
                    );
                  }
                ),
              ),
            ],
          ),
        ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required double width,
        required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return SizedBox(
      width: width,
      child: ModernCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 28,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100, // Slightly darker than the surface so it's visible on grey.shade50
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.1,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}