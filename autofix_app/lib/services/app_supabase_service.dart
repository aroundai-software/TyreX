// lib/services/app_supabase_service.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/admin_setting_model.dart';
import '../services/company_filter_service.dart';

/// A wrapper service around SupabaseService that automatically handles company filtering
/// based on the current user's selected company
class AppSupabaseService {
  static final AppSupabaseService _instance = AppSupabaseService._internal();
  factory AppSupabaseService() => _instance;
  AppSupabaseService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  /// Get current company name from context
  String? _getCurrentCompany(BuildContext context) {
    return null; // Company selection removed
  }

  /// Search vehicle with automatic company filtering
  Future<Map<String, dynamic>?> searchVehicle(BuildContext context, String vehicleNumber) async {
    final companyName = _getCurrentCompany(context);
    return await _supabaseService.searchVehicle(vehicleNumber, companyName: companyName);
  }

  /// Save report with automatic company filtering
  Future<void> saveReport(BuildContext context, Map<String, dynamic> reportData) async {
    final companyName = _getCurrentCompany(context);
    await _supabaseService.saveReport(reportData, companyName: companyName);
  }

  /// Get all reports for user with automatic company filtering
  Future<List<Map<String, dynamic>>> getAllReportsForUser(BuildContext context, int userId) async {
    final companyName = _getCurrentCompany(context);
    return await _supabaseService.getAllReportsForUser(userId, companyName: companyName);
  }

  /// Create or update owner with automatic company filtering
  Future<String> createOrUpdateOwner(BuildContext context, Map<String, dynamic> ownerData) async {
    final companyName = _getCurrentCompany(context);
    return await _supabaseService.createOrUpdateOwner(ownerData, companyName: companyName);
  }

  /// Get vehicle models (no company filtering needed for global data)
  Future<List<Map<String, dynamic>>> getVehicleModels() async {
    return await _supabaseService.getVehicleModels();
  }

  /// Get active materials with company filtering
  Future<List<Map<String, dynamic>>> getAllMaterials(BuildContext context) async {
    // TODO: Add company filtering to materials when materials table has company_name column
    return await _supabaseService.getAllMaterials();
  }

  /// Get unassigned reports with company filtering
  Future<List<Map<String, dynamic>>> getUnassignedReports(BuildContext context) async {
    // TODO: Add company filtering to unassigned reports - need to update SupabaseService method first
    return await _supabaseService.getUnassignedReports();
  }

  /// Claim job with company filtering
  Future<void> claimJob(BuildContext context, int reportId, int executiveId) async {
    // TODO: Add company filtering when claiming jobs - need to update SupabaseService method first
    return await _supabaseService.claimJob(reportId, executiveId);
  }

  /// Create booking with company filtering
  Future<void> createBooking(BuildContext context, Map<String, dynamic> bookingData) async {
    final companyName = _getCurrentCompany(context);
    final dataWithCompany = CompanyFilterService.addCompanyToData(bookingData, companyName: companyName);
    return await _supabaseService.createBooking(dataWithCompany);
  }

  /// Get open bookings with company filtering
  Future<List<Map<String, dynamic>>> getOpenBookings(BuildContext context) async {
    // TODO: Add company filtering to open bookings - need to update SupabaseService method first
    return await _supabaseService.getOpenBookings();
  }

  /// Create service reminder with company filtering
  Future<void> createServiceReminder(BuildContext context, int reportId) async {
    final companyName = _getCurrentCompany(context);
    return await _supabaseService.createServiceReminder(reportId, companyName: companyName);
  }

  /// Get due service reminders with company filtering
  Future<List<Map<String, dynamic>>> getDueServiceReminders(BuildContext context) async {
    // TODO: Add company filtering to service reminders - need to update SupabaseService method first
    return await _supabaseService.getDueServiceReminders();
  }

  /// Get jobs awaiting executive assignment with company filtering
  Future<List<Map<String, dynamic>>> getJobsAwaitingExecutiveAssignment(BuildContext context) async {
    // TODO: Add company filtering to jobs awaiting assignment - need to update SupabaseService method first
    return await _supabaseService.getJobsAwaitingExecutiveAssignment();
  }

  /// Get jobs for feedback with company filtering
  Future<List<Map<String, dynamic>>> getJobsForFeedback(BuildContext context) async {
    // TODO: Add company filtering to jobs for feedback - need to update SupabaseService method first
    return await _supabaseService.getJobsForFeedback();
  }

  /// Get all service reminders with company filtering
  Future<List<Map<String, dynamic>>> getAllServiceReminders(BuildContext context) async {
    // TODO: Add company filtering to all service reminders - need to update SupabaseService method first
    return await _supabaseService.getAllServiceReminders();
  }

  // Delegate other methods that don't need company filtering
  Future<void> updateAdminSetting(AdminSettingModel setting) => _supabaseService.updateAdminSetting(setting);
  Future<List<AdminSettingModel>> getAdminSettings() => _supabaseService.getAdminSettings();
  Future<List<Map<String, dynamic>>> getPudoUsers() => _supabaseService.getPudoUsers();
  Future<void> assignBooking(int bookingId, int pudoId) => _supabaseService.assignBooking(bookingId, pudoId);
  Future<List<Map<String, dynamic>>> getExecutiveUsers() => _supabaseService.getExecutiveUsers();
  Future<List<Map<String, dynamic>>> getExecutiveWorkload() => _supabaseService.getExecutiveWorkload();
  Future<List<Map<String, dynamic>>> getAssignedPickups(int pudoId) => _supabaseService.getAssignedPickups(pudoId);
  Future<List<Map<String, dynamic>>> getJobsCreatedByPudo(int pudoId) => _supabaseService.getJobsCreatedByPudo(pudoId);
  Future<List<Map<String, dynamic>>> getPudoWorkload() => _supabaseService.getPudoWorkload();
  Future<void> updateServiceReminderStatus(int reminderId, String status, {String? notes}) => _supabaseService.updateServiceReminderStatus(reminderId, status, notes: notes);
  Future<void> assignJobToExecutive(int reportId, int executiveId) => _supabaseService.assignJobToExecutive(reportId, executiveId);
  Future<List<Map<String, dynamic>>> getAssignedBookingsForExecutive(int executiveId) => _supabaseService.getAssignedBookingsForExecutive(executiveId);
  Future<List<Map<String, dynamic>>> searchMaterials(String query) => _supabaseService.searchMaterials(query);
  Future<List<Map<String, dynamic>>> getMaterialsByCategory(String category) => _supabaseService.getMaterialsByCategory(category);
  Future<List<String>> getMaterialCategories() => _supabaseService.getMaterialCategories();
  Future<void> updateOwner(String ownerId, Map<String, dynamic> ownerData) => _supabaseService.updateOwner(ownerId, ownerData);
}
