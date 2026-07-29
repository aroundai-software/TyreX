// lib/screens/saved_job_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SavedJobDetailScreen extends StatefulWidget {
  final int reportId;

  const SavedJobDetailScreen({super.key, required this.reportId});

  @override
  State<SavedJobDetailScreen> createState() => _SavedJobDetailScreenState();
}

class _SavedJobDetailScreenState extends State<SavedJobDetailScreen> {
  final supabase = Supabase.instance.client;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  Map<String, dynamic>? _report;
  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _approvedItems = [];
  String? _feedbackText;
  String? _feedbackAudio;
  bool _isAudioPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isAudioPlaying = state == PlayerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  List<dynamic> _safeJsonDecodeList(dynamic data) {
    if (data is String && data.isNotEmpty && data.startsWith('[')) {
      try {
        return jsonDecode(data) as List;
      } catch (_) {
        return [];
      }
    } else if (data is List) {
      return data;
    }
    return [];
  }

  Future<void> _loadReport() async {
    try {
      final response = await supabase
          .from('reports')
          .select('''
            *,
            vehicles!reports_vehicle_fk(
              "Vehicle Number", vehicle_name, "Color",
              vehicle_models!inner(brand, "Model name")
            )
          ''')
          .eq('id', widget.reportId)
          .single();

      final suggestedList = _safeJsonDecodeList(response['suggested']);
      final complaintList = _safeJsonDecodeList(response['complaint']);
      final approvedList = _safeJsonDecodeList(response['approved']);

      List<Map<String, dynamic>> complaints = [];
      List<Map<String, dynamic>> suggestions = [];

      if (suggestedList.isNotEmpty) {
        complaints = suggestedList
            .where((item) => item['type'] == AppConstants.typeComplaint)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        suggestions = suggestedList
            .where((item) => item['type'] == AppConstants.typeSuggestion)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        complaints = complaintList.map((e) {
          if (e is String) {
            return {'text': e, 'amount': 0, 'type': AppConstants.typeComplaint};
          }
          return Map<String, dynamic>.from(e);
        }).toList();
      }

      setState(() {
        _report = response;
        _complaints = complaints;
        _suggestions = suggestions;
        _approvedItems =
            approvedList.map((e) => Map<String, dynamic>.from(e)).toList();
        _feedbackText = response['customer_feedback_text'] as String?;
        _feedbackAudio = response['customer_feedback_audio'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAudio() async {
    if (_feedbackAudio == null || _feedbackAudio!.isEmpty) return;
    if (_isAudioPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(_feedbackAudio!));
    }
  }

  double get _laborCost =>
      (_report?['labour_cost'] as num?)?.toDouble() ?? 0.0;

  double get _totalAmount {
    if (_approvedItems.isNotEmpty) {
      final itemsTotal = _approvedItems.fold(
          0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0).toDouble());
      return itemsTotal + _laborCost;
    }
    final suggestedTotal = [..._complaints, ..._suggestions].fold(
        0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0).toDouble());
    return suggestedTotal + _laborCost;
  }

  @override
  Widget build(BuildContext context) {
    final vehicleNo = _report?['vehicles']?['Vehicle Number'] ?? 'Job Details';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          vehicleNo,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.primaryColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Ready for Inspection',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading details: $_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final vehicle = _report?['vehicles'];
    final brand = vehicle?['vehicle_models']?['brand'] ?? '';
    final model = vehicle?['vehicle_models']?['Model name'] ?? '';
    final vehicleName = vehicle?['vehicle_name'] ?? '';
    final color = vehicle?['Color'] ?? '';
    final ownerName = _report?['Owner name'] ?? '';
    final clientPhone = _report?['client_phone'] ?? '';
    final createdAt = _report?['created_at'];
    String dateStr = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Vehicle Header Card
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle?['Vehicle Number'] ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [brand, model, vehicleName, if (color.isNotEmpty) color]
                          .where((s) => s.toString().isNotEmpty)
                          .join(' • '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    if (ownerName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ownerName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (clientPhone.isNotEmpty)
                      Text(
                        clientPhone,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (dateStr.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Customer Voice / Text Response Card
        if (_feedbackAudio != null && _feedbackAudio!.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFF10B981), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.mic, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Customer Voice Response',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_feedbackText != null && _feedbackText!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _feedbackText!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _toggleAudio,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isAudioPlaying
                          ? const Color(0xFF065F46)
                          : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isAudioPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isAudioPlaying
                              ? 'Pause Voice Message'
                              : 'Play Voice Message',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else if (_feedbackText != null && _feedbackText!.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFF10B981), width: 1.5),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.comment_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Customer Response',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _feedbackText!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Approved Services Card
        if (_approvedItems.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.check, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Customer Approved Services',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._approvedItems.map((item) {
                  final materials = (item['materials'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['text'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '₹${(item['amount'] as num? ?? 0.0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        if (materials.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: materials
                                .map(
                                  (m) => Chip(
                                    label: Text(
                                      m,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    backgroundColor:
                                        AppTheme.primaryColor.withValues(alpha: 0.1),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 0),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    side: BorderSide(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.3)),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const Divider(height: 20),
                      ],
                    ),
                  );
                }),
                if (_laborCost > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Labour Cost',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          '₹${_laborCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(thickness: 1.5),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '₹${_totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Original Complaints Card
        if (_complaints.isNotEmpty || _suggestions.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.build_outlined,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _approvedItems.isNotEmpty
                            ? 'All Suggested Items'
                            : 'Customer Complaints',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...[..._complaints, ..._suggestions].map((item) {
                  final isComplaint =
                      item['type'] == AppConstants.typeComplaint;
                  final amount =
                      (item['amount'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin:
                              const EdgeInsets.only(right: 10, top: 5),
                          decoration: BoxDecoration(
                            color: isComplaint
                                ? AppTheme.primaryColor
                                : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item['text'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (amount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₹${amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                if (_complaints.isEmpty && _suggestions.isEmpty)
                  const Text(
                    'No complaints recorded.',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 24),
        _buildScannedQRsSection(),
      ],
    );
  }

  Widget _buildScannedQRsSection() {
    final photoUrlsDynamic = _report?['photo_urls'];
    if (photoUrlsDynamic == null) return const SizedBox.shrink();
    
    List<String> photoUrls = [];
    if (photoUrlsDynamic is List) {
      photoUrls = photoUrlsDynamic.map((e) => e.toString()).toList();
    } else if (photoUrlsDynamic is String && photoUrlsDynamic.startsWith('[')) {
      try {
        final decoded = jsonDecode(photoUrlsDynamic) as List;
        photoUrls = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    
    final qrUrls = photoUrls.where((url) => url.contains('_tyreqr_')).toList();
    if (qrUrls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scanned Tyre QRs',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: qrUrls.length,
            itemBuilder: (context, index) {
              final url = qrUrls[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(url, fit: BoxFit.cover, width: double.infinity),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        try {
                          final response = await http.get(Uri.parse(url));
                          final dir = await getTemporaryDirectory();
                          final file = File('${dir.path}/tyre_qr_$index.jpg');
                          await file.writeAsBytes(response.bodyBytes);
                          await Share.shareXFiles([XFile(file.path)], text: 'Tyre QR photo');
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Share', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
