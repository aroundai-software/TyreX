// lib/services/supabase_middleware.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// Middleware service that intercepts direct Supabase operations
/// Company filtering has been removed - operations work across all data
class SupabaseMiddleware {
  static final SupabaseMiddleware _instance = SupabaseMiddleware._internal();
  factory SupabaseMiddleware() => _instance;
  SupabaseMiddleware._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Vehicle-related tables that require company filtering
  static const List<String> vehicleRelatedTables = [
    'vehicles',
    'reports',
    'owner_master',
    'bookings',
    'service_reminders',
    'vehicle_images',
    'vehicle_documents',
    'service_history',
    'vehicle_expenses',
  ];

  /// Get current company name from context
  String? _getCurrentCompany(BuildContext context) {
    return null; // Company selection removed
  }

  /// Intercept table operations and apply company filtering
  dynamic from(String table, {BuildContext? context}) {
    // Check if this is a vehicle-related table and context is provided
    if (context != null && vehicleRelatedTables.contains(table)) {
      final companyName = _getCurrentCompany(context);
      if (companyName != null && companyName.isNotEmpty) {
        // This is a vehicle-related operation, ensure company filtering
        _validateCompanyContext(context, table);
      }
    }
    
    return _client.from(table);
  }

  /// Validate that company context is available for vehicle-related operations
  void _validateCompanyContext(BuildContext context, String table) {
    final companyName = _getCurrentCompany(context);
    if (companyName == null || companyName.isEmpty) {
      throw Exception(
        'Company selection is required for $table operations. '
        'Please ensure a company is selected before performing vehicle-related operations.'
      );
    }
  }

  /// Safe insert operation without company filtering
  Future<void> safeInsert(
    BuildContext context,
    String table,
    Map<String, dynamic> data, {
    String? companyName,
  }) async {
    // Company selection has been removed, insert data as-is
    await _client.from(table).insert(data);
  }

  /// Safe update operation without company validation
  Future<void> safeUpdate(
    BuildContext context,
    String table,
    Map<String, dynamic> data,
    {required String column,
    required dynamic value,
    String? companyName,}) async {
    // Company selection has been removed, update data directly
    await _client.from(table).update(data).eq(column, value);
  }

  /// Safe delete operation without company validation
  Future<void> safeDelete(
    BuildContext context,
    String table, {
    required String column,
    required dynamic value,
    String? companyName,
  }) async {
    // Company selection has been removed, delete record directly
    await _client.from(table).delete().eq(column, value);
  }

  /// Safe select operation without company filtering
  PostgrestFilterBuilder safeSelect(
    BuildContext context,
    String table,
    String columns, {
    String? companyName,
  }) {
    // Company selection has been removed, select data directly
    return _client.from(table).select(columns);
  }

  /// Batch operation without company filtering
  Future<void> safeBatchOperation(
    BuildContext context,
    List<BatchOperation> operations,
  ) async {
    // Company selection has been removed, process operations directly
    
    for (final operation in operations) {
      // Process operations without company filtering
      switch (operation.type) {
        case BatchOperationType.insert:
          await safeInsert(context, operation.table, operation.data);
          break;
        case BatchOperationType.update:
          await safeUpdate(
            context,
            operation.table,
            operation.data,
            column: operation.column!,
            value: operation.value!,
          );
          break;
        case BatchOperationType.delete:
          await safeDelete(
            context,
            operation.table,
            column: operation.column!,
            value: operation.value!,
          );
          break;
      }
    }
  }

  /// Get all vehicle-related tables for debugging
  List<String> getVehicleRelatedTables() {
    return List.unmodifiable(vehicleRelatedTables);
  }

  /// Check if a table requires company filtering
  bool requiresCompanyFiltering(String table) {
    return vehicleRelatedTables.contains(table);
  }
}

/// Batch operation definition
class BatchOperation {
  final String table;
  final BatchOperationType type;
  final Map<String, dynamic> data;
  final String? column;
  final dynamic value;

  BatchOperation({
    required this.table,
    required this.type,
    required this.data,
    this.column,
    this.value,
  });

  Future<void> execute(SupabaseClient client) async {
    switch (type) {
      case BatchOperationType.insert:
        await client.from(table).insert(data);
        break;
      case BatchOperationType.update:
        await client.from(table).update(data).eq(column!, value!);
        break;
      case BatchOperationType.delete:
        await client.from(table).delete().eq(column!, value!);
        break;
    }
  }
}

enum BatchOperationType { insert, update, delete }
