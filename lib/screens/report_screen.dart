// lib/screens/report_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/user_provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:printing/printing.dart';
import '../widgets/printable_job_card.dart';
import '../theme/app_theme.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import '../providers/report_provider.dart';
import '../providers/admin_settings_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/local_media_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

// Assuming DamagePainter is in a shared file or defined elsewhere.
// If not, you can copy the DamagePainter class from job_card_screen.dart to here.
class DamagePainter extends CustomPainter {
  final List<Offset> marks;
  DamagePainter({required this.marks});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // SCALE RELATIVE COORDINATES TO THE CANVAS SIZE
    for (final mark in marks) {
      final x = mark.dx * size.width;
      final y = mark.dy * size.height;
      canvas.drawCircle(Offset(x, y), 5.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DamagePainter oldDelegate) =>
      oldDelegate.marks != marks;
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _filteredReports = [];

  final _vehicleNoController = TextEditingController();
  final _brandController = TextEditingController();
  final _fromDateController = TextEditingController();
  final _toDateController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Audio player for voice notes
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  String? _currentlyPlayingAudioId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReportsForCurrentUser();
    });
    
    // ✅ Load admin settings to ensure feature flags are available
    Provider.of<AdminSettingsProvider>(context, listen: false).loadSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Fetch fresh data every time the screen becomes active
    // This ensures data is refreshed when switching between executives
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReportsForCurrentUser();
    });
  }

  /// Fetch reports for the currently logged-in user
  void _fetchReportsForCurrentUser() {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      final userId = user['id'] as int;
      debugPrint('🔄 ReportScreen: Fetching fresh reports for userId: $userId');
      
      // ✅ Use refresh() instead of fetchReports() to bypass cache
      Provider.of<ReportProvider>(context, listen: false).refresh(userId);
    }
  }

  @override
  void dispose() {
    _vehicleNoController.dispose();
    _brandController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _applyFilters() {
    // Get the full list from the provider
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    List<Map<String, dynamic>> filtered = List.from(reportProvider.reports);
    if (_vehicleNoController.text.isNotEmpty) {
      final searchTerm = _vehicleNoController.text.toUpperCase();
      filtered = filtered
          .where((report) =>
              report['vehicles']?['Vehicle Number']
                  ?.toString()
                  .toUpperCase()
                  .contains(searchTerm) ??
              false)
          .toList();
    }
    if (_brandController.text.isNotEmpty) {
      final searchTerm = _brandController.text.toLowerCase();
      filtered = filtered
          .where((report) =>
              report['vehicles']?['vehicle_models']?['brand']
                  ?.toString()
                  .toLowerCase()
                  .contains(searchTerm) ??
              false)
          .toList();
    }
    if (_fromDate != null) {
      filtered = filtered
          .where((report) =>
              !DateTime.parse(report['created_at']).isBefore(_fromDate!))
          .toList();
    }
    if (_toDate != null) {
      final endOfDay =
          DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
      filtered = filtered
          .where((report) =>
              !DateTime.parse(report['created_at']).isAfter(endOfDay))
          .toList();
    }
    setState(() => _filteredReports = filtered);
  }

  void _clearFilters() {
    setState(() {
      _vehicleNoController.clear();
      _brandController.clear();
      _fromDateController.clear();
      _toDateController.clear();
      _fromDate = null;
      _toDate = null;
      // Get the full list from the provider
      final reportProvider =
          Provider.of<ReportProvider>(context, listen: false);
      _filteredReports = reportProvider.reports;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? (_fromDate ?? DateTime.now())
          : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          _fromDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        } else {
          _toDate = picked;
          _toDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        }
      });
      _applyFilters();
    }
  }

  String _formatJsonCell(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty || jsonString == '[]') {
      return 'N/A';
    }
    try {
      final list = jsonDecode(jsonString) as List;
      if (list.isEmpty) return 'N/A';
      return list
          .map((item) => (item is Map ? item['text'] : item).toString())
          .join(', ');
    } catch (e) {
      return 'Invalid Data';
    }
  }

  Future<void> _downloadReport() async {
    if (_filteredReports.isEmpty) {
      _showErrorSnackBar('No reports to download.');
      return;
    }

    // 1. Define the CSV headers
    final List<String> headers = [
      'Date & Time',
      'Vehicle No',
      'Vehicle Name',
      'Brand',
      'Model',
      'Client Name',
      'Client Phone',
      'Odometer',
      'Status',
      'Complaints',
      'Executive'
    ];

    // 2. Create the list of rows, starting with the headers
    List<List<dynamic>> rows = [];
    rows.add(headers);

    // 3. Add data for each report
    for (final report in _filteredReports) {
      final vehicle = report['vehicles'];
      final model = vehicle?['vehicle_models'];
      rows.add([
        DateFormat('dd-MM-yyyy HH:mm')
            .format(DateTime.parse(report['created_at'])),
        vehicle?['Vehicle Number'] ?? 'N/A',
        vehicle?['vehicle_name'] ?? 'N/A',
        model?['brand'] ?? 'N/A',
        model?['Model name'] ?? 'N/A',
        report['Owner name'] ?? 'N/A',
        report['client_phone'] ?? 'N/A',
        report['odometer_reading']?.toString() ?? 'N/A',
        report['status'] ?? 'N/A',
        _formatJsonCell(
            report['complaint']), // Use your existing formatting function
        report['executive']?['username'] ?? 'N/A',
      ]);
    }

    // 4. Convert the list of lists into a CSV string
    final String csv = const ListToCsvConverter().convert(rows);

    // 5. Trigger the download for web
    final blob = html.Blob([csv]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download",
          "autofix_reports_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);

    _showSuccessSnackBar('Report downloaded successfully!');
  }

  Future<void> _openLocalMediaViewer(int jobId) async {
    final items = LocalMediaService().listByJob(jobId);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Local Media'),
          content: SizedBox(
            width: 600,
            height: 420,
            child: items.isEmpty
                ? const Center(child: Text('No local media for this job.'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isPhoto = item['type'] == 'photo';
                      final audioId = item['id'] as String;
                      final Uint8List bytes = item['bytes'] as Uint8List;
                      final isCurrentlyPlaying = _currentlyPlayingAudioId == audioId && _isPlayingAudio;
                      
                      return ListTile(
                        leading: isPhoto
                            ? Image.memory(bytes, width: 48, height: 48, fit: BoxFit.cover)
                            : Icon(
                                isCurrentlyPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: Colors.blueGrey,
                                size: 48,
                              ),
                        title: Text(item['fileName'] ?? audioId),
                        subtitle: Text('${item['mime'] ?? ''} • ${(bytes.length / 1024).toStringAsFixed(1)} KB'),
                        onTap: isPhoto 
                            ? () => _previewImage(bytes, item['fileName'] ?? 'image.jpg') 
                            : () => _playAudio(bytes, audioId),
                        trailing: Consumer<AdminSettingsProvider>(
                          builder: (context, adminSettings, _) {
                            if (!adminSettings.featureJobCardDownload) {
                              return const SizedBox.shrink();
                            }
                            return TextButton.icon(
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Download'),
                              onPressed: () => _saveOrShareBytes(bytes, item['fileName'] ?? 'media', mime: item['mime'] as String?),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            Consumer<AdminSettingsProvider>(
              builder: (context, adminSettings, _) {
                if (!adminSettings.featureJobCardDownload) {
                  return const SizedBox.shrink();
                }
                return TextButton(
                  onPressed: () => _exportZipForJob(jobId),
                  child: const Text('Export ZIP'),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveOrShareBytes(Uint8List bytes, String filename, {String? mime}) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes], mime);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getTemporaryDirectory();
      final file = io.File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path, name: filename, mimeType: mime)]);
    }
  }

  Future<void> _exportZipForJob(int jobId) async {
    final zipBytes = LocalMediaService().exportZipForJob(jobId);
    final filename = 'job_${jobId}_media.zip';
    if (kIsWeb) {
      final blob = html.Blob([zipBytes], 'application/zip');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getTemporaryDirectory();
      final file = io.File('${dir.path}/$filename');
      await file.writeAsBytes(zipBytes, flush: true);
      await Share.shareXFiles([XFile(file.path, name: filename, mimeType: 'application/zip')]);
    }
  }

  Future<void> _previewImage(Uint8List bytes, String name) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _playAudio(Uint8List bytes, String audioId) async {
    try {
      // Stop any currently playing audio
      if (_isPlayingAudio && _currentlyPlayingAudioId != audioId) {
        await _audioPlayer.stop();
      }

      if (_isPlayingAudio && _currentlyPlayingAudioId == audioId) {
        // Pause if this is the currently playing audio
        await _audioPlayer.pause();
        setState(() {
          _isPlayingAudio = false;
          _currentlyPlayingAudioId = null;
        });
      } else {
        // Play the audio
        if (kIsWeb) {
          // For web, create a blob URL
          final blob = html.Blob([bytes], 'audio/webm');
          final url = html.Url.createObjectUrlFromBlob(blob);
          await _audioPlayer.setSourceUrl(url);
          await _audioPlayer.resume();
        } else {
          // For mobile/desktop, save to temp file and play
          final tempDir = await getTemporaryDirectory();
          final tempFile = io.File('${tempDir.path}/temp_audio_$audioId.webm');
          await tempFile.writeAsBytes(bytes);
          await _audioPlayer.play(DeviceFileSource(tempFile.path));
        }

        setState(() {
          _isPlayingAudio = true;
          _currentlyPlayingAudioId = audioId;
        });

        // Listen for audio completion
        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() {
            _isPlayingAudio = false;
            _currentlyPlayingAudioId = null;
          });
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to play audio: $e');
      setState(() {
        _isPlayingAudio = false;
        _currentlyPlayingAudioId = null;
      });
    }
  }

  Future<void> _printJobCard(Map<String, dynamic> reportData) async {
    try {
      // 1. Generate the PDF bytes using your existing function
      final pdfBytes = await generateJobCardPdf(reportData);

      // 2. Open the native print preview screen
      await Printing.layoutPdf(onLayout: (format) => pdfBytes);
    } catch (e) {
      _showErrorSnackBar('Could not generate PDF: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 100),
        ));
  }

  void _showSuccessSnackBar(String message) {
    // Commented out to reduce UI noise
    // if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Ongoing':
        return Colors.orange;
      case 'Not Started':
        return Colors.red;
      default:
        return Colors.grey.shade600;
    }
  }

  void _showMarksDialog(String? marksJson) {
    if (marksJson == null || marksJson.isEmpty || marksJson == '[]') {
      _showErrorSnackBar('No damage marks recorded.');
      return;
    }
    List<Offset> marks = [];
    try {
      final decoded = jsonDecode(marksJson) as List;
      marks = decoded
          .map((m) =>
              Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble()))
          .toList();
    } catch (e) {
      _showErrorSnackBar('Could not display damage marks.');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: AspectRatio(
          // ❗ IMPORTANT: Use the exact same value here
          aspectRatio: 0.8466666666666667,
          child: CustomPaint(
            // --- FIX START ---
            // Replaced non-existent `DamagePainterFromJson` and `marksData`
            // with the correct painter and the `marks` variable.
            foregroundPainter: DamagePainter(marks: marks),
            // --- FIX END ---
            child: Image.asset(
              'assets/images/car_outline.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  void _showWarrantyDialog(String? barcodeJson) {
    if (barcodeJson == null || barcodeJson.isEmpty || barcodeJson == '{}') {
      _showErrorSnackBar('No warranty QR codes recorded.');
      return;
    }
    Map<String, dynamic> barcodeData = {};
    try {
      barcodeData = jsonDecode(barcodeJson) as Map<String, dynamic>;
    } catch (e) {
      _showErrorSnackBar('Could not parse warranty data.');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warranty QRs'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: barcodeData.length,
            itemBuilder: (context, index) {
              String position = barcodeData.keys.elementAt(index);
              Map<String, dynamic> details = barcodeData[position] as Map<String, dynamic>;
              String qr = details['qr'] ?? '';
              String spec = details['spec'] ?? '';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      position,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (spec.isNotEmpty)
                      Text('Spec: $spec', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    if (qr.isNotEmpty)
                      Center(
                        child: QrImageView(
                          data: qr,
                          version: QrVersions.auto,
                          size: 150.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> _shareWarrantyPDF(Map<String, dynamic> report) async {
    final barcodeJson = report['barcode'] as String?;
    if (barcodeJson == null || barcodeJson.isEmpty || barcodeJson == '{}') {
      _showErrorSnackBar('No warranty QR codes recorded.');
      return;
    }

    Map<String, dynamic> barcodeData = {};
    try {
      barcodeData = jsonDecode(barcodeJson) as Map<String, dynamic>;
    } catch (e) {
      _showErrorSnackBar('Could not parse warranty data.');
      return;
    }

    final String jobIdStr = (report['job_card_id']?.toString().isNotEmpty == true) 
        ? report['job_card_id'].toString() 
        : report['id']?.toString() ?? 'N/A';
    final vehicle = report['vehicles'];
    final vehicleNo = vehicle?['Vehicle Number'] ?? 'N/A';
    final clientName = report['Owner name'] ?? 'N/A';
    final clientPhone = report['client_phone'] ?? 'N/A';

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Tyre Warranty Details', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Job Card: $jobIdStr', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Vehicle: $vehicleNo', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Client: $clientName ($clientPhone)', style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 20),
              pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                children: barcodeData.entries.map((entry) {
                  final position = entry.key;
                  final details = entry.value as Map<String, dynamic>;
                  final qr = details['qr']?.toString() ?? '';
                  final spec = details['spec']?.toString() ?? '';

                  return pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(position, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        if (spec.isNotEmpty) pw.Text('Spec: $spec', style: const pw.TextStyle(fontSize: 12)),
                        pw.SizedBox(height: 10),
                        if (qr.isNotEmpty)
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: qr,
                            width: 120,
                            height: 120,
                          ),
                        if (qr.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 8),
                            child: pw.Text(qr, style: const pw.TextStyle(fontSize: 8)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = io.File('${dir.path}/job_${jobIdStr}_warranty_qrs.pdf');
      await file.writeAsBytes(bytes);

      final String message = 'Warranty details for Job $jobIdStr (Vehicle: $vehicleNo)';
      await Share.shareXFiles(
        [XFile(file.path)],
        text: message,
        subject: 'Warranty details for Job $jobIdStr',
      );
    } catch (e) {
      _showErrorSnackBar('Error generating or sharing PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, reportProvider, child) {
        // ✅ FIX: Update filtered list when provider data changes
        if (_filteredReports.isEmpty && reportProvider.reports.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _filteredReports = reportProvider.reports;
              });
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text(
              'Reports',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 24,
                color: AppTheme.primaryColor,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
                onPressed: () async {
                  final user =
                      Provider.of<UserProvider>(context, listen: false).user;
                  if (user != null) {
                    await reportProvider.refresh(user['id'] as int);
                    if (mounted) _applyFilters();
                  }
                },
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: Column(
            // Keep the Column layout
            children: [
              // ✅ REMOVE the custom blue title Container that was here
              // Content (Expanded RefreshIndicator with ListView)
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    final user =
                        Provider.of<UserProvider>(context, listen: false).user;
                    if (user != null) {
                      await reportProvider.refresh(user['id'] as int);
                      if (mounted) _applyFilters();
                    }
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
                        sliver: SliverToBoxAdapter(
                          child: _buildFilterCard(), // Filters remain at the top
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0).copyWith(bottom: 16),
                        sliver: SliverFillRemaining(
                          hasScrollBody: true,
                          child: _buildServiceHistoryCard(
                            isLoading: reportProvider.isLoading &&
                                reportProvider.reports.isEmpty,
                            filteredReports: _filteredReports,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _fromDateController,
                    decoration: const InputDecoration(
                        labelText: 'From Date',
                        suffixIcon: Icon(Icons.calendar_today, size: 20)),
                    readOnly: true,
                    onTap: () => _selectDate(context, true))),
            const SizedBox(width: 16),
            Expanded(
                child: TextField(
                    controller: _toDateController,
                    decoration: const InputDecoration(
                        labelText: 'To Date',
                        suffixIcon: Icon(Icons.calendar_today, size: 20)),
                    readOnly: true,
                    onTap: () => _selectDate(context, false))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _vehicleNoController,
                    decoration:
                        const InputDecoration(labelText: 'Vehicle Number'),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => _applyFilters())),
            const SizedBox(width: 16),
            Expanded(
                child: TextField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'Brand'),
                    onChanged: (_) => _applyFilters())),
          ]),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear Filters'))),
        ],
      ),
    );
  }

  Widget _buildServiceHistoryCard({
    required bool isLoading,
    required List<Map<String, dynamic>> filteredReports,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Service History',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Consumer<AdminSettingsProvider>(
                  builder: (context, adminSettings, _) {
                    if (!adminSettings.featureJobCardDownload) {
                      return const SizedBox.shrink();
                    }
                    return ElevatedButton.icon(
                        onPressed: _downloadReport,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text(
                          'Download',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    );
                  },
                ),
              ],
            ),
          ),
          if (isLoading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator()))
          else if (filteredReports.isEmpty)
            const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                    child: Text('No reports found.',
                        style: TextStyle(color: AppTheme.textSecondary))))
          else
            Consumer<AdminSettingsProvider>(
              builder: (context, adminSettings, _) {
                // Build columns dynamically based on settings
                List<DataColumn2> columns = [];
                
                // Add PRINT column only if feature is enabled
                if (adminSettings.featureJobCardDownload) {
                  columns.add(const DataColumn2(label: Text('PRINT'), size: ColumnSize.S));
                }
                
                // Add all other columns
                columns.addAll(const [
                  DataColumn2(label: Text('Job ID'), size: ColumnSize.M),
                  DataColumn2(label: Text('Vehicle No.'), size: ColumnSize.M),
                  DataColumn2(label: Text('Vehicle Name'), size: ColumnSize.M),
                  DataColumn2(label: Text('Model'), size: ColumnSize.M),
                  DataColumn2(label: Text('Brand'), size: ColumnSize.M),
                  DataColumn2(label: Text('Color'), size: ColumnSize.S),
                  DataColumn2(label: Text('Engine No'), size: ColumnSize.L),
                  DataColumn2(label: Text('Chassis No'), size: ColumnSize.L),
                  DataColumn2(label: Text('Client Name'), size: ColumnSize.M),
                  DataColumn2(label: Text('Client Phone'), size: ColumnSize.M),
                  DataColumn2(label: Text('Odometer'), size: ColumnSize.S),
                  DataColumn2(label: Text('Executive'), size: ColumnSize.M),
                  DataColumn2(label: Text('Date & Time'), size: ColumnSize.L), // Give more space to prevent wrapping
                  DataColumn2(label: Text('Status'), size: ColumnSize.M), // "Work in Progress" needs more space
                  DataColumn2(label: Text('Duration'), size: ColumnSize.M),
                  DataColumn2(label: Text('Complaint'), size: ColumnSize.L),
                  DataColumn2(label: Text('Suggested'), size: ColumnSize.L),
                  DataColumn2(label: Text('Approved'), size: ColumnSize.L),
                  DataColumn2(label: Text('Feedback Text'), size: ColumnSize.L),
                  DataColumn2(label: Text('Feedback Voice'), size: ColumnSize.S),
                  DataColumn2(label: Text('Marks'), size: ColumnSize.S),
                  DataColumn2(label: Text('Warranty'), size: ColumnSize.S),
                  DataColumn2(label: Text('Media'), size: ColumnSize.S),
                ]);
                
                List<String> columnNames = columns.map((c) => (c.label as Text).data!).toList();
                
                final rows = List<DataRow>.generate(_filteredReports.length, (index) {
                  final report = _filteredReports[index];
                  final vehicle = report['vehicles'];
                  final model = vehicle?['vehicle_models'];

                  // Parse the date robustly and convert to local time (IST)
                  String rawDate = report['created_at'].toString();
                  // If Supabase returns UTC without timezone info, append 'Z' so Flutter knows it's UTC
                  if (!rawDate.endsWith('Z') && !rawDate.contains('+') && !rawDate.contains('T')) {
                    rawDate = '${rawDate.replaceAll(' ', 'T')}Z';
                  } else if (!rawDate.endsWith('Z') && !rawDate.contains('+')) {
                    rawDate = '${rawDate}Z';
                  }
                  
                  final parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
                  final localDate = parsedDate.toLocal();

                  // Build cells dynamically based on settings
                  List<DataCell> cells = [];
                  
                  // Add PRINT cell only if feature is enabled
                  if (adminSettings.featureJobCardDownload) {
                    cells.add(
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.download, color: AppTheme.textSecondary),
                          onPressed: () => _printJobCard(report),
                        ),
                      ),
                    );
                  }
                  
                  // Add all other cells
                  cells.addAll([
                    DataCell(Text(report['job_card_id']?.toString() ?? 'Job #${report['id']}')),
                    DataCell(Text(vehicle?['Vehicle Number'] ?? 'N/A')),
                    DataCell(Text(vehicle?['vehicle_name'] ?? 'N/A')),
                    DataCell(Text(model?['Model name'] ?? 'N/A')),
                    DataCell(Text(model?['brand'] ?? 'N/A')),
                    DataCell(Text(vehicle?['Color'] ?? 'N/A')),
                    DataCell(Text(vehicle?['Engine Number'] ?? 'N/A')),
                    DataCell(Text(vehicle?['Chasis Number'] ?? 'N/A')),
                    DataCell(Text(report['Owner name'] ?? 'N/A')),
                    DataCell(Text(report['client_phone'] ?? 'N/A')),
                    DataCell(Text(report['odometer_reading']?.toString() ?? 'N/A')),
                    DataCell(Text(report['executive']?['username'] ?? 'N/A')),
                    DataCell(Text(DateFormat('dd/MM/yy, HH:mm').format(localDate))),
                    DataCell(Chip(
                        label: Text(report['status'] ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 11)),
                        backgroundColor: _getStatusColor(report['status']),
                        padding: const EdgeInsets.symmetric(horizontal: 4))),
                    DataCell(Text(_formatDuration(report['started_at'], report['completed_at']))),
                    DataCell(Text(_formatJsonCell(report['complaint']), overflow: TextOverflow.ellipsis)),
                    DataCell(Text(_formatJsonCell(report['suggested']), overflow: TextOverflow.ellipsis)),
                    DataCell(Text(_formatJsonCell(report['approved']), overflow: TextOverflow.ellipsis)),
                    DataCell(Text(report['customer_feedback_text'] ?? 'N/A')),
                    DataCell(report['customer_feedback_audio'] != null
                        ? IconButton(
                            icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                            onPressed: () async => await launchUrl(Uri.parse(report['customer_feedback_audio'])))
                        : const Text('N/A')),
                    DataCell(
                        (report['marks'] as String?)?.isNotEmpty == true && report['marks'] != '[]'
                            ? TextButton(
                                onPressed: () => _showMarksDialog(report['marks']),
                                child: const Text('View'))
                            : const Text('N/A')),
                    DataCell(
                        (report['barcode'] as String?)?.isNotEmpty == true && report['barcode'] != '{}'
                            ? TextButton(
                                onPressed: () => _showWarrantyDialog(report['barcode']),
                                child: const Text('View QRs'))
                            : const Text('N/A')),
                    DataCell(
                      TextButton(
                        onPressed: () => _openLocalMediaViewer(report['id'] as int),
                        child: const Text('View Local'),
                      ),
                    ),
                  ]);

                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (index.isEven) return Colors.grey.withValues(alpha: 0.05);
                      return null; // Use default for odd rows
                    }),
                    cells: cells,
                  );
                });

                bool isMobile = MediaQuery.of(context).size.width < 600;
                if (isMobile) {
                  return _buildMobileReportsList(columnNames, rows, adminSettings);
                }
                
                return Expanded(
                  child: DataTable2(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    // Significantly increase minWidth so horizontal scroll kicks in before columns get squished
                    minWidth: adminSettings.featureJobCardDownload ? 3000 : 2900,
                    isHorizontalScrollBarVisible: true, // Force scrollbar visibility
                    
                    // Adjust fixed columns based on whether PRINT column is shown
                    fixedLeftColumns: adminSettings.featureJobCardDownload ? 2 : 1,
                    
                    columns: columns,
                    // Generate rows with alternating colors (Zebra Striping)
                    rows: rows,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDuration(String? start, String? end) {
    if (start == null) return 'N/A';
    final startTime = DateTime.tryParse(start);
    if (startTime == null) return 'N/A';

    final endTime = (end != null ? DateTime.tryParse(end) : null) ?? DateTime.now();
    final duration = endTime.difference(startTime);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hr ${minutes} min';
    }
    return '$minutes min';
  }

  Widget _buildMobileReportsList(List<String> columnNames, List<DataRow> rows, AdminSettingsProvider adminSettings) {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        itemCount: _filteredReports.length,
        itemBuilder: (context, index) {
          final report = _filteredReports[index];
          final row = rows[index];
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => _showMobileReportDetails(report, columnNames, row),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          report['job_card_id']?.toString() ?? 'Job #${report['id']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Chip(
                          label: Text(
                            report['status'] ?? 'N/A',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                          backgroundColor: _getStatusColor(report['status']),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Client: ${report['Owner name']?.toString() ?? 'N/A'}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMobileReportDetails(Map<String, dynamic> report, List<String> columnNames, DataRow row) {
    bool hasQr = false;
    try {
      final barcodeContent = report['barcode'] as String?;
      if (barcodeContent != null && barcodeContent.isNotEmpty && barcodeContent != '{}') {
        final Map<String, dynamic> barcodeData = jsonDecode(barcodeContent);
        hasQr = barcodeData.values.any((details) {
          if (details is Map) {
            return details['qr']?.toString().isNotEmpty == true || details['has_image']?.toString() == 'true';
          }
          return false;
        });
      }
    } catch (_) {}

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('Report Details'),
              centerTitle: true,
              elevation: 0,
              actions: [
                if (hasQr)
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.blue),
                    onPressed: () => _shareWarrantyPDF(report),
                    tooltip: 'Share QRs',
                  ),
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.blue),
                  onPressed: () => _printJobCard(report),
                ),
              ],
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['job_card_id']?.toString() ?? 'Job #${report['id']}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 32),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMobileDetailGroup(
                              title: 'Vehicle Information',
                              keys: ['Vehicle No.', 'Brand', 'Vehicle Name', 'Model', 'Color', 'Engine No', 'Chassis No', 'Odometer'],
                              columnNames: columnNames,
                              row: row,
                              context: context,
                            ),
                            _buildMobileDetailGroup(
                              title: 'Client Details',
                              keys: ['Client Name', 'Client Phone'],
                              columnNames: columnNames,
                              row: row,
                              context: context,
                            ),
                            _buildMobileDetailGroup(
                              title: 'Job & Timing',
                              keys: ['Executive', 'Status', 'Date & Time', 'Duration'],
                              columnNames: columnNames,
                              row: row,
                              context: context,
                            ),
                            _buildMobileDetailGroup(
                              title: 'Findings & Actions',
                              keys: ['Complaint', 'Approved', 'Suggested', 'Feedback Text', 'Feedback Voice', 'Marks', 'Media'],
                              columnNames: columnNames,
                              row: row,
                              context: context,
                              isFullWidthGroup: false,
                            ),
                            if ((report['barcode'] as String?)?.isNotEmpty == true && report['barcode'] != '{}')
                              _buildWarrantyQRSection(report['barcode'] as String),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileDetailGroup({
    required String title,
    required List<String> keys,
    required List<String> columnNames,
    required DataRow row,
    required BuildContext context,
    bool isFullWidthGroup = false,
  }) {
    final availableKeys = keys.where((k) => columnNames.contains(k)).toList();
    if (availableKeys.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16.0,
            runSpacing: 20.0,
            children: availableKeys.map((key) {
              final index = columnNames.indexOf(key);
              final cellWidget = row.cells[index].child;
              
              bool isFullWidth = isFullWidthGroup || key.toLowerCase() == 'complaint' || key.toLowerCase() == 'media' || key.toLowerCase() == 'suggested';
              
              return SizedBox(
                width: isFullWidth 
                    ? double.infinity 
                    : (MediaQuery.of(context).size.width - 48) / 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DefaultTextStyle(
                      style: const TextStyle(color: Colors.black, fontSize: 15),
                      child: cellWidget,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWarrantyQRSection(String barcodeJson) {
    Map<String, dynamic> barcodeData = {};
    try {
      barcodeData = jsonDecode(barcodeJson) as Map<String, dynamic>;
    } catch (e) {
      return const SizedBox.shrink();
    }

    if (barcodeData.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Warranty QRs',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16.0,
            runSpacing: 20.0,
            children: barcodeData.entries.map((entry) {
              final position = entry.key;
              final details = entry.value as Map<String, dynamic>;
              final qr = details['qr']?.toString() ?? '';
              final spec = details['spec']?.toString() ?? '';

              return SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      position.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (spec.isNotEmpty)
                      Text(
                        spec,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (qr.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                          color: Colors.white,
                        ),
                        child: QrImageView(
                          data: qr,
                          version: QrVersions.auto,
                          size: 130.0,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
