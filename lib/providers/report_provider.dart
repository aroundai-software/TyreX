// lib/providers/report_provider.dart
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import '../services/company_service.dart';

class ReportProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final CacheService _cacheService = CacheService();

  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _unassignedReports = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreReports = true;
  String? _error;

  List<Map<String, dynamic>> get reports => _reports;
  List<Map<String, dynamic>> get unassignedReports => _unassignedReports;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreReports => _hasMoreReports;
  String? get error => _error;

  // Core fetching logic. Assumes the caller manages _isLoading state.
  Future<void> _performFetch(int userId, {bool forceRefresh = false, bool isAdminMode = false}) async {
    try {
      // Check cache first (only if not forcing refresh)
      if (!forceRefresh) {
        final cacheKey = isAdminMode ? 'reports_admin' : 'reports_$userId';
        final cached = _cacheService.get<List<Map<String, dynamic>>>(cacheKey);
        
        if (cached != null && !_isLoading) {
          _reports = cached;
          notifyListeners();
        }
      }

      if (isAdminMode) {
        final companyName = CompanyService().companyName;
        final results = await Future.wait([
          _supabaseService.getAllCompanyReports(companyName: companyName),
          _supabaseService.getUnassignedReports(),
        ]);
        _reports = results[0];
        _unassignedReports = results[1];
      } else {
        final results = await Future.wait([
          _supabaseService.getAllReportsForUser(userId),
          _supabaseService.getUnassignedReports(),
        ]);
        _reports = results[0];
        _unassignedReports = results[1];
      }
      
      // Cache the results (only if not forcing refresh)
      if (!forceRefresh) {
        final cacheKey = isAdminMode ? 'reports_admin' : 'reports_$userId';
        _cacheService.set(cacheKey, _reports, ttl: const Duration(minutes: 5));
      }
      
      _error = null; // Ensure error is null on success
      debugPrint('✅ Fetched ${_reports.length} reports, ${_unassignedReports.length} unassigned');
    } catch (e) {
      debugPrint('❌ Error fetching reports: $e');
      _error = e.toString();
      // Keep stale data on error during refresh, but ensure lists are initialized if empty (for initial load failure).
      if (_reports.isEmpty) _reports = [];
      if (_unassignedReports.isEmpty) _unassignedReports = [];
    }
  }

  /// Clear all cached report data
  void clearCache() {
    debugPrint('🗑️ ReportProvider: Clearing all cached data');
    _reports = [];
    _unassignedReports = [];
    _error = null;
    _isLoading = false;
    _isLoadingMore = false;
    _hasMoreReports = true;
    notifyListeners();
  }

  /// Clear cache for specific user
  void clearCacheForUser(int userId) {
    debugPrint('🗑️ ReportProvider: Clearing cache for userId: $userId');
    final cacheKey = 'reports_$userId';
    _cacheService.remove(cacheKey);
    
    // Also clear local data if it belongs to this user
    if (_reports.isNotEmpty) {
      _reports = [];
      _unassignedReports = [];
      notifyListeners();
    }
  }

  /// Immediately remove a single report by ID from the in-memory list.
  /// Call this right after a successful delete/cancel so the UI updates
  /// instantly without waiting for a full network refresh.
  void removeReportById(int reportId) {
    _reports.removeWhere((r) => r['id'] == reportId);
    _unassignedReports.removeWhere((r) => r['id'] == reportId);
    notifyListeners();
    debugPrint('🗑️ ReportProvider: Removed report $reportId from local list');
  }

  /// Load more reports (pagination support for future)
  Future<void> loadMore(int userId) async {
    if (_isLoadingMore || !_hasMoreReports) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      // For now, this is a placeholder for future pagination
      // When backend supports pagination, implement here
      debugPrint('🔵 loadMore called (pagination not yet implemented in backend)');
      _hasMoreReports = false; // No more pages for now
    } catch (e) {
      debugPrint('❌ Error loading more: $e');
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Method for initial load.
  Future<void> fetchReports(int userId, {bool isAdminMode = false}) async {
    debugPrint('🔵 fetchReports called with userId: $userId, isAdminMode: $isAdminMode');
    // Prevent concurrent fetches
    if (_isLoading) return;

    _isLoading = true;
    _error = null;

    try {
      await _performFetch(userId, forceRefresh: false, isAdminMode: isAdminMode);
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify UI that loading is finished
    }
  }

  // Method for explicit refresh (e.g., pull-to-refresh). Resolves the deadlock.
  Future<void> refresh(int userId, {bool isAdminMode = false}) async {
    debugPrint('🔵 refresh called with userId: $userId, isAdminMode: $isAdminMode');

    // Prevent concurrent fetches entirely.
    if (_isLoading) {
      debugPrint('🟡 Refresh skipped (already loading).');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify immediately for refresh indicator

    try {
      // ✅ Force refresh to bypass cache
      await _performFetch(userId, forceRefresh: true, isAdminMode: isAdminMode);
    } finally {
      // Ensure loading state is cleared and listeners notified at the end
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> claimJob(int reportId, int executiveId) async {
    try {
      debugPrint('🔵 Claiming job $reportId for executive $executiveId');
      await _supabaseService.claimJob(reportId, executiveId);

      debugPrint('🟡 Refreshing data...');
      // Refresh manages the loading state.
      await refresh(executiveId);

      debugPrint('🟢 Claim complete - Unassigned: ${_unassignedReports.length}, My jobs: ${_reports.length}');
    } catch (e) {
      debugPrint('❌ Error claiming job: $e');
      _error = "Failed to claim job: $e";
      notifyListeners(); // Notify UI about the error
      rethrow; // Re-throw so the UI can show a specific snackbar etc.
    }
  }

  Future<void> refreshForUser(Map<String, dynamic>? user) async {
    if (user == null) return;
    final userId = user['id'];
    if (userId is int) {
      await refresh(userId);
    } else {
      _error = 'Invalid user ID type for refreshing reports.';
      notifyListeners();
    }
  }
}