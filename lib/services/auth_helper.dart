// lib/services/auth_helper.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/report_provider.dart';

class AuthHelper {
  static Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final originalAdmin = prefs.getString('originalAdmin');

    // ✅ Clear all report cache before logout
    reportProvider.clearCache();
    debugPrint('🗑️ AuthHelper: Cleared report cache during logout');

    if (originalAdmin != null) {
      try {
        userProvider.setUser(jsonDecode(originalAdmin));

        await prefs.setString('currentUser', originalAdmin);
        await prefs.remove('originalAdmin');

        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              (route) => false,
        );

        if (!context.mounted) return;
        // Commented out to reduce UI noise
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: const Text('Returned to admin dashboard'),
        //     backgroundColor: Colors.green,
        //     behavior: SnackBarBehavior.floating,
        //     shape: RoundedRectangleBorder(
        //       borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
        //     ),
        //     margin: const EdgeInsets.all(16),
        //   ),
        // );
      } catch (e) {
        await _performNormalLogout(context, prefs, userProvider, reportProvider);
      }
    } else {
      await _performNormalLogout(context, prefs, userProvider, reportProvider);
    }
  }

  static Future<void> _performNormalLogout(
      BuildContext context,
      SharedPreferences prefs,
      UserProvider userProvider,
      ReportProvider reportProvider,
      ) async {
    await prefs.remove('currentUser');
    await prefs.remove('originalAdmin');

    if (!context.mounted) return;
    userProvider.setUser(null);

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }


  /// Check if currently in a Quick Access session
  static Future<bool> isQuickAccessSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('originalAdmin');
  }

  /// Get the button text for logout (changes based on session type)
  static Future<String> getLogoutButtonText() async {
    final isQuickAccess = await isQuickAccessSession();
    return isQuickAccess ? 'Return to Admin' : 'Logout';
  }
}