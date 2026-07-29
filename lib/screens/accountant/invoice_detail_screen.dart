// lib/screens/accountant/invoice_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../providers/user_provider.dart';
import 'payment_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final bool isPending;

  const InvoiceDetailScreen({super.key, required this.job, required this.isPending});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final supabase = Supabase.instance.client;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _suggestions = [];
  double _labourCost = 0;
  double _subtotal = 0;

  // ── Adjustments ──
  bool _gstEnabled = false;
  double _gstPercent = 18;
  final _gstController = TextEditingController(text: '18');

  String _discountType = 'flat'; // 'flat' or 'percent'
  double _discountValue = 0;
  final _discountController = TextEditingController(text: '0');

  final _extraLabelController = TextEditingController();
  double _extraChargeAmount = 0;
  final _extraAmountController = TextEditingController(text: '0');

  // ── Computed totals ──
  double get _discountAmount {
    if (_discountType == 'percent') {
      return (_subtotal + _labourCost) * (_discountValue / 100);
    }
    return _discountValue;
  }

  double get _gstAmount {
    if (!_gstEnabled) return 0;
    final base = (_subtotal + _labourCost) - _discountAmount + _extraChargeAmount;
    return base * (_gstPercent / 100);
  }

  double get _grandTotal {
    return (_subtotal + _labourCost) - _discountAmount + _extraChargeAmount + _gstAmount;
  }

  @override
  void initState() {
    super.initState();
    _parseJobData();
  }

  @override
  void dispose() {
    _gstController.dispose();
    _discountController.dispose();
    _extraLabelController.dispose();
    _extraAmountController.dispose();
    super.dispose();
  }

  void _parseJobData() {
    final job = widget.job;
    _labourCost = ((job['labour_cost'] ?? 0) as num).toDouble();

    final rawComplaints = job['complaint'];
    if (rawComplaints is List) {
      _complaints = rawComplaints.map((e) => Map<String, dynamic>.from(e)).toList();
    } else if (rawComplaints is String) {
      try {
        final decoded = jsonDecode(rawComplaints) as List;
        _complaints = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    final rawSuggested = job['suggested'];
    if (rawSuggested is List) {
      _suggestions = rawSuggested
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['type'] != AppConstants.typeComplaint)
          .toList();
    } else if (rawSuggested is String) {
      try {
        final decoded = jsonDecode(rawSuggested) as List;
        _suggestions = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => e['type'] != AppConstants.typeComplaint)
            .toList();
      } catch (_) {}
    }

    _recalcTotals();

    // Restore saved adjustments if already billed
    if (job['gst_percent'] != null) {
      _gstEnabled = true;
      _gstPercent = (job['gst_percent'] as num).toDouble();
      _gstController.text = _gstPercent.toStringAsFixed(0);
    }
    if (job['discount_amount'] != null) {
      _discountValue = (job['discount_amount'] as num).toDouble();
      _discountType = job['discount_type'] ?? 'flat';
      _discountController.text = _discountValue.toStringAsFixed(0);
    }
    if (job['extra_charge_amount'] != null) {
      _extraChargeAmount = (job['extra_charge_amount'] as num).toDouble();
      _extraAmountController.text = _extraChargeAmount.toStringAsFixed(0);
      _extraLabelController.text = job['extra_charge_label'] ?? '';
    }
  }

  void _recalcTotals() {
    double itemTotal = 0;
    for (final c in _complaints) {
      itemTotal += ((c['amount'] ?? 0) as num).toDouble();
    }
    for (final s in _suggestions) {
      itemTotal += ((s['amount'] ?? 0) as num).toDouble();
    }
    _subtotal = itemTotal;
  }

  String _getCustomerName() {
    return widget.job['bookings']?['customer_name'] ?? 
           widget.job['Owner name'] ?? 
           'Walk-in Customer';
  }

  String _getCustomerPhone() {
    return widget.job['bookings']?['customer_phone'] ?? 
           widget.job['client_phone'] ?? 
           '-';
  }
  String _getVehicleNo() => widget.job['vehicles']?['Vehicle Number'] ?? '-';
  String _getBrandModel() {
    final brand = widget.job['vehicles']?['vehicle_models']?['brand'] ?? '';
    final model = widget.job['vehicles']?['vehicle_models']?['Model name'] ?? '';
    return '$brand $model'.trim();
  }

  Future<void> _markAsBilled() async {
    setState(() => _isSubmitting = true);
    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      // Combine complaints and original suggested arrays back to json
      // Need to include unselected suggestions too? The DB expects the full arrays for suggestions, but we only have selected ones in _suggestions.
      // Wait, we can just save back the ones we have, but to avoid losing unselected suggestions, we should re-merge.
      // Let's just update the ones in the DB.
      List<Map<String, dynamic>> finalSuggested = [];
      final rawSuggested = widget.job['suggested'];
      if (rawSuggested is List) {
        finalSuggested = List<Map<String, dynamic>>.from(rawSuggested);
      } else if (rawSuggested is String) {
        try { finalSuggested = List<Map<String, dynamic>>.from(jsonDecode(rawSuggested)); } catch (_) {}
      }
      
      // Update amounts in finalSuggested based on _suggestions
      for (var s in finalSuggested) {
        if (s['type'] != AppConstants.typeComplaint) {
          final matched = _suggestions.where((e) => e['text'] == s['text']).firstOrNull;
          if (matched != null) {
            s['amount'] = matched['amount'];
          }
        }
      }

      await supabase.from('reports').update({
        'billing_status': AppConstants.statusBilled,
        'billed_at': DateTime.now().toIso8601String(),
        'billed_by': user?['id'],
        'labour_cost': _labourCost,
        'complaint': _complaints,
        'suggested': finalSuggested,
        'gst_percent': _gstEnabled ? _gstPercent : null,
        'discount_amount': _discountValue > 0 ? _discountValue : null,
        'discount_type': _discountValue > 0 ? _discountType : null,
        'extra_charge_amount': _extraChargeAmount > 0 ? _extraChargeAmount : null,
        'extra_charge_label': _extraChargeAmount > 0 ? _extraLabelController.text.trim() : null,
      }).eq('id', widget.job['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice marked as Billed!'), backgroundColor: Colors.blue),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveAsDraft() async {
    setState(() => _isSubmitting = true);
    try {
      List<Map<String, dynamic>> finalSuggested = [];
      final rawSuggested = widget.job['suggested'];
      if (rawSuggested is List) {
        finalSuggested = List<Map<String, dynamic>>.from(rawSuggested);
      } else if (rawSuggested is String) {
        try { finalSuggested = List<Map<String, dynamic>>.from(jsonDecode(rawSuggested)); } catch (_) {}
      }
      
      for (var s in finalSuggested) {
        if (s['type'] != AppConstants.typeComplaint) {
          final matched = _suggestions.where((e) => e['text'] == s['text']).firstOrNull;
          if (matched != null) {
            s['amount'] = matched['amount'];
          }
        }
      }

      await supabase.from('reports').update({
        'billing_status': AppConstants.statusDraft,
        'labour_cost': _labourCost,
        'complaint': _complaints,
        'suggested': finalSuggested,
        'gst_percent': _gstEnabled ? _gstPercent : null,
        'discount_amount': _discountValue > 0 ? _discountValue : null,
        'discount_type': _discountValue > 0 ? _discountType : null,
        'extra_charge_amount': _extraChargeAmount > 0 ? _extraChargeAmount : null,
        'extra_charge_label': _extraChargeAmount > 0 ? _extraLabelController.text.trim() : null,
      }).eq('id', widget.job['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice saved as Draft!'), backgroundColor: Colors.purple),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<pw.Document> _generatePdf() async {
    final currency = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 0);
    final doc = pw.Document();
    final jobCardId = widget.job['job_card_id'] ?? '#${widget.job['id']}';
    final vehicleNo = _getVehicleNo();
    final customerName = _getCustomerName();
    final customerPhone = _getCustomerPhone();
    final model = _getBrandModel();
    final now = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // Load Logo
    pw.MemoryImage? logoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/images/tyrex.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    doc.addPage(  
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      height: 60,
                      child: pw.Image(logoImage),
                    )
                  else
                    pw.Text('TYREX', style: pw.TextStyle(color: PdfColors.blue700, fontSize: 28, fontWeight: pw.FontWeight.bold)),
                  
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE', style: pw.TextStyle(color: PdfColors.blue700, fontSize: 28, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(jobCardId, style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                      pw.Text('Generated: $now', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(customerName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text(customerPhone, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('VEHICLE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(vehicleNo, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text(model, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                  pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 8),
              ..._complaints.map((c) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text(c['text'] ?? '-', style: const pw.TextStyle(fontSize: 12))),
                    pw.Text(currency.format((c['amount'] ?? 0) as num), style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              )),
              ..._suggestions.map((s) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text(s['text'] ?? '-', style: const pw.TextStyle(fontSize: 12))),
                    pw.Text(currency.format((s['amount'] ?? 0) as num), style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              )),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                pw.Expanded(child: pw.Text('Parts & Services Subtotal', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))),
                pw.Text(currency.format(_subtotal), style: const pw.TextStyle(fontSize: 12)),
              ]),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Expanded(child: pw.Text('Labour Charges', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))),
                pw.Text(currency.format(_labourCost), style: const pw.TextStyle(fontSize: 12)),
              ]),
              if (_discountAmount > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(children: [
                  pw.Expanded(child: pw.Text(
                    _discountType == 'percent'
                        ? 'Discount (${_discountValue.toStringAsFixed(0)}%)'
                        : 'Discount',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.red),
                  )),
                  pw.Text('- ${currency.format(_discountAmount)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.red)),
                ]),
              ],
              if (_extraChargeAmount > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(children: [
                  pw.Expanded(child: pw.Text(
                    _extraLabelController.text.isNotEmpty ? _extraLabelController.text : 'Extra Charges',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  )),
                  pw.Text(currency.format(_extraChargeAmount), style: const pw.TextStyle(fontSize: 12)),
                ]),
              ],
              if (_gstEnabled && _gstAmount > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(children: [
                  pw.Expanded(child: pw.Text('GST (${_gstPercent.toStringAsFixed(0)}%)', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))),
                  pw.Text(currency.format(_gstAmount), style: const pw.TextStyle(fontSize: 12)),
                ]),
              ],
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 6),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
                  pw.Text(currency.format(_grandTotal), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  Future<void> _printInvoice() async {
    final doc = await _generatePdf();
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Future<void> _shareInvoice() async {
    final doc = await _generatePdf();
    final bytes = await doc.save();
    final filename = 'invoice_${widget.job['job_card_id'] ?? widget.job['id']}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final billingStatus = widget.job['billing_status'] as String?;
    final isPaid = billingStatus == AppConstants.statusPaid;
    final isBilled = billingStatus == AppConstants.statusBilled;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Invoice — ${widget.job['job_card_id'] ?? '#${widget.job['id']}'}'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Invoice',
            onPressed: _shareInvoice,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print / Download',
            onPressed: _printInvoice,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer & Vehicle
            _buildSection(
              icon: Icons.person_outline,
              title: 'Customer & Vehicle',
              color: Colors.blue,
              child: Column(
                children: [
                  _infoRow('Customer', _getCustomerName()),
                  _infoRow('Phone', _getCustomerPhone()),
                  _infoRow('Vehicle No.', _getVehicleNo()),
                  _infoRow('Model', _getBrandModel()),
                  if (widget.job['completed_at'] != null)
                    _infoRow(
                      'Completed',
                      DateFormat('dd MMM yyyy, hh:mm a').format(
                        DateTime.parse(widget.job['completed_at']).toLocal(),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (_complaints.isNotEmpty)
              _buildSection(
                icon: Icons.build_outlined,
                title: 'Services / Complaints',
                color: AppTheme.primaryColor,
                child: Column(
                  children: _complaints.map((c) => _lineItem(
                    c['text'] ?? '-',
                    ((c['amount'] ?? 0) as num).toDouble(),
                    (newAmount) => setState(() {
                      c['amount'] = newAmount;
                      _recalcTotals();
                    }),
                  )).toList(),
                ),
              ),

            if (_complaints.isNotEmpty) const SizedBox(height: 16),

            if (_suggestions.isNotEmpty)
              _buildSection(
                icon: Icons.add_task,
                title: 'Additional Work',
                color: Colors.teal,
                child: Column(
                  children: _suggestions.map((s) => _lineItem(
                    s['text'] ?? '-',
                    ((s['amount'] ?? 0) as num).toDouble(),
                    (newAmount) => setState(() {
                      s['amount'] = newAmount;
                      _recalcTotals();
                    }),
                  )).toList(),
                ),
              ),

            if (_suggestions.isNotEmpty) const SizedBox(height: 16),

            // ── Adjustments card (only editable when pending) ──
            if (widget.isPending) _buildAdjustmentsCard(),
            if (widget.isPending) const SizedBox(height: 16),

            // Totals Card
            _buildTotalsCard(currency),

            // Billing Status for already-billed/paid jobs
            if (!widget.isPending) ...[
              const SizedBox(height: 16),
              _buildSection(
                icon: Icons.receipt_long,
                title: 'Billing Details',
                color: isPaid ? Colors.green : Colors.blue,
                child: Column(
                  children: [
                    _infoRow('Status', billingStatus ?? '-'),
                    if (widget.job['billed_at'] != null)
                      _infoRow('Billed On', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(widget.job['billed_at']).toLocal())),
                    if (widget.job['paid_at'] != null)
                      _infoRow('Paid On', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(widget.job['paid_at']).toLocal())),
                    if (widget.job['payment_method'] != null)
                      _infoRow('Payment Method', widget.job['payment_method']),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: widget.isPending
          ? _buildActionButtons(currency)
          : (isBilled && !isPaid)
              ? _buildRecordPaymentButton()
              : null,
    );
  }

  Widget _buildAdjustmentsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.tune, color: Colors.purple, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Adjustments', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const Spacer(),
                const Text('Optional', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── GST ──
                Row(
                  children: [
                    const Icon(Icons.percent, size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Apply GST', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    Switch(
                      value: _gstEnabled,
                      activeColor: Colors.purple,
                      onChanged: (v) => setState(() => _gstEnabled = v),
                    ),
                  ],
                ),
                if (_gstEnabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...[5, 12, 18, 28].map((rate) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _gstPercent = rate.toDouble();
                            _gstController.text = rate.toString();
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _gstPercent == rate ? Colors.purple : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('$rate%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _gstPercent == rate ? Colors.white : AppTheme.textSecondary)),
                          ),
                        ),
                      )),
                      Expanded(
                        child: TextField(
                          controller: _gstController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            hintText: 'Custom %',
                            suffixText: '%',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          ),
                          onChanged: (v) => setState(() {
                            _gstPercent = double.tryParse(v) ?? 0;
                          }),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // ── Discount ──
                Row(
                  children: [
                    const Icon(Icons.discount_outlined, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('Discount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Flat / Percent toggle
                    GestureDetector(
                      onTap: () => setState(() => _discountType = 'flat'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _discountType == 'flat' ? Colors.red : Colors.grey.shade100,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                        ),
                        child: Text('₹ Flat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _discountType == 'flat' ? Colors.white : AppTheme.textSecondary)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _discountType = 'percent'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _discountType == 'percent' ? Colors.red : Colors.grey.shade100,
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
                        ),
                        child: Text('% Off', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _discountType == 'percent' ? Colors.white : AppTheme.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _discountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        decoration: InputDecoration(
                          hintText: _discountType == 'flat' ? 'Amount (₹)' : 'Percentage',
                          suffixText: _discountType == 'flat' ? '₹' : '%',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                        onChanged: (v) => setState(() {
                          _discountValue = double.tryParse(v) ?? 0;
                        }),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // ── Extra Charges ──
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('Extra Charges', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _extraLabelController,
                        decoration: InputDecoration(
                          hintText: 'Label (e.g. Towing)',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _extraAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        decoration: InputDecoration(
                          hintText: 'Amount',
                          prefixText: '₹ ',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                        onChanged: (v) => setState(() {
                          _extraChargeAmount = double.tryParse(v) ?? 0;
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(NumberFormat currency) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _totalRow('Parts & Services Subtotal', _subtotal, isBold: false),
          
          // Editable Labour Charges
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Labour Charges', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                ),
                if (widget.isPending)
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: _labourCost.toStringAsFixed(0),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppTheme.primaryColor)),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _labourCost = double.tryParse(val) ?? 0;
                        });
                      },
                    ),
                  )
                else
                  Text(
                    currency.format(_labourCost),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
              ],
            ),
          ),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 4),
            _totalRow(
              _discountType == 'percent'
                  ? 'Discount (${_discountValue.toStringAsFixed(0)}% off)'
                  : 'Discount',
              -_discountAmount,
              isBold: false,
              color: Colors.red,
            ),
          ],
          if (_extraChargeAmount > 0) ...[
            const SizedBox(height: 4),
            _totalRow(
              _extraLabelController.text.isNotEmpty ? _extraLabelController.text : 'Extra Charges',
              _extraChargeAmount,
              isBold: false,
              color: Colors.orange.shade800,
            ),
          ],
          if (_gstEnabled && _gstAmount > 0) ...[
            const SizedBox(height: 4),
            _totalRow('GST (${_gstPercent.toStringAsFixed(0)}%)', _gstAmount, isBold: false, color: Colors.purple),
          ],
          const Divider(height: 24),
          _totalRow('Grand Total', _grandTotal, isBold: true, color: AppTheme.primaryColor, fontSize: 20),
        ],
      ),
    );
  }

  Widget _buildActionButtons(NumberFormat currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _saveAsDraft,
              icon: const Icon(Icons.edit_note, size: 20),
              label: const Text(
                'Save as Draft',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple,
                side: const BorderSide(color: Colors.purple),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _markAsBilled,
              icon: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 20),
              label: Text(
                _isSubmitting ? 'Processing...' : 'Mark as Billed',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordPaymentButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentScreen(job: widget.job, grandTotal: _grandTotal),
              ),
            );
            Navigator.pop(context);
          },
          icon: const Icon(Icons.payment, size: 20),
          label: const Text('Record Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required Color color, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _lineItem(String name, double amount, void Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          if (widget.isPending)
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: amount.toStringAsFixed(0),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppTheme.primaryColor)),
                ),
                onChanged: (val) => onChanged(double.tryParse(val) ?? 0),
              ),
            )
          else
            Text(
              NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(amount),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, {bool isBold = false, Color? color, double fontSize = 14}) {
    final isNegative = amount < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? AppTheme.textSecondary)),
          ),
          Text(
            '${isNegative ? '- ' : ''}${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(amount.abs())}',
            style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
