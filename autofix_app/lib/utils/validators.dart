// lib/utils/validators.dart
import 'app_constants.dart';

class Validators {
  /// Validates phone number (10 digits)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.length != AppConstants.phoneNumberLength) {
      return 'Enter a valid 10-digit phone number';
    }

    return null;
  }

  /// Validates required fields
  static String? validateRequired(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  /// Validates password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }

    return null;
  }

  /// Validates confirm password
  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Validates numeric input
  static String? validateNumber(String? value, {String fieldName = 'This field', int? min, int? max}) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    final number = int.tryParse(value);

    if (number == null) {
      return '$fieldName must be a valid number';
    }

    if (min != null && number < min) {
      return '$fieldName must be at least $min';
    }

    if (max != null && number > max) {
      return '$fieldName must not exceed $max';
    }

    return null;
  }

  /// Validates decimal number
  static String? validateDecimal(String? value, {String fieldName = 'This field', double? min, double? max}) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    final number = double.tryParse(value);

    if (number == null) {
      return '$fieldName must be a valid number';
    }

    if (min != null && number < min) {
      return '$fieldName must be at least $min';
    }

    if (max != null && number > max) {
      return '$fieldName must not exceed $max';
    }

    return null;
  }

  /// Validates vehicle number format
  static String? validateVehicleNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vehicle number is required';
    }

    final cleaned = value.toUpperCase().replaceAll(RegExp(r'[\s-]+'), '');

    // Indian vehicle number patterns
    final patterns = [
      RegExp(r'^\d{2}BH\d{4}[A-Z]{2}$'),       // BH Series
      RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{1,2}\d{4}$'), // Standard
      RegExp(r'^[A-Z]{2}\d{2}[A-Z]{1,2}\d{3,4}$'), // Generic
    ];

    final isValid = patterns.any((pattern) => pattern.hasMatch(cleaned));

    if (!isValid) {
      return 'Enter a valid vehicle number (e.g., KL07AB1234)';
    }

    return null;
  }

  /// Validates odometer reading
  static String? validateOdometer(String? value, {int? minValue}) { // Keep minValue parameter for potential future use elsewhere
    if (value == null || value.isEmpty) {
      return 'Odometer reading is required';
    }

    final reading = int.tryParse(value);

    if (reading == null) {
      return 'Enter a valid odometer reading (numbers only)';
    }

    if (reading < 0) {
      return 'Odometer reading cannot be negative';
    }

    // ✅ REMOVE THIS CHECK from the validator
    // if (minValue != null && reading < minValue) {
    //   return 'Odometer reading cannot be less than last reading ($minValue km)';
    // }

    return null; // Format is valid
  }

  /// Validates date is not in the past
  static String? validateFutureDate(DateTime? value, {String fieldName = 'Date'}) {
    if (value == null) {
      return '$fieldName is required';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(value.year, value.month, value.day);

    if (selectedDay.isBefore(today)) {
      return '$fieldName cannot be in the past';
    }

    return null;
  }

  /// Validates amount
  static String? validateAmount(String? value, {double minAmount = 0}) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }

    final amount = double.tryParse(value);

    if (amount == null) {
      return 'Enter a valid amount';
    }

    if (amount <= minAmount) {
      return 'Amount must be greater than $minAmount';
    }

    return null;
  }

  /// Validates username
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }

    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }

    if (value.length > 20) {
      return 'Username must not exceed 20 characters';
    }

    // Only alphanumeric and underscores
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }

    return null;
  }

  /// Validates engine number
  static String? validateEngineNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Engine number is required';
    }
    if (value.trim().length < 5) {
      return 'Engine number must be at least 5 characters';
    }
    return null;
  }

  /// Validates URL format
  static String? validateUrl(String? value, {bool required = false}) {
    if (value == null || value.isEmpty) {
      return required ? 'URL is required' : null;
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value)) {
      return 'Enter a valid URL';
    }

    return null;
  }

  /// Validates date range
  static String? validateDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) {
      return 'Both dates are required';
    }

    if (endDate.isBefore(startDate)) {
      return 'End date must be after start date';
    }

    return null;
  }

  /// Validates minimum length
  static String? validateMinLength(
    String? value, {
    required int minLength,
    String fieldName = 'This field',
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    return null;
  }

  /// Validates maximum length
  static String? validateMaxLength(
    String? value, {
    required int maxLength,
    String fieldName = 'This field',
  }) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty if not required
    }

    if (value.length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }

    return null;
  }

  /// Composite validator - combines multiple validators
  static String? Function(String?) compose(
    List<String? Function(String?)> validators,
  ) {
    return (String? value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) {
          return error;
        }
      }
      return null;
    };
  }
}