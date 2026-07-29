// lib/services/ocr_service.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OcrService {
  static Future<String?> recognizeVehicleNumber(Uint8List imageBytes) async {
    final url = Uri.parse('https://api.ocr.space/parse/image');

    final request = http.MultipartRequest('POST', url);
    request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'image.jpg'));
    request.fields['apikey'] = 'helloworld'; // Replace with your own key later
    request.fields['language'] = 'eng';
    request.fields['ocrengine'] = '2';

    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = jsonDecode(respStr);

      if (data['IsErroredOnProcessing'] == false) {
        final text = data['ParsedResults'][0]['ParsedText'];
        return _extractVehicleNumber(text);
      } else {
        debugPrint('OCR Error: ${data['ErrorMessage']}');
        return null;
      }
    } catch (e) {
      debugPrint('OCR API Error: $e');
      return null;
    }
  }

  static String? _extractVehicleNumber(String text) {
    if (text.isEmpty) return null;

    // Clean text
    final cleaned = text.toUpperCase().replaceAll(
        RegExp(r'[\s\n\r\t.,!@#$%^&*()_+\-=\[\]{};:"\\|,.<>\/?~`]+'), '');

    // Define patterns
    final patterns = [
      RegExp(r'\d{2}BH\d{4}[A-Z]{2}'), // BH Series: 21BH2345AA
      RegExp(r'[A-Z]{2}\d{1,2}[A-Z]{0,2}\d{4}'), // Standard: KL07AB1234 or KL071234
      RegExp(r'[A-Z]{2}\d{2}[A-Z]{0,2}\d{1,4}'), // Generic catch-all (includes KL78111)
    ];

    // Try each pattern
    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null && match.group(0) != null) {
        return match.group(0);
      }
    }

    return null;
  }
}
