import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';
import 'vehicle_management_screen.dart';
import 'reports_analytics_screen.dart';
import 'user_management_screen.dart';
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

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final supabase = Supabase.instance.client;
  
  // Metrics
  int _totalUsers = 0;
  int _activeReports = 0;
  int _pendingApprovals = 0;
  int _todayBookings = 0;
  bool _isLoadingMetrics = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final results = await Future.wait([
        supabase.from('users').select('id').count(),
        supabase.from('reports').select('id').neq('status', 'Completed').count(),
        supabase.from('reports').select('id').eq('status', 'Pending Approval').count(),
        supabase.from('bookings').select('id').gte('created_at', DateTime.now().toIso8601String().split('T')[0]).count(),
      ]);

      if (mounted) {
        setState(() {
          _totalUsers = results[0].count;
          _activeReports = results[1].count;
          _pendingApprovals = results[2].count;
          _todayBookings = results[3].count;
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
      backgroundColor:Colors.white,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Metrics Section
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _isLoadingMetrics
                  ? const ModernLoadingIndicator(message: 'Loading metrics...')
                  : AnimationLimiter(
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.2,
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 375),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(child: widget),
                          ),
                          children: [
                            _buildMetricCard('Total Users', _totalUsers.toString(), Icons.people, Colors.blue),
                            _buildMetricCard('Active Reports', _activeReports.toString(), Icons.assignment, Colors.green),
                            _buildMetricCard('Pending Approvals', _pendingApprovals.toString(), Icons.pending_actions, Colors.orange),
                            _buildMetricCard('Today\'s Bookings', _todayBookings.toString(), Icons.event, Colors.purple),
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 32),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              AnimationLimiter(
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 375),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: [
                      _buildDashboardCard(
                        context,
                        title: 'Reports & Service History',
                    
                        icon: Icons.assessment,
                        color: Colors.blue,
                        onTap: () {
                          HapticUtils.light();
                          _navigateTo(context, const ReportsAnalyticsScreen());
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        title: 'Analytics',
                        
                        icon: Icons.bar_chart,
                        color: Colors.indigo,
                        onTap: () {
                          HapticUtils.light();
                          _navigateTo(context, const AnalyticsScreen());
                        },
                      ),
                      _buildDashboardCard(
                        context,
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
                        title: 'User Management',
                        
                        icon: Icons.people_alt,
                        color: Colors.green,
                        onTap: () {
                          HapticUtils.light();
                          _navigateTo(context, const UserManagementScreen());
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        title: 'App Settings',
                        
                        icon: Icons.settings,
                        color: Colors.indigo,
                        onTap: () {
                          HapticUtils.light();
                          _navigateTo(context, const AppSettingsScreen());
                        },
                      ),
                      _buildDashboardCard(
                        context,
                        title: 'Quick Access',
                        icon: Icons.switch_account,
                        color: Colors.teal,
                        onTap: () {
                          HapticUtils.light();
                          _showQuickAccessDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required String title,
        
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 32,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return ModernCard(
      padding: const EdgeInsets.all(16),
      enableHoverEffect: true,
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
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ).animate().fadeIn(duration: 400.ms).scale(),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}