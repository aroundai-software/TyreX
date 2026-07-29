// lib/widgets/quick_access_dialog.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import '../theme/app_theme.dart';
import '../screens/main_dashboard.dart'; 
import '../screens/washer_screen.dart';
import '../screens/inspector_screen.dart';
import '../screens/telecaller_dashboard_screen.dart';
import '../screens/pudo_dashboard_screen.dart';

import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class QuickAccessDialog extends StatefulWidget {
  const QuickAccessDialog({super.key});

  @override
  State<QuickAccessDialog> createState() => _QuickAccessDialogState();
}

class _QuickAccessDialogState extends State<QuickAccessDialog> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _executives = [];
  List<Map<String, dynamic>> _inspectors = [];
  List<Map<String, dynamic>> _washers = [];
  List<Map<String, dynamic>> _telecallers = [];
  List<Map<String, dynamic>> _pudos = [];

  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _collapsedSections = {
    'telecallers': true,
    'pudos': true,
    'executives': true,
    'inspectors': true,
    'washers': true,
  };

  void _toggleSection(String key) {
    setState(() {
      final current = _collapsedSections[key] ?? false;
      _collapsedSections[key] = !current;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch all users (executives, inspectors, washers, telecallers, pudo) in parallel
      final results = await Future.wait([
        supabase
            .from('users')
            .select('id, username, role, team')
            .eq('role', 'executive')
            .order('username', ascending: true),
        supabase
            .from('users')
            .select('id, username, role')
            .eq('role', 'inspector')
            .order('username', ascending: true),
        supabase
            .from('users')
            .select('id, username, role')
            .eq('role', 'washer')
            .order('username', ascending: true),
        supabase
            .from('users')
            .select('id, username, role')
            .eq('role', 'tele_caller')
            .order('username', ascending: true),
        supabase
            .from('users')
            .select('id, username, role')
            .eq('role', 'pickup_dropoff')
            .order('username', ascending: true),
      ]);

      setState(() {
        _executives = List<Map<String, dynamic>>.from(results[0]);
        _inspectors = List<Map<String, dynamic>>.from(results[1]);
        _washers = List<Map<String, dynamic>>.from(results[2]);
        _telecallers = List<Map<String, dynamic>>.from(results[3]);
        _pudos = List<Map<String, dynamic>>.from(results[4]);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load users: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _switchToUser(Map<String, dynamic> user) async {
    try {
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();

      // Get current admin from provider (assumed to be admin during Quick Access)
      final originalAdmin = userProvider.user;
      if (originalAdmin == null) {
        throw Exception('Original admin session not found');
      }

      // Save original admin to SharedPreferences for later restore
      await prefs.setString('originalAdmin', jsonEncode(originalAdmin));

      // Update the UserProvider to reflect the switched user
      userProvider.switchToUser(user);

      // Also save to SharedPreferences (for app restart / deep link support)
      await prefs.setString('currentUser', jsonEncode(user));

      if (!mounted) return;

      // Navigate based on role
      Widget targetScreen;
      String successMessage;

      switch (user['role']) {
        case 'executive':
          targetScreen = const MainDashboard(); 
          successMessage = 'Switched to executive: ${user['username']}';
          break;
        case 'washer':
          targetScreen = const WasherScreen();
          successMessage = 'Switched to washer: ${user['username']}';
          break;
        case 'inspector':
          targetScreen = const InspectorScreen();
          successMessage = 'Switched to inspector: ${user['username']}';
          break;
        case 'telecaller': // legacy key
        case 'tele_caller':
          targetScreen = const TelecallerDashboardScreen();
          successMessage = 'Switched to telecaller: ${user['username']}';
          break;
        case 'pudo': // legacy key
        case 'pickup_dropoff':
          targetScreen = const PudoDashboardScreen();
          successMessage = 'Switched to PUDO: ${user['username']}';
          break;
        default:
          throw Exception('Unknown user role: ${user['role']}');
      }

      // Close dialog
      Navigator.of(context).pop();

      // Replace current route
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => targetScreen),
      );

      // Show success message - Commented out to reduce UI noise
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(successMessage),
      //     backgroundColor: Colors.green,
      //     behavior: SnackBarBehavior.floating,
      //     shape: RoundedRectangleBorder(
      //       borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
      //     ),
      //     margin: const EdgeInsets.all(16),
      //   ),
      // );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to switch user: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.85;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SafeArea(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight < 640 ? maxHeight : 640),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Modern header with gradient
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.switch_account_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quick Access',
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Switch to any user profile',
                                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search users...',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryColor),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                    const SizedBox(height: 12),
                                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                                    const SizedBox(height: 12),
                                    ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
                                  ],
                                ),
                              )
                            : _buildUsersList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    // Get module toggle status from settings
    // Filter users based on search query (always include all roles)
    final filteredExecutives = _executives.where((u) => u['username'].toString().toLowerCase().contains(_searchQuery)).toList();
    final filteredInspectors = _inspectors.where((u) => u['username'].toString().toLowerCase().contains(_searchQuery)).toList();
    final filteredWashers = _washers.where((u) => u['username'].toString().toLowerCase().contains(_searchQuery)).toList();
    final filteredTelecallers = _telecallers.where((u) => u['username'].toString().toLowerCase().contains(_searchQuery)).toList();
    final filteredPudos = _pudos.where((u) => u['username'].toString().toLowerCase().contains(_searchQuery)).toList();

    final hasAnyUsers = filteredExecutives.isNotEmpty ||
        filteredInspectors.isNotEmpty ||
        filteredWashers.isNotEmpty ||
        filteredTelecallers.isNotEmpty ||
        filteredPudos.isNotEmpty;

    if (!hasAnyUsers) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No users found' : 'No users match "$_searchQuery"',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final sections = <_UserSection>[
      _UserSection(
        key: 'telecallers',
        title: 'Telecallers',
        icon: Icons.headset_mic_rounded,
        color: const Color(0xFF14B8A6),
        users: filteredTelecallers,
        isVisible: true,
      ),
      _UserSection(
        key: 'pudos',
        title: 'PUDO Users',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF6366F1),
        users: filteredPudos,
        isVisible: true,
      ),
      _UserSection(
        key: 'executives',
        title: 'Executives',
        icon: Icons.engineering_rounded,
        color: const Color(0xFF3B82F6),
        users: filteredExecutives,
        isVisible: true,
      ),
      _UserSection(
        key: 'inspectors',
        title: 'Inspectors',
        icon: Icons.fact_check_rounded,
        color: const Color(0xFF8B5CF6),
        users: filteredInspectors,
        isVisible: true,
      ),
      _UserSection(
        key: 'washers',
        title: 'Washers',
        icon: Icons.local_car_wash_rounded,
        color: const Color(0xFF10B981),
        users: filteredWashers,
        isVisible: true,
      ),
    ];

    final visibleSections = sections
        .where((section) => section.isVisible && section.users.isNotEmpty)
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < visibleSections.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == visibleSections.length - 1 ? 0 : 20),
              child: _buildCollapsibleSection(visibleSections[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection(_UserSection section) {
    final isCollapsed = _collapsedSections[section.key] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          section.title,
          section.icon,
          section.color,
          section.users.length,
          isCollapsed,
          () => _toggleSection(section.key),
        ),
        if (!isCollapsed) ...[
          const SizedBox(height: 12),
          _buildUserGrid(section.users, section.color, section.icon),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    int count,
    bool isCollapsed,
    VoidCallback onToggle,
  ) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.06)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserGrid(List<Map<String, dynamic>> users, Color color, IconData icon) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        return _buildCompactUserCard(users[index], color, icon);
      },
    );
  }

  Widget _buildCompactUserCard(Map<String, dynamic> user, Color color, IconData icon) {
    final hasTeam = user['team'] != null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, color.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _switchToUser(user),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  user['username'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
                if (hasTeam) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
                    ),
                    child: Text(
                      user['team'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _UserSection {
  const _UserSection({
    required this.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.users,
    required this.isVisible,
  });

  final String key;
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> users;
  final bool isVisible;
}