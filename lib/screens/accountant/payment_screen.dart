// lib/screens/accountant/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';

class SplitPayment {
  String method;
  TextEditingController amountController;
  TextEditingController transactionIdController;

  SplitPayment({
    required this.method,
    required double initialAmount,
  })  : amountController = TextEditingController(text: initialAmount > 0 ? initialAmount.toStringAsFixed(0) : ''),
        transactionIdController = TextEditingController();

  void dispose() {
    amountController.dispose();
    transactionIdController.dispose();
  }
}

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final double grandTotal;

  const PaymentScreen({super.key, required this.job, required this.grandTotal});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final supabase = Supabase.instance.client;
  final _notesController = TextEditingController();

  final List<String> _paymentMethods = ['UPI', 'Card', 'Cash', 'Credit', 'Bajaj Finance', 'Buyback', 'Others'];
  final List<SplitPayment> _splits = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _splits.add(SplitPayment(method: 'UPI', initialAmount: widget.grandTotal));
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (var split in _splits) {
      split.dispose();
    }
    super.dispose();
  }

  void _addSplit() {
    double currentTotal = _splits.fold(0.0, (sum, split) {
      return sum + (double.tryParse(split.amountController.text) ?? 0.0);
    });
    double remaining = widget.grandTotal - currentTotal;
    if (remaining < 0) remaining = 0;
    
    setState(() {
      _splits.add(SplitPayment(method: 'Cash', initialAmount: remaining));
    });
  }

  void _removeSplit(int index) {
    setState(() {
      _splits[index].dispose();
      _splits.removeAt(index);
      
      // Re-balance if there are still splits left
      if (_splits.length > 1) {
        _onAmountChanged(0, _splits[0].amountController.text);
      }
    });
  }

  void _onAmountChanged(int changedIndex, String value) {
    if (_splits.length < 2) {
      setState(() {});
      return;
    }
    
    // The "buffer" split that auto-adjusts is usually the last one,
    // unless the user is currently editing the last one.
    int targetIndex = (changedIndex == _splits.length - 1) 
        ? _splits.length - 2 
        : _splits.length - 1;
        
    // Sum up everything EXCEPT the buffer split
    double sumOthers = 0;
    for (int i = 0; i < _splits.length; i++) {
      if (i == targetIndex) continue;
      sumOthers += double.tryParse(_splits[i].amountController.text) ?? 0.0;
    }
    
    double remaining = widget.grandTotal - sumOthers;
    if (remaining < 0) remaining = 0;
    
    _splits[targetIndex].amountController.text = remaining > 0 ? remaining.toStringAsFixed(0) : '0';
    
    setState(() {});
  }

  Future<void> _recordPayment() async {
    // Validate amounts
    double totalEntered = _splits.fold(0.0, (sum, split) {
      return sum + (double.tryParse(split.amountController.text) ?? 0.0);
    });

    if ((totalEntered - widget.grandTotal).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Total split amount (₹${totalEntered.toStringAsFixed(0)}) must exactly equal Grand Total (₹${widget.grandTotal.toStringAsFixed(0)})'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // 1. Insert into payments table
      for (var split in _splits) {
        final amount = double.tryParse(split.amountController.text) ?? 0.0;
        if (amount <= 0) continue; // Skip 0 amounts just in case

        final tid = split.transactionIdController.text.trim();
        
        await supabase.from('payments').insert({
          'report_id': widget.job['id'],
          'method': split.method,
          'amount': amount,
          'transaction_id': tid.isNotEmpty ? tid : null,
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      // 2. Update reports table
      await supabase.from('reports').update({
        'billing_status': AppConstants.statusPaid,
        'paid_at': DateTime.now().toUtc().toIso8601String(),
        'payment_method': 'Split', // Legacy marker
        'payment_notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      }).eq('id', widget.job['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Payment recorded successfully!'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Record Payment'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount due banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Amount Due', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    currency.format(widget.grandTotal),
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.job['vehicles']?['Vehicle Number'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text('Payment Methods', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),

            // Splits list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _splits.length,
              itemBuilder: (context, index) {
                final split = _splits[index];
                final requiresTransactionId = ['Card', 'UPI', 'Bajaj Finance', 'Others'].contains(split.method);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Payment ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          if (_splits.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _removeSplit(index),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Payment method selector inside split
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _paymentMethods.map((method) {
                          final isSelected = split.method == method;
                          return GestureDetector(
                            onTap: () => setState(() => split.method = method),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryColor : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_iconForMethod(method), size: 14, color: isSelected ? Colors.white : AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    method,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Amount
                      TextField(
                        controller: split.amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount (₹)',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (val) => _onAmountChanged(index, val),
                      ),
                      
                      if (requiresTransactionId) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: split.transactionIdController,
                          decoration: InputDecoration(
                            labelText: 'Transaction ID / Ref No.',
                            hintText: 'e.g., 1234567890',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            Center(
              child: TextButton.icon(
                onPressed: _addSplit,
                icon: const Icon(Icons.add, color: AppTheme.primaryColor),
                label: const Text('Add Split Payment', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 24),

            const Text('Notes (optional)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _recordPayment,
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle, size: 20),
                label: Text(
                  _isSubmitting ? 'Recording...' : 'Confirm Payment',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForMethod(String method) {
    switch (method) {
      case 'Card': return Icons.credit_card;
      case 'UPI': return Icons.phone_android;
      case 'Cash': return Icons.money;
      case 'Credit': return Icons.pending_actions;
      case 'Bajaj Finance': return Icons.account_balance;
      case 'Buyback': return Icons.swap_horiz;
      case 'Others': return Icons.more_horiz;
      default: return Icons.payment;
    }
  }
}
