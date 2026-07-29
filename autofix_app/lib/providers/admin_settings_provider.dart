import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/admin_setting_model.dart';
import '../services/supabase_service.dart';

class AdminSettingsProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  Map<String, AdminSettingModel> _settings = {};
  bool _isLoading = true;
  String? _error;

  // Cache management
  DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const String _cacheKey = 'admin_settings_cache';
  static const String _cacheTimeKey = 'admin_settings_cache_time';

  bool get isLoading => _isLoading;

  String? get error => _error;

  Map<String, AdminSettingModel> get allSettings => _settings;

  bool _getBoolValue(String key, {bool defaultValue = false}) {
    final setting = _settings[key];
    return (setting?.value is bool) ? setting!.value : defaultValue;
  }

  bool _hasMetadataInSettings() {
    if (_settings.isEmpty) return false;
    for (final s in _settings.values) {
      if (s.displayOrder != 999 || s.category != 'General') {
        return true;
      }
    }
    return false;
  }

  // Feature Toggles matching your web app
  bool get featureScanner =>
      _getBoolValue('feature_scanner', defaultValue: true);

  bool get featureDamageMarking =>
      _getBoolValue('feature_damage_marking', defaultValue: true);

  bool get featureGdrive => _getBoolValue('feature_gdrive', defaultValue: true);

  bool get featureWhatsappApproval =>
      _getBoolValue('feature_whatsapp_approval');

  bool get featureReportsDownload => _getBoolValue('feature_reports_download');

  bool get featureInspectionModule =>
      _getBoolValue('feature_inspection_module');

  bool get featureWashModule => _getBoolValue('feature_wash_module');

  bool get featureTelecallerModule =>
      _getBoolValue('feature_telecaller_module', defaultValue: true);

  bool get featurePudoModule =>
      _getBoolValue('feature_pudo_module', defaultValue: true);

  bool get featureAnalyticsPage =>
      _getBoolValue('feature_analytics_page', defaultValue: true);

  bool get showFullVehicleForm =>
      _getBoolValue('show_full_vehicle_form', defaultValue: true);

  bool get featureBiometricAuth =>
      _getBoolValue('feature_biometric_auth', defaultValue: true);

  bool get featureJobCardDownload =>
      _getBoolValue('feature_reports_download', defaultValue: false);

  /// A flag to check if the initial settings load has been attempted.
  bool get hasLoadedOnce => _settings.isNotEmpty || _error != null;

  List<String> get visibleReportColumns {
    final setting = _settings['visible_report_columns'];
    if (setting?.value is List) {
      // FIXED: Safely convert list elements to prevent runtime cast errors.
      // This ensures that only String values are included in the final list.
      return (setting!.value as List).whereType<String>().toList();
    }
    // Default columns if not set
    return [
      'vehicle_no',
      'client_name',
      'executive',
      'date_time',
      'status',
      'media'
    ];
  }

  /// Load settings with caching support
  /// Set [forceRefresh] to true to bypass cache and fetch from database
  Future<void> loadSettings({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheExpiry &&
        _settings.isNotEmpty) {
      final hasMetadata = _hasMetadataInSettings();
      if (hasMetadata) {
        debugPrint('✅ Using cached admin settings (age: ${DateTime.now().difference(_lastFetchTime!).inMinutes}m)');
        return;
      } else {
        debugPrint('⚠️ Cached settings missing metadata, refreshing from database');
      }
    }

    try {
      if (!_isLoading) {
        _isLoading = true;
        notifyListeners();
      }

      debugPrint('🔄 Fetching admin settings from database...');
      final settingsList = await _supabaseService.getAdminSettings();
      _settings = {for (var s in settingsList) s.key: s};
      _lastFetchTime = DateTime.now();
      _error = null;

      // Cache to local storage
      await _cacheSettings();
      debugPrint('✅ Admin settings loaded and cached (${_settings.length} settings)');
    } catch (e) {
      debugPrint('❌ Failed to load settings from database: $e');
      _error = "Failed to load settings: $e";

      // Try to load from local cache as fallback
      await _loadCachedSettings();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cache settings to local storage
  Future<void> _cacheSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert settings to JSON using model's toJson method
      final settingsJson = _settings.map((key, value) => MapEntry(key, value.toJson()));

      await prefs.setString(_cacheKey, jsonEncode(settingsJson));
      await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
      debugPrint('💾 Settings cached to local storage');
    } catch (e) {
      debugPrint('⚠️ Failed to cache settings: $e');
      // Non-critical error, don't throw
    }
  }

  /// Load cached settings from local storage
  Future<void> _loadCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final cacheTimeStr = prefs.getString(_cacheTimeKey);

      if (cachedJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        _settings = decoded.map((key, value) {
          // Parse timestamps
          DateTime? createdAt;
          DateTime? updatedAt;
          try {
            if (value['created_at'] != null) {
              createdAt = DateTime.parse(value['created_at']);
            }
            if (value['updated_at'] != null) {
              updatedAt = DateTime.parse(value['updated_at']);
            }
          } catch (e) {
            // Ignore timestamp parsing errors
          }
          
          return MapEntry(
            key,
            AdminSettingModel(
              key: value['key'],
              value: value['value'],
              label: value['label'] ?? key,
              description: value['description'] ?? '',
              category: value['category'] ?? 'General',
              type: value['type'] ?? 'toggle',
              displayOrder: value['display_order'] ?? 999,
              inputType: value['input_type'],
              inputConfig: value['input_config'],
              defaultValue: value['default_value'],
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );
        });

        if (cacheTimeStr != null) {
          _lastFetchTime = DateTime.parse(cacheTimeStr);
          final age = DateTime.now().difference(_lastFetchTime!);
          debugPrint('📦 Loaded ${_settings.length} settings from cache (age: ${age.inMinutes}m)');
        }

        _error = null; // Clear error since we have cached data
      } else {
        debugPrint('⚠️ No cached settings found');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load cached settings: $e');
      // Non-critical error, settings will remain empty
    }
  }

  /// Clear cached settings (useful for debugging or logout)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimeKey);
      _lastFetchTime = null;
      debugPrint('🗑️ Settings cache cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear cache: $e');
    }
  }

  Future<void> updateSetting(String key, dynamic newValue) async {
    final originalSetting = _settings[key];
    if (originalSetting == null) return;

    // Optimistic update: CREATE A NEW MODEL
    final updatedSetting = originalSetting.copyWith(
      value: newValue,
      // keep all metadata (label, description, category, type, displayOrder, inputType, inputConfig, defaultValue)
    );

    // Replace in map
    _settings = Map<String, AdminSettingModel>.from(_settings)
      ..[key] = updatedSetting;

    notifyListeners(); // ✅ Now the map has a new reference

    try {
      await _supabaseService.updateAdminSetting(updatedSetting);

      // Update cache after successful save
      await _cacheSettings();
      debugPrint('✅ Setting "$key" updated and cached');
    } catch (e) {
      // Revert on error
      _settings = Map<String, AdminSettingModel>.from(_settings)
        ..[key] = originalSetting;
      _error = "Failed to save setting '$key': $e";
      notifyListeners();
      rethrow;
    }
  }

  // BONUS: Refresh settings from database (bypasses cache)
  Future<void> refreshSettings() async {
    await loadSettings(forceRefresh: true);
  }

  /// Get cache age in minutes (useful for debugging)
  int? get cacheAgeMinutes {
    if (_lastFetchTime == null) return null;
    return DateTime.now().difference(_lastFetchTime!).inMinutes;
  }

  /// Check if cache is expired
  bool get isCacheExpired {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) >= _cacheExpiry;
  }
}