// lib/utils/company_demo.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/app_supabase_service.dart';
import '../services/company_service.dart';

/// Demo utility showing how to use company-based data isolation
class CompanyDemo {
  
  /// Example: How to fetch vehicles for the current company
  static Future<void> demoVehicleSearch(BuildContext context) async {
    final appSupabaseService = AppSupabaseService();
    
    try {
      // This will automatically filter by the current user's selected company
      final vehicle = await appSupabaseService.searchVehicle(context, 'KA-01-AB-1234');
      
      if (vehicle != null) {
        print('Found vehicle: ${vehicle['Vehicle Number']} for company: ${vehicle['company_name']}');
      } else {
        print('Vehicle not found for current company');
      }
    } catch (e) {
      print('Error searching vehicle: $e');
    }
  }
  
  /// Example: How to save a report with company filtering
  static Future<void> demoSaveReport(BuildContext context) async {
    final appSupabaseService = AppSupabaseService();
    
    final reportData = {
      'vehicle_id': 1,
      'complaint': 'Engine noise',
      'status': 'Not Started',
      'created_at': DateTime.now().toIso8601String(),
    };
    
    try {
      // This will automatically add the current company's name to the report
      await appSupabaseService.saveReport(context, reportData);
      print('Report saved successfully with company filtering');
    } catch (e) {
      print('Error saving report: $e');
    }
  }
  
  /// Example: How to fetch reports for current user and company
  static Future<void> demoFetchReports(BuildContext context) async {
    final appSupabaseService = AppSupabaseService();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    try {
      // This will automatically filter by current user's ID and company
      final reports = await appSupabaseService.getAllReportsForUser(context, userProvider.userId!);
      
      print('Found ${reports.length} reports (company selection disabled)');
      for (var report in reports) {
        print('- Report ID: ${report['id']}, Company: ${report['company_name']}');
      }
    } catch (e) {
      print('Error fetching reports: $e');
    }
  }
  
  /// Example: How to create or update an owner with company filtering
  static Future<void> demoOwnerManagement(BuildContext context) async {
    final appSupabaseService = AppSupabaseService();
    
    final ownerData = {
      'Owner name': 'John Doe',
      'MobileNumber': '+1234567890',
      'Address Line1': '123 Main St',
      'city': 'Bangalore',
      'created_at': DateTime.now().toIso8601String(),
    };
    
    try {
      // This will automatically add the current company's name to the owner
      final ownerId = await appSupabaseService.createOrUpdateOwner(context, ownerData);
      print('Owner created/updated with ID: $ownerId');
    } catch (e) {
      print('Error managing owner: $e');
    }
  }
  
  /// Example: How to fetch available companies
  static Future<void> demoFetchCompanies() async {
    final companyService = CompanyService();
    
    try {
      final companies = await companyService.getActiveCompanies();
      
      print('Found ${companies.length} active companies:');
      for (var company in companies) {
        print('- ${company['company_name']} (ID: ${company['id']})');
      }
    } catch (e) {
      print('Error fetching companies: $e');
    }
  }
  
  /// Example: How to check current company selection
  static void demoCurrentCompany(BuildContext context) {
    print('Company selection has been disabled');
  }
  
  /// Complete demo showing the entire workflow
  static Future<void> runCompleteDemo(BuildContext context) async {
    print('=== Company-Based Data Isolation Demo ===\n');
    
    // 1. Show current company selection
    demoCurrentCompany(context);
    print('');
    
    // 2. Fetch available companies
    print('Fetching available companies...');
    await demoFetchCompanies();
    print('');
    
    // 3. Search vehicle (company-filtered)
    print('Searching vehicle with company filtering...');
    await demoVehicleSearch(context);
    print('');
    
    // 4. Save report (with company name)
    print('Saving report with company filtering...');
    await demoSaveReport(context);
    print('');
    
    // 5. Fetch reports (company-filtered)
    print('Fetching reports with company filtering...');
    await demoFetchReports(context);
    print('');
    
    // 6. Manage owner (with company name)
    print('Managing owner with company filtering...');
    await demoOwnerManagement(context);
    print('');
    
    print('=== Demo Complete ===');
  }
}
