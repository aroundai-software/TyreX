// lib/utils/app_constants.dart

class AppConstants {
  // Status Constants
  static const String statusCompleted = 'Completed';
  static const String statusOngoing = 'Ongoing';
  static const String statusWorkInProgress = 'Work in Progress';
  static const String statusNotStarted = 'Not Started';

  static const String statusCancelled = 'Cancelled';
  static const String statusAwaitingExecutiveAssignment = 'pending_assignment';

  // Role Constants
  static const String roleAdmin = 'admin';
  static const String roleExecutive = 'executive';
  static const String roleTeleCaller = 'tele_caller';
  static const String rolePickupDropoff = 'pickup_dropoff';
  static const String roleAccountant = 'accountant';
  static const String roleAlignmentTech = 'alignment_tech';
  static const String roleInstallationTech = 'installation_tech';

  // Tech roles for dynamic dropdowns
  static const List<String> techRoles = [
    roleAlignmentTech,
    roleInstallationTech,
  ];

  // Billing Status Constants
  static const String statusDraft = 'Draft';
  static const String statusBilled = 'Billed';
  static const String statusPaid = 'Paid';

  // Item Type Constants
  static const String typeComplaint = 'complaint';
  static const String typeSuggestion = 'suggestion';

  // Team Constants
  static const List<String> teams = ['Accident', 'Service', 'Insurance'];

  // Fuel Type Constants
  static const List<String> fuelTypes = ['Petrol', 'Diesel', 'CNG', 'Electric'];

  // Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;

  // Validation
  static const int phoneNumberLength = 10;
  static const int minPasswordLength = 6;

  // Error Messages
  static const String errorNetworkFailure =
      'Network connection failed. Please check your internet.';
  static const String errorUnknown =
      'An unexpected error occurred. Please try again.';
  static const String errorNoData = 'No data available.';
  static const String errorInvalidInput =
      'Please check your input and try again.';

  // Success Messages
  static const String successSaved = 'Saved successfully!';
  static const String successUpdated = 'Updated successfully!';
  static const String successDeleted = 'Deleted successfully!';

  // Cache Keys
  static const String cacheKeyVehicleModels = 'vehicle_models_cache';
  static const String cacheKeySettings = 'cached_settings';
  static const String cacheKeyCurrentUser = 'currentUser';
  static const String cacheKeyOriginalAdmin = 'originalAdmin';

  // URLs
  static const String feedbackBaseUrl =
      'https://autofix-six.vercel.app/?feedback_id=';
  static const String approvalBaseUrl =
      'https://customer-approval-tyre-x.vercel.app/?report_id=';
  static const String whatsappBaseUrl = 'https://wa.me/';

  // Google Drive
  static const String parentFolderId = '1jmD_XBl_4a_FEvT3xQ9RKgH7-26gmM30';

  // Date Formats
  static const String dateFormatDisplay = 'dd/MM/yy HH:mm';
  static const String dateFormatFull = 'dd MMM yyyy, hh:mm a';
  static const String dateFormatDate = 'dd-MM-yyyy';
  static const String dateFormatISO = 'yyyy-MM-dd';
}
