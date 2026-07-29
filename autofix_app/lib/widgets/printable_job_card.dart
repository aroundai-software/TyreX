// lib/widgets/printable_job_card.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a professional, invoice-style PDF for a given job card.
Future<Uint8List> generateJobCardPdf(Map<String, dynamic> reportData) async {
  final pdf = pw.Document();

  // ✅ Load fonts with error handling
  pw.Font? ttfBold;
  pw.Font? ttfRegular;
  try {
    final font = await rootBundle.load("assets/fonts/Manrope/static/Manrope-Bold.ttf");
    final regularFont = await rootBundle.load("assets/fonts/Manrope/static/Manrope-Regular.ttf");
    ttfBold = pw.Font.ttf(font);
    ttfRegular = pw.Font.ttf(regularFont);
  } catch (e) {
    debugPrint('⚠️ Custom fonts not found, using default: $e');
  }

  // ✅ Load logo with error handling
  pw.MemoryImage? logoImage;
  try {
    final logoBytes = await rootBundle.load('assets/images/logo.png');
    logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (e) {
    debugPrint('⚠️ Logo not found: $e');
  }

  // ✅ Load car outline with error handling
  pw.MemoryImage? carOutlineImage;
  try {
    final carBytes = await rootBundle.load('assets/images/car_outline.png');
    carOutlineImage = pw.MemoryImage(carBytes.buffer.asUint8List());
  } catch (e) {
    debugPrint('⚠️ Car outline not found: $e');
  }

  // Safely extract all data
  final vehicle = reportData['vehicles'];
  final model = vehicle?['vehicle_models'];
  final executive = reportData['executive']?['username'] ?? 'N/A';
  final inspector = reportData['inspector']?['username'] ?? 'N/A';

  // ✅ Helper function to safely parse JSON arrays from the report
  List<String> parseJsonList(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty || jsonString == '[]') return [];
    try {
      final list = jsonDecode(jsonString) as List;
      if (list.isEmpty) return [];
      return list.map((item) => (item is Map ? item['text'] : item).toString()).toList();
    } catch (e) {
      return ['Data error'];
    }
  }

  final complaints = parseJsonList(reportData['complaint']);
  final suggested = parseJsonList(reportData['suggested']);
  final approved = parseJsonList(reportData['approved']);

  // ✅ Parse marks with error handling
  List<PdfPoint> marks = [];
  try {
    final marksData = reportData['marks'];
    if (marksData != null && marksData != '[]') {
      marks = (jsonDecode(marksData) as List)
          .map((m) => PdfPoint((m['x'] as num).toDouble(), (m['y'] as num).toDouble()))
          .toList();
    }
  } catch (e) {
    debugPrint('⚠️ Error parsing marks: $e');
  }

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // === 1. HEADER ===
            _buildHeader(logoImage, ttfBold, reportData),
            pw.SizedBox(height: 20),

            // === 2. CUSTOMER & VEHICLE DETAILS ===
            _buildCustomerAndVehicleDetails(reportData, vehicle, model, ttfBold, ttfRegular),
            pw.SizedBox(height: 20),

            // === 3. JOB DETAILS TABLE ===
            _buildJobDetailsTable(complaints, suggested, approved, ttfBold, ttfRegular),
            pw.SizedBox(height: 20),

            // === 4. DAMAGE MARKS VISUAL ===
            if (marks.isNotEmpty && carOutlineImage != null)
              _buildDamageMarksSection(carOutlineImage, marks, ttfBold),

            // === 5. FOOTER & SIGNATURES ===
            pw.Spacer(),
            _buildFooter(executive, inspector, ttfRegular),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

// === HELPER WIDGETS FOR PDF STRUCTURE ===

pw.Widget _buildHeader(pw.MemoryImage? logo, pw.Font? font, Map<String, dynamic> report) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'AutoFix Service Center',
            style: font != null
                ? pw.TextStyle(font: font, fontSize: 18)
                : pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('123 Auto Lane, Kochi, Kerala'),
          pw.Text('contact@autofix.com'),
        ],
      ),
      // ✅ Show logo or placeholder
      pw.SizedBox(
        height: 60,
        width: 60,
        child: logo != null
            ? pw.Image(logo)
            : pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColors.blue,
            borderRadius: pw.BorderRadius.circular(30),
          ),
          child: pw.Center(
            child: pw.Text(
              'AF',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

pw.Widget _buildCustomerAndVehicleDetails(
    Map<String, dynamic> report,
    Map<String, dynamic>? vehicle,
    Map<String, dynamic>? model,
    pw.Font? font,
    pw.Font? regularFont) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Customer Column
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Customer Information',
                style: font != null
                    ? pw.TextStyle(font: font, fontSize: 12)
                    : pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(height: 8),
              _buildDetailRow('Client:', report['client_phone'] ?? 'N/A', regularFont),
              _buildDetailRow('Phone:', report['client_phone'] ?? 'N/A', regularFont),
              _buildDetailRow(
                'Report Date:',
                DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(report['created_at'])),
                regularFont,
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        // Vehicle Column
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Vehicle Information',
                style: font != null
                    ? pw.TextStyle(font: font, fontSize: 12)
                    : pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(height: 8),
              _buildDetailRow('Vehicle No:', vehicle?['Vehicle Number'] ?? 'N/A', regularFont),
              _buildDetailRow(
                'Brand/Model:',
                '${model?['brand'] ?? ''} ${model?['Model name'] ?? ''}'.trim(),
                regularFont,
              ),
              _buildDetailRow('Engine No:', vehicle?['Engine Number'] ?? 'N/A', regularFont),
              _buildDetailRow('Chassis No:', vehicle?['Chasis Number'] ?? 'N/A', regularFont),
              _buildDetailRow('Odometer:', '${report['odometer_reading'] ?? 'N/A'} km', regularFont),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildJobDetailsTable(
    List<String> complaints,
    List<String> suggested,
    List<String> approved,
    pw.Font? font,
    pw.Font? regularFont) {
  // Determine the maximum number of rows needed
  final int rowCount = [complaints.length, suggested.length, approved.length]
      .reduce((a, b) => a > b ? a : b);

  return pw.TableHelper.fromTextArray(
    headers: ['Customer Complaints', 'Technician\'s Suggestions', 'Approved Work'],
    headerStyle: font != null
        ? pw.TextStyle(font: font, fontSize: 10)
        : pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
    cellStyle: regularFont != null
        ? pw.TextStyle(font: regularFont, fontSize: 9)
        : const pw.TextStyle(fontSize: 9),
    cellAlignments: {
      0: pw.Alignment.centerLeft,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.centerLeft,
    },
    border: pw.TableBorder.all(),
    data: List<List<String>>.generate(
      rowCount,
          (row) => [
        row < complaints.length ? '• ${complaints[row]}' : '',
        row < suggested.length ? '• ${suggested[row]}' : '',
        row < approved.length ? '• ${approved[row]}' : '',
      ],
    ),
  );
}

// ✅ This widget draws the damage marks on top of the car outline image
pw.Widget _buildDamageMarksSection(pw.MemoryImage carImage, List<PdfPoint> marks, pw.Font? font) {
  const imageAspectRatio = 0.8466; // The ratio you calculated earlier
  const imageWidth = 250.0;
  const imageHeight = imageWidth / imageAspectRatio;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Damage Marks',
        style: font != null
            ? pw.TextStyle(font: font, fontSize: 12)
            : pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
      pw.Container(
        width: imageWidth,
        height: imageHeight,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
        child: pw.Stack(
          alignment: pw.Alignment.center,
          children: [
            pw.Image(carImage),
            // Iterate through marks and place a red dot for each one
            ...marks.map(
                  (mark) => pw.Positioned(
                left: mark.x * imageWidth - 2, // Adjust for dot size
                top: mark.y * imageHeight - 2,
                child: pw.Container(
                  width: 4,
                  height: 4,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.red,
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _buildFooter(String executive, String inspector, pw.Font? regularFont) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.SizedBox(
        width: 200,
        child: pw.Column(
          children: [
            pw.Divider(),
            pw.Text(
              'Executive: $executive',
              style: regularFont != null
                  ? pw.TextStyle(font: regularFont, fontSize: 10)
                  : const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
      pw.SizedBox(
        width: 200,
        child: pw.Column(
          children: [
            pw.Divider(),
            pw.Text(
              'Customer Signature',
              style: regularFont != null
                  ? pw.TextStyle(font: regularFont, fontSize: 10)
                  : const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _buildDetailRow(String label, String value, pw.Font? font) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 75,
          child: pw.Text(
            label,
            style: font != null
                ? pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)
                : pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: font != null ? pw.TextStyle(font: font) : const pw.TextStyle(),
          ),
        ),
      ],
    ),
  );
}