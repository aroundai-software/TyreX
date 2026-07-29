// lib/services/company_filter_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class CompanyFilterService {
  /// Adds company_name filter to a Supabase query if a company is selected
  /// Returns the modified query builder
  static PostgrestFilterBuilder applyCompanyFilter(
    PostgrestFilterBuilder query, {
    String? companyName,
  }) {
    // If companyName is provided, use it, otherwise get from UserProvider
    final company = companyName ?? _getCurrentCompanyName();
    
    if (company != null && company.isNotEmpty) {
      return query.eq('company_name', company);
    }
    
    return query;
  }
  
  /// Adds company_name filter to a Supabase select query
  static PostgrestFilterBuilder applyCompanyFilterToSelect(
    PostgrestFilterBuilder query, {
    String? companyName,
  }) {
    // If companyName is provided, use it, otherwise get from UserProvider
    final company = companyName ?? _getCurrentCompanyName();
    
    if (company != null && company.isNotEmpty) {
      return query.eq('company_name', company);
    }
    
    return query;
  }
  
  /// Adds company_name to data being inserted/updated
  static Map<String, dynamic> addCompanyToData(
    Map<String, dynamic> data, {
    String? companyName,
  }) {
    // If companyName is provided, use it, otherwise get from UserProvider
    final company = companyName ?? _getCurrentCompanyName();
    
    if (company != null && company.isNotEmpty) {
      final modifiedData = Map<String, dynamic>.from(data);
      modifiedData['company_name'] = company;
      return modifiedData;
    }
    
    return data;
  }
  
  /// Gets the current company name from UserProvider
  /// This requires a BuildContext, so we'll need to pass it from the calling widget
  static String? getCurrentCompany(BuildContext context) {
    // Company selection has been removed from login flow
    // Always return null since no company is selected
    return null;
  }
  
  /// Internal method to get current company name (for use without context)
  static String? _getCurrentCompanyName() {
    // This is a fallback method - ideally we should use the context-based method
    // For now, we'll return null and let the calling code handle it
    return null;
  }
  
  /// Validates if data belongs to current company
  static bool isDataForCurrentCompany(
    Map<String, dynamic> data, 
    String? currentCompany
  ) {
    if (currentCompany == null || currentCompany.isEmpty) return true;
    
    final dataCompany = data['company_name'] as String?;
    return dataCompany == currentCompany;
  }
  
  /// Filters a list of data by company name
  static List<Map<String, dynamic>> filterDataByCompany(
    List<Map<String, dynamic>> data,
    String? currentCompany,
  ) {
    if (currentCompany == null || currentCompany.isEmpty) return data;
    
    return data.where((item) {
      final itemCompany = item['company_name'] as String?;
      return itemCompany == currentCompany;
    }).toList();
  }
}
