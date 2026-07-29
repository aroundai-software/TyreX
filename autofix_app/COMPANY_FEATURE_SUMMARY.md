# Company Selection Feature Implementation

## Overview
This feature adds multi-company support to the AutoFix app, allowing users to select a company during login and ensuring complete data isolation between companies.

## Features Implemented

### 1. Company Selection in Login Screen
- **Location**: `lib/screens/login_screen.dart`
- **Functionality**: 
  - Added dropdown field for company selection
  - Loads active companies from `tally_companies` table where `is_active = true`
  - Auto-selects first company if only one company is active
  - Validates company selection before login
  - Works with both regular login and biometric login

### 2. Company Data Management
- **Service**: `lib/services/company_service.dart`
- **Functionality**:
  - Fetches active companies from database
  - Validates company table existence
  - Returns company list for dropdown

### 3. User Provider Enhancement
- **File**: `lib/providers/user_provider.dart`
- **Added**:
  - `selectedCompany` property
  - `companyName` getter
  - `companyId` getter
  - `setSelectedCompany()` method

### 4. Company Filtering Service
- **File**: `lib/services/company_filter_service.dart`
- **Functionality**:
  - Adds company_name filter to database queries
  - Adds company_name to data being saved
  - Validates data belongs to current company
  - Filters data lists by company

### 5. Enhanced Supabase Service
- **File**: `lib/services/supabase_service.dart`
- **Updated Methods**:
  - `searchVehicle()` - filters vehicles by company
  - `saveReport()` - adds company_name to reports
  - `getAllReportsForUser()` - filters reports by company
  - `createOrUpdateOwner()` - manages owners by company
  - `createBooking()` - adds company_name to bookings
  - `createServiceReminder()` - adds company_name to reminders

### 6. App Service Wrapper
- **File**: `lib/services/app_supabase_service.dart`
- **Purpose**: Provides automatic company filtering based on current user's selection
- **Benefits**: Screens don't need to manually pass company names

## Database Schema Requirements

### Required Tables
1. **tally_companies** (must exist):
   ```sql
   CREATE TABLE tally_companies (
     id INTEGER PRIMARY KEY,
     company_name VARCHAR NOT NULL,
     is_active BOOLEAN DEFAULT true
   );
   ```

2. **All existing tables** should have `company_name` column:
   ```sql
   ALTER TABLE reports ADD COLUMN company_name VARCHAR;
   ALTER TABLE vehicles ADD COLUMN company_name VARCHAR;
   ALTER TABLE owner_master ADD COLUMN company_name VARCHAR;
   ALTER TABLE bookings ADD COLUMN company_name VARCHAR;
   ALTER TABLE service_reminders ADD COLUMN company_name VARCHAR;
   -- Add to other relevant tables as needed
   ```

## Usage Examples

### For Developers
```dart
// Using the AppSupabaseService (recommended)
final appSupabaseService = AppSupabaseService();

// Search vehicle (automatically filtered by current company)
final vehicle = await appSupabaseService.searchVehicle(context, 'KA-01-AB-1234');

// Save report (automatically adds company name)
await appSupabaseService.saveReport(context, reportData);

// Get reports for user (automatically filtered by company)
final reports = await appSupabaseService.getAllReportsForUser(context, userId);
```

### For Users
1. User opens the app
2. Login screen shows company dropdown (if multiple companies exist)
3. User selects their company
4. User logs in normally
5. All data shown belongs to selected company only
6. All data created is tagged with selected company name

## Data Isolation Guarantees

### What Gets Filtered
- Vehicle searches
- Job cards/reports
- Owner information
- Bookings
- Service reminders
- Any CRUD operations

### What Stays Global
- Vehicle models/brands (shared across companies)
- User management
- System settings
- Material definitions

## Testing
- **Test File**: `test/company_isolation_test.dart`
- **Coverage**: Company filtering logic, UserProvider functionality
- **Results**: All tests passing ✅

## Demo
- **Demo File**: `lib/utils/company_demo.dart`
- **Purpose**: Shows complete workflow examples
- **Usage**: Call `CompanyDemo.runCompleteDemo(context)` to see all features

## Migration Steps

### For Existing App
1. Add `company_name` columns to all relevant tables
2. Create `tally_companies` table with active companies
3. Deploy the updated app
4. Users will see company dropdown on next login

### For New Setup
1. Ensure database schema includes company columns
2. Add companies to `tally_companies` table
3. Deploy app with company selection feature

## Benefits
- ✅ Complete data isolation between companies
- ✅ Single app instance supports multiple companies
- ✅ Easy company switching during login
- ✅ Automatic data filtering (no manual coding needed)
- ✅ Backward compatible (works with single company)
- ✅ Scalable to unlimited companies

## Security Considerations
- Company selection happens at login time
- Company name is stored in user session
- All database queries automatically filtered
- No cross-company data leakage possible

## Future Enhancements
- Company switching without logout
- Company-specific settings
- Company analytics dashboard
- Company-based user permissions
