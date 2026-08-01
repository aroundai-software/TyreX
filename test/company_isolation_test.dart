// test/company_isolation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:autofix_app/services/company_filter_service.dart';
import 'package:autofix_app/providers/user_provider.dart';

void main() {
  group('Company Isolation Tests', () {
    late UserProvider userProvider;

    setUp(() {
      userProvider = UserProvider();
    });

    test('should filter data by company name', () {
      // Test data
      final testData = [
        {'id': 1, 'name': 'Item 1', 'company_name': 'Company A'},
        {'id': 2, 'name': 'Item 2', 'company_name': 'Company B'},
        {'id': 3, 'name': 'Item 3', 'company_name': 'Company A'},
        {'id': 4, 'name': 'Item 4', 'company_name': null},
      ];

      // Filter by Company A
      final filteredData = CompanyFilterService.filterDataByCompany(testData, 'Company A');
      
      expect(filteredData.length, 2);
      expect(filteredData[0]['company_name'], 'Company A');
      expect(filteredData[1]['company_name'], 'Company A');
    });

    test('should add company name to data', () {
      final data = {'name': 'Test Item', 'value': 100};
      final dataWithCompany = CompanyFilterService.addCompanyToData(data, companyName: 'Test Company');
      
      expect(dataWithCompany['name'], 'Test Item');
      expect(dataWithCompany['value'], 100);
      expect(dataWithCompany['company_name'], 'Test Company');
    });

    test('should validate data belongs to current company', () {
      final data = {'company_name': 'Company A'};
      
      expect(CompanyFilterService.isDataForCurrentCompany(data, 'Company A'), true);
      expect(CompanyFilterService.isDataForCurrentCompany(data, 'Company B'), false);
      expect(CompanyFilterService.isDataForCurrentCompany(data, null), true);
      expect(CompanyFilterService.isDataForCurrentCompany(data, ''), true);
    });

    test('should handle empty company list gracefully', () {
      final data = {'name': 'Test Item'};
      final dataWithCompany = CompanyFilterService.addCompanyToData(data, companyName: '');
      
      expect(dataWithCompany.length, 1); // Should not add company_name if empty
      expect(dataWithCompany['name'], 'Test Item');
      expect(dataWithCompany.containsKey('company_name'), false);
    });

    test('user provider company functionality has been removed', () {
      // Company selection has been removed from the app
      // These properties and methods no longer exist
      expect(() => (userProvider as dynamic).setSelectedCompany({'id': 1, 'company_name': 'Test Company'}), 
             throwsA(isA<NoSuchMethodError>()));
    });
  });
}
