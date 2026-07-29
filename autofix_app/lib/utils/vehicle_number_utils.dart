class VehicleNumberUtils {
  /// Normalizes a vehicle number by:
  /// 1. Converting to uppercase
  /// 2. Removing spaces and special characters
  /// 3. Padding district code with leading zero if needed (e.g., KL7 -> KL07)
  /// 
  /// Examples:
  /// - "kl7as5656" -> "KL07AS5656"
  /// - "KL 7 AS 5656" -> "KL07AS5656"
  /// - "KL-07-AS-5656" -> "KL07AS5656"
  static String normalize(String vehicleNumber) {
    if (vehicleNumber.isEmpty) return vehicleNumber;
    
    // Remove spaces, hyphens, and convert to uppercase
    String cleaned = vehicleNumber
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-]'), '');
    
    // Pattern: StateCode(2 letters) + DistrictCode(1-2 digits) + Series(1-2 letters) + Number(4 digits)
    // Example: KL07AS5656 or KL7AS5656
    final RegExp pattern = RegExp(r'^([A-Z]{2})(\d{1,2})([A-Z]{1,2})(\d{1,4})$');
    final match = pattern.firstMatch(cleaned);
    
    if (match != null) {
      final stateCode = match.group(1)!;
      final districtCode = match.group(2)!;
      final series = match.group(3)!;
      final number = match.group(4)!;
      
      // Pad district code to 2 digits if needed
      final paddedDistrict = districtCode.padLeft(2, '0');
      
      // Pad number to 4 digits if needed
      final paddedNumber = number.padLeft(4, '0');
      
      return '$stateCode$paddedDistrict$series$paddedNumber';
    }
    
    // If pattern doesn't match, return cleaned version as-is
    return cleaned;
  }
  
  /// Compares two vehicle numbers after normalizing them
  static bool areEqual(String vehicleNumber1, String vehicleNumber2) {
    return normalize(vehicleNumber1) == normalize(vehicleNumber2);
  }
  
  /// Formats a vehicle number for display with spaces
  /// Example: "KL07AS5656" -> "KL 07 AS 5656"
  static String formatForDisplay(String vehicleNumber) {
    final normalized = normalize(vehicleNumber);
    
    final RegExp pattern = RegExp(r'^([A-Z]{2})(\d{2})([A-Z]{1,2})(\d{4})$');
    final match = pattern.firstMatch(normalized);
    
    if (match != null) {
      return '${match.group(1)} ${match.group(2)} ${match.group(3)} ${match.group(4)}';
    }
    
    return normalized;
  }

  /// Generates possible variants for searching, including forms without padded zeros.
  static List<String> generateSearchCandidates(String vehicleNumber) {
    final normalized = normalize(vehicleNumber);
    final candidates = <String>{normalized};

    final RegExp pattern = RegExp(r'^([A-Z]{2})(\d{2})([A-Z]{1,2})(\d{4})$');
    final match = pattern.firstMatch(normalized);

    if (match != null) {
      final state = match.group(1)!;
      final district = match.group(2)!;
      final series = match.group(3)!;
      final number = match.group(4)!;

      // Include variation without leading zero in the district code if applicable
      final trimmedDistrict = district.replaceFirst(RegExp(r'^0'), '');
      if (trimmedDistrict != district) {
        candidates.add('$state$trimmedDistrict$series$number');
      }
    }

    return candidates.toList(growable: false);
  }
}
