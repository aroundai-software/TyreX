import 'package:flutter/material.dart';

class AppDateUtils {
  /// Parses a date string from Supabase into local IST time.
  /// Handles explicit UTC strings (with Z/+00:00), local IST strings,
  /// and legacy UTC strings that lack trailing timezone indicators.
  static DateTime parseUtcToLocal(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return DateTime.now();
    try {
      final cleanStr = dateStr.trim();
      
      // If it already has an explicit timezone indicator (Z or +hh:mm or -hh:mm), parse naturally
      if (cleanStr.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(cleanStr)) {
        return DateTime.parse(cleanStr).toLocal();
      }
      
      // If it lacks a timezone indicator, compare parsing it as Local vs parsing it as UTC
      final dtAsLocal = DateTime.parse(cleanStr);
      
      try {
        final dtAsUtc = DateTime.parse('${cleanStr}Z').toLocal();
        final now = DateTime.now();
        
        // If treating it as UTC brings the timestamp into valid non-future time (<= now + 10m) 
        // AND it is closer to now than dtAsLocal (which would be 5.5 hours in the past), 
        // then it was a UTC timestamp missing 'Z'.
        if (dtAsUtc.isBefore(now.add(const Duration(minutes: 10))) &&
            now.difference(dtAsUtc).abs() < now.difference(dtAsLocal).abs()) {
          return dtAsUtc;
        }
      } catch (_) {}
      
      return dtAsLocal;
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return DateTime.now();
    }
  }
}



