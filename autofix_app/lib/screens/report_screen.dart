// lib/screens/report_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers/src/source.dart';
import '../providers/user_provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:printing/printing.dart';
import '../widgets/printable_job_card.dart';
import '../theme/app_theme.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import '../providers/report_provider.dart';
import '../providers/admin_settings_provider.dart';
import '../services/local_media_service.dart';

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
      'Executive',
      'Inspector'
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
        report['inspector']?['username'] ?? 'N/A',
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
                    }
                  },
                  child: ListView(
                    // Keep the ListView for filters + table
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildFilterCard(), // Filters remain in the body
                      const SizedBox(height: 16),
                      _buildServiceHistoryCard(
                        isLoading: reportProvider.isLoading &&
                            reportProvider.reports.isEmpty,
                        filteredReports: _filteredReports,
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
                  DataColumn2(label: Text('Inspector'), size: ColumnSize.M),
                  DataColumn2(label: Text('Date & Time'), size: ColumnSize.M),
                  DataColumn2(label: Text('Status'), size: ColumnSize.S),
                  DataColumn2(label: Text('Complaint'), size: ColumnSize.L),
                  DataColumn2(label: Text('Suggested'), size: ColumnSize.L),
                  DataColumn2(label: Text('Approved'), size: ColumnSize.L),
                  DataColumn2(label: Text('Feedback Text'), size: ColumnSize.L),
                  DataColumn2(label: Text('Feedback Voice'), size: ColumnSize.S),
                  DataColumn2(label: Text('Marks'), size: ColumnSize.S),
                  DataColumn2(label: Text('Media'), size: ColumnSize.S),
                ]);
                
                return SizedBox(
                  height: 600,
                  child: DataTable2(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    minWidth: adminSettings.featureJobCardDownload ? 2200 : 2100,
                    
                    // Adjust fixed columns based on whether PRINT column is shown
                    fixedLeftColumns: adminSettings.featureJobCardDownload ? 2 : 1,
                    
                    columns: columns,
                    // Generate rows with alternating colors (Zebra Striping)
                    rows: List<DataRow>.generate(_filteredReports.length, (index) {
                      final report = _filteredReports[index];
                      final vehicle = report['vehicles'];
                      final model = vehicle?['vehicle_models'];

                      // Build cells dynamically based on settings
                      List<DataCell> cells = [];
                      
                      // Add PRINT cell only if feature is enabled
                      if (adminSettings.featureJobCardDownload) {
                        cells.add(
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.download,
                                  color: AppTheme.textSecondary),
                              onPressed: () => _printJobCard(report),
                            ),
                          ),
                        );
                      }
                      
                      // Add all other cells
                      cells.addAll([
                        DataCell(Text(vehicle?['Vehicle Number'] ?? 'N/A')),
                        DataCell(Text(vehicle?['vehicle_name'] ?? 'N/A')),
                        DataCell(Text(model?['Model name'] ?? 'N/A')),
                        DataCell(Text(model?['brand'] ?? 'N/A')),
                        DataCell(Text(vehicle?['Color'] ?? 'N/A')),
                        DataCell(Text(vehicle?['Engine Number'] ?? 'N/A')),
                        DataCell(Text(vehicle?['Chasis Number'] ?? 'N/A')),
                        DataCell(Text(report['Owner name'] ?? 'N/A')),
                        DataCell(Text(report['client_phone'] ?? 'N/A')),
                        DataCell(Text(
                            report['odometer_reading']?.toString() ?? 'N/A')),
                        DataCell(Text(report['executive']?['username'] ?? 'N/A')),
                        DataCell(Text(report['inspector']?['username'] ?? 'N/A')),
                        DataCell(Text(DateFormat('dd/MM/yy, HH:mm')
                            .format(DateTime.parse(report['created_at'])))),
                        DataCell(Chip(
                            label: Text(report['status'] ?? 'N/A',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11)),
                            backgroundColor: _getStatusColor(report['status']),
                            padding: const EdgeInsets.symmetric(horizontal: 4))),
                        DataCell(Text(_formatJsonCell(report['complaint']),
                            overflow: TextOverflow.ellipsis)),
                        DataCell(Text(_formatJsonCell(report['suggested']),
                            overflow: TextOverflow.ellipsis)),
                        DataCell(Text(_formatJsonCell(report['approved']),
                            overflow: TextOverflow.ellipsis)),
                        DataCell(Text(report['customer_feedback_text'] ?? 'N/A')),
                        DataCell(report['customer_feedback_audio'] != null
                            ? IconButton(
                                icon: const Icon(Icons.play_circle_fill,
                                    color: Colors.green),
                                onPressed: () async => await launchUrl(
                                    Uri.parse(report['customer_feedback_audio'])))
                            : const Text('N/A')),
                        DataCell(
                            (report['marks'] as String?)?.isNotEmpty == true &&
                                    report['marks'] != '[]'
                                ? TextButton(
                                    onPressed: () =>
                                        _showMarksDialog(report['marks']),
                                    child: const Text('View'))
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
                    }),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
