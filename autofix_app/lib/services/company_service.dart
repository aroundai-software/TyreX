// lib/services/company_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class CompanyService {
  static final CompanyService _instance = CompanyService._internal();
  factory CompanyService() => _instance;
  CompanyService._internal();

  final supabase = Supabase.instance.client;

  // Cached active company data
  Map<String, dynamic>? _activeCompany;
  bool _isLoading = false;

  /// Get cached active company data
  Map<String, dynamic>? get activeCompany => _activeCompany;
  bool get isLoading => _isLoading;
  bool get hasActiveCompany => _activeCompany != null;

  /// Get company name from cached data
  String? get companyName => _activeCompany?['company_name'] as String?;
  
  /// Get GUID from cached data
  String? get guid => _activeCompany?['Guid'] as String?;

  /// Fetch and cache the single active company
  Future<void> loadActiveCompany() async {
    if (_isLoading) return;
    
    try {
      _isLoading = true;
      
      final response = await supabase
          .from('tally_companies')
          .select('id, company_name, Guid, company_alias, company_number')
          .eq('is_active', true)
          .limit(1)
          .single();
      
      _activeCompany = response;
      
      debugPrint('✅ Active company loaded: ${companyName}');
    } catch (e) {
      debugPrint('❌ Failed to load active company: $e');
      _activeCompany = null;
      throw Exception('Failed to load active company: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Manually set the active company (used when user selects from dropdown)
  /// Persists the selection to SharedPreferences so it survives app restarts
  void setActiveCompany(Map<String, dynamic> company) {
    _activeCompany = company;
    debugPrint('✅ Company set manually: ${companyName}');
    _persistCompany(company);
  }

  Future<void> _persistCompany(Map<String, dynamic> company) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_company', jsonEncode(company));
    } catch (e) {
      debugPrint('⚠️ Failed to persist company: $e');
    }
  }

  /// Load the persisted company from SharedPreferences
  Future<bool> loadPersistedCompany() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('selected_company');
      if (stored != null) {
        _activeCompany = jsonDecode(stored) as Map<String, dynamic>;
        debugPrint('✅ Company restored from prefs: ${companyName}');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load persisted company: $e');
    }
    return false;
  }

  /// Force refresh the active company data
  Future<void> refreshActiveCompany() async {
    _activeCompany = null;
    await loadActiveCompany();
  }

  /// Add company fields to any data map for insert operations
  /// [tableName] specifies which table the data is for, to handle different schemas
  Map<String, dynamic> addCompanyFields(Map<String, dynamic> data, {String? tableName}) {
    if (_activeCompany == null) {
      debugPrint('⚠️ No active company loaded - cannot add company fields');
      return data;
    }

    final result = Map<String, dynamic>.from(data);
    
    // Tables that have company_name and Guid columns
    final tablesWithCompanyFields = {
      'vehicles', 'reports', 'owner_master', 'vehicle_models', 'materials'
    };
    
    // Only add company fields for tables that support them
    if (tableName != null && tablesWithCompanyFields.contains(tableName)) {
      // Add company_name if it doesn't exist
      if (!result.containsKey('company_name')) {
        result['company_name'] = companyName;
      }
      
      // Add Guid if it doesn't exist
      if (!result.containsKey('Guid')) {
        result['Guid'] = guid;
      }
      
      debugPrint('✅ Added company fields for $tableName: company_name=$companyName, Guid=$guid');
    } else {
      debugPrint('ℹ️ Table $tableName does not support company fields - skipping auto-fill');
    }

    return result;
  }

  /// Fetch all companies from tally_companies table
  Future<List<Map<String, dynamic>>> getActiveCompanies() async {
    try {
      final response = await supabase
          .from('tally_companies')
          .select('id, company_name, Guid, company_alias, company_number')
          .order('company_name');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch companies: $e');
    }
  }

  /// Check if tally_companies table exists and has data
  Future<bool> validateCompaniesTable() async {
    try {
      final response = await supabase
          .from('tally_companies')
          .select('id')
          .limit(1);
      
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear cached company data (for testing or logout)
  void clearCache() {
    _activeCompany = null;
    debugPrint('🗑️ Company cache cleared');
    SharedPreferences.getInstance().then((prefs) => prefs.remove('selected_company'));
  }
}
