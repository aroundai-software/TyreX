// lib/services/vehicle_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_constants.dart';
import 'company_service.dart';

/// Comprehensive service for all vehicle-related operations
/// Company filtering has been removed - operations work across all data
class VehicleService {
  static final VehicleService _instance = VehicleService._internal();
  factory VehicleService() => _instance;
  VehicleService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// ===== VEHICLE OPERATIONS =====

  /// Create or update vehicle with auto-filled company fields
  Future<void> createOrUpdateVehicle(BuildContext context, Map<String, dynamic> vehicleData) async {
    // Auto-fill company fields for new vehicles
    final dataWithCompany = CompanyService().addCompanyFields(vehicleData, tableName: 'vehicles');

    final vehicleNumber = (vehicleData['Vehicle Number'] ?? '').toString();

    try {
      // Check if vehicle already exists by vehicle number
      final existingVehicle = await _client
          .from('vehicles')
          .select('id')
          .eq('"Vehicle Number"', vehicleNumber)
          .maybeSingle();

      if (existingVehicle != null) {
        // Update existing vehicle (only add company fields if not present)
        final updateData = CompanyService().addCompanyFields(vehicleData, tableName: 'vehicles');
        await _client
            .from('vehicles')
            .update(updateData)
            .eq('id', existingVehicle['id']);
      } else {
        // Insert new vehicle with company fields
        await _client.from('vehicles').insert(dataWithCompany);
      }
    } catch (e) {
      throw Exception('Failed to create/update vehicle: $e');
    }
  }

  /// Search vehicle without company filtering
  Future<Map<String, dynamic>?> searchVehicle(BuildContext context, String vehicleNumber) async {
    // Company selection has been removed, search across all vehicles
    try {
      final response = await _client
          .from('vehicles')
          .select('*')
          .eq('"Vehicle Number"', vehicleNumber)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Failed to search vehicle: $e');
    }
  }

  /// Get all vehicles without company filtering
  Future<List<Map<String, dynamic>>> getCompanyVehicles(BuildContext context) async {
    // Company selection has been removed, fetch all vehicles
    try {
      final response = await _client
          .from('vehicles')
          .select('*, vehicle_models(brand, "Model name")')
          .order('"Vehicle Number"');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch vehicles: $e');
    }
  }

  /// ===== REPORT/JOB CARD OPERATIONS =====

  /// Create report with auto-filled company fields
  Future<Map<String, dynamic>> createReport(BuildContext context, Map<String, dynamic> reportData) async {
    if (!CompanyService().hasActiveCompany) {
      debugPrint('⚠️ VehicleService: No company selected - Guid will not be saved');
    } else {
      debugPrint('ℹ️ VehicleService: Company Guid=${CompanyService().guid}');
    }

    // Auto-fill company fields for new reports
    final dataWithCompany = CompanyService().addCompanyFields(reportData, tableName: 'reports');

    try {
      final response = await _client.from('reports').insert(dataWithCompany).select().single();
      debugPrint('🟢 VehicleService: Report inserted successfully');
      return response;
    } catch (e) {
      debugPrint('🔴 VehicleService: Failed to insert report: $e');
      throw Exception('Failed to create report: $e');
    }
  }

  /// Update report without company filtering
  Future<void> updateReport(BuildContext context, int reportId, Map<String, dynamic> updateData) async {
    // Company selection has been removed, proceed without company filtering
    final dataWithCompany = updateData; // Use data as-is without adding company

    try {
      // Update report directly without company validation
      await _client.from('reports').update(dataWithCompany).eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to update report: $e');
    }
  }

  /// Get all reports without company filtering
  Future<List<Map<String, dynamic>>> getCompanyReports(BuildContext context, {int? executiveId}) async {
    // Company selection has been removed, fetch all reports
    try {
      var query = _client
          .from('reports')
          .select('''
            id, created_at, status, complaint, suggested, approved,
            client_phone, odometer_reading,
            customer_feedback_text, customer_feedback_audio,
            marks, gdrive_folder_url, booking_id, created_by_pudo_id,
            inspection_remarks,
            vehicles!reports_vehicle_fk(
              "Guid", "Vehicle Number", vehicle_name, "Color", "Engine Number", "Chasis Number",
              vehicle_models!inner(brand, "Model name")
            ),
            executive:executive_id(username)
          ''');

      if (executiveId != null) {
        query = query.eq('executive_id', executiveId);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch reports: $e');
    }
  }

  /// ===== OWNER OPERATIONS =====

  /// Create or update owner with auto-filled company fields
  Future<String> createOrUpdateOwner(BuildContext context, Map<String, dynamic> ownerData) async {
    // Auto-fill company fields for new owners
    final dataWithCompany = CompanyService().addCompanyFields(ownerData, tableName: 'owner_master');

    try {
      final mobile = (dataWithCompany['MobileNumber'] as String?)?.trim();
      final phone = (dataWithCompany['PhoneNumber'] as String?)?.trim();
      final companyName = (dataWithCompany['company_name'] as String?)?.trim();
      final guid = (dataWithCompany['Guid'] as String?)?.trim();

      final String? lookupField;
      final String? lookupValue;
      if (mobile != null && mobile.isNotEmpty) {
        lookupField = 'MobileNumber';
        lookupValue = mobile;
      } else if (phone != null && phone.isNotEmpty) {
        lookupField = 'PhoneNumber';
        lookupValue = phone;
      } else {
        lookupField = null;
        lookupValue = null;
      }

      // Check if owner already exists by phone number
      Map<String, dynamic>? existingOwner;
      if (lookupField != null && lookupValue != null) {
        var ownerQuery = _client
            .from('owner_master')
            .select('id')
            .eq(lookupField, lookupValue);

        if (companyName != null && companyName.isNotEmpty) {
          ownerQuery = ownerQuery.eq('company_name', companyName);
        }
        if (guid != null && guid.isNotEmpty) {
          ownerQuery = ownerQuery.eq('Guid', guid);
        }

        existingOwner = await ownerQuery.limit(1).maybeSingle();
      }

      if (existingOwner != null) {
        // Update existing owner (only add company fields if not present)
        final updateData = CompanyService().addCompanyFields(ownerData, tableName: 'owner_master');
        await _client
            .from('owner_master')
            .update(updateData)
            .eq('id', existingOwner['id']);
        return existingOwner['id'] as String;
      } else {
        try {
          // Insert new owner with company fields
          final response = await _client
              .from('owner_master')
              .insert(dataWithCompany)
              .select('id')
              .single();
          return response['id'] as String;
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            // Duplicate key — owner already exists but initial lookup missed them.
            // Try multiple fallback strategies to find the existing owner.
            Map<String, dynamic>? fallback;

            // Fallback 1: lookup by phone/mobile without company filter
            if (lookupField != null && lookupValue != null) {
              try {
                fallback = await _client
                    .from('owner_master')
                    .select('id')
                    .eq(lookupField, lookupValue)
                    .limit(1)
                    .maybeSingle();
              } catch (_) {}
            }

            // Fallback 2: lookup by Owner name + Guid
            final ownerName = (dataWithCompany['Owner name'] as String?)?.trim();
            if (fallback == null && ownerName != null && ownerName.isNotEmpty && guid != null && guid.isNotEmpty) {
              try {
                fallback = await _client
                    .from('owner_master')
                    .select('id')
                    .eq('Owner name', ownerName)
                    .eq('Guid', guid)
                    .limit(1)
                    .maybeSingle();
              } catch (_) {}
            }

            // Fallback 3: lookup by Guid alone (first match)
            if (fallback == null && guid != null && guid.isNotEmpty) {
              try {
                fallback = await _client
                    .from('owner_master')
                    .select('id')
                    .eq('Guid', guid)
                    .limit(1)
                    .maybeSingle();
              } catch (_) {}
            }

            if (fallback != null) {
              debugPrint('⚠️ Owner already exists (duplicate key), using existing id=${fallback['id']}');
              return fallback['id'] as String;
            }
            rethrow;
          }
          rethrow;
        }
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to create/update owner: $e');
    } catch (e) {
      throw Exception('Failed to create/update owner: $e');
    }
  }

  /// ===== BOOKING OPERATIONS =====

  /// Create booking without company filtering
  Future<void> createBooking(BuildContext context, Map<String, dynamic> bookingData) async {
    // bookings table doesn't have company fields, use data as-is
    final dataWithCompany = bookingData;

    try {
      await _client.from('bookings').insert(dataWithCompany);
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  /// Get all bookings without company filtering
  Future<List<Map<String, dynamic>>> getCompanyBookings(BuildContext context) async {
    // Company selection has been removed, fetch all bookings
    try {
      final response = await _client
          .from('bookings')
          .select('*, assigned_pudo:assigned_pudo_id(username)')
          .neq('status', AppConstants.statusCompleted)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch bookings: $e');
    }
  }

  /// ===== SERVICE REMINDER OPERATIONS =====

  /// Create service reminder without company filtering
  Future<void> createServiceReminder(BuildContext context, Map<String, dynamic> reminderData) async {
    // Company selection has been removed, proceed without company filtering
    final dataWithCompany = reminderData; // Use data as-is without adding company

    try {
      await _client.from('service_reminders').insert(dataWithCompany);
    } catch (e) {
      throw Exception('Failed to create service reminder: $e');
    }
  }

  /// Get all service reminders without company filtering
  Future<List<Map<String, dynamic>>> getCompanyServiceReminders(BuildContext context) async {
    // Company selection has been removed, fetch all service reminders
    try {
      final response = await _client
          .from('service_reminders')
          .select('*')
          .order('next_service_due_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch service reminders: $e');
    }
  }

  /// ===== UTILITY METHODS =====

  /// Validate data (company validation disabled)
  bool validateDataOwnership(BuildContext context, Map<String, dynamic> data) {
    // Company selection has been removed, always return true
    return true;
  }

  /// Filter data (company filtering disabled)
  List<Map<String, dynamic>> filterByCurrentCompany(BuildContext context, List<Map<String, dynamic>> data) {
    // Company selection has been removed, return data as-is
    return data;
  }

  /// Get company name (disabled)
  String? getCurrentCompanyName(BuildContext context) {
    // Company selection has been removed
    return null;
  }
}
