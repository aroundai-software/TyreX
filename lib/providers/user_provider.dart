// lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import '../services/company_service.dart';

class UserProvider with ChangeNotifier {
  // Private variable to hold the current user data.
  Map<String, dynamic>? _user;
  
  // Public getter to safely expose the user data to the rest of the app.
  Map<String, dynamic>? get user => _user;
  
  /// Sets the current user (e.g., on login or session restore).
  /// Pass `null` to log out.
  void setUser(Map<String, dynamic>? userData) async {
    _user = userData;
    notifyListeners();
    
    if (userData == null) {
      // Clear company cache on logout
      CompanyService().clearCache();
    }
  }
  
  int? get userId => _user?['id'] as int?;

  /// Switches to another user (used during Quick Access impersonation).
  void switchToUser(Map<String, dynamic> user) {
    _user = user;
    notifyListeners();
  }

  /// Restores the original admin session after Quick Access.
  void restoreOriginalAdmin(Map<String, dynamic> adminUser) {
    _user = adminUser;
    notifyListeners();
  }

  /// Initialize provider and load active company (called during app startup)
  Future<void> initialize() async {
    if (!CompanyService().hasActiveCompany) {
      // First try to restore from SharedPreferences (user's previous selection)
      final restored = await CompanyService().loadPersistedCompany();
      if (!restored) {
        // Fall back to DB query only if nothing was persisted
        try {
          await CompanyService().loadActiveCompany();
        } catch (e) {
          debugPrint('⚠️ Failed to load active company during initialization: $e');
        }
      }
    }
  }
}