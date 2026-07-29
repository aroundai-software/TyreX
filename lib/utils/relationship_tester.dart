// lib/utils/relationship_tester.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Utility to test and identify the correct relationship name between reports and vehicles
class RelationshipTester {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Test different relationship names to find the correct one
  static Future<String?> findCorrectRelationship() async {
    final possibleNames = [
      'vehicles!reports_guid',
      'vehicles!reports_Guid',
      'vehicles!reports_vehicle_fk',
      'vehicles!reports_vehicle_id_fkey',
      'vehicles!reports_Guid_fkey',
      'vehicles!inner',
    ];

    for (final name in possibleNames) {
      try {
        print('Testing relationship: $name');
        
        await _client
            .from('reports')
            .select('$name("Vehicle Number")')
            .limit(1);
        
        print('✅ Success with: $name');
        return name;
      } catch (e) {
        print('❌ Failed with: $name - $e');
        continue;
      }
    }
    
    return null;
  }

  /// Test the specific relationship that matches your Supabase function
  static Future<bool> testGuidRelationship() async {
    try {
      // Test if we can query using Guid relationship like your function
      await _client
          .from('reports')
          .select('''
            id,
            vehicles!inner("Guid", "Vehicle Number")
          ''')
          .limit(1);
      
      print('✅ Guid relationship works');
      return true;
    } catch (e) {
      print('❌ Guid relationship failed: $e');
      return false;
    }
  }
}
