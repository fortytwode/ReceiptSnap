import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';

import '../../../common/models/models.dart';
import '../../../common/services/services.dart';
import '../../../common/theme/app_theme.dart';
import '../../../common/widgets/widgets.dart';
import '../providers/receipts_provider.dart';

class ReceiptDetailScreen extends ConsumerStatefulWidget {
  final String receiptId;

  const ReceiptDetailScreen({
    super.key,
    required this.receiptId,
  });

  @override
  ConsumerState<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends ConsumerState<ReceiptDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  DateTime? _selectedDate;
  String? _selectedCurrency;
  String? _selectedCategory;
  bool _isLoading = false;
  Receipt? _receipt;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _initializeForm(Receipt receipt) {
    if (_receipt?.id != receipt.id) {
      _receipt = receipt;
      _merchantController.text = receipt.merchant ?? '';
      _amountController.text = receipt.amount?.toString() ?? '';
      _noteController.text = receipt.note ?? '';
      _selectedDate = receipt.date;
      _selectedCurrency = receipt.currency ?? 'USD';
      _selectedCategory = receipt.category;
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate()) return;
    if (_receipt == null) return;

    setState(() => _isLoading = true);

    try {
      final updated = _receipt!.copyWith(
        merchant: _merchantController.text.trim(),
        date: _selectedDate,
        amount: double.tryParse(_amountController.text),
        currency: _selectedCurrency,
        category: _selectedCategory,
        note: _noteController.text.trim(),
        ocrStatus: OcrStatus.confirmed,
      );

      final service = ref.read(receiptsServiceProvider);
      await service.updateReceipt(updated);

      // Refresh receipts list
      ref.read(receiptsProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt saved'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReceipt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: const Text('Are you sure you want to delete this receipt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || _receipt == null) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(receiptsServiceProvider);
      await service.deleteReceipt(_receipt!.id);

      // Refresh receipts list
      ref.read(receiptsProvider.notifier).refresh();

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _openImageViewer() {
    if (_receipt == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          imageUrl: _receipt!.imageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receiptAsync = ref.watch(receiptDetailProvider(widget.receiptId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Details'),
        actions: [
          if (_receipt != null && !_receipt!.isInReport)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isLoading ? null : _deleteReceipt,
            ),
        ],
      ),
      body: receiptAsync.when(
        loading: () => const LoadingWidget(message: 'Loading receipt...'),
        error: (error, _) => ErrorDisplay(
          message: error.toString(),
          onRetry: () => ref.refresh(receiptDetailProvider(widget.receiptId)),
        ),
        data: (receipt) {
          _initializeForm(receipt);
          return LoadingOverlay(
            isLoading: _isLoading,
            message: 'Saving...',
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image preview
                    GestureDetector(
                      onTap: _openImageViewer,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildImage(receipt),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Center(
                      child: Text(
                        'Tap to view full image',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Status message
                    if (receipt.ocrStatus == OcrStatus.needsConfirmation)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.info.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.info),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please review and confirm the receipt details below.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Form fields
                    TextFormField(
                      controller: _merchantController,
                      decoration: const InputDecoration(
                        labelText: 'Merchant',
                        prefixIcon: Icon(Icons.store),
                      ),
                      enabled: !receipt.isInReport,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Please enter merchant name' : null,
                    ),

                    const SizedBox(height: 16),

                    // Date picker
                    InkWell(
                      onTap: receipt.isInReport ? null : _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _selectedDate != null
                              ? DateFormat.yMMMd().format(_selectedDate!)
                              : 'Select date',
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Amount and currency
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _amountController,
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            enabled: !receipt.isInReport,
                            validator: (value) {
                              if (value?.isEmpty == true) return 'Enter amount';
                              if (double.tryParse(value!) == null) return 'Invalid number';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCurrency,
                            decoration: const InputDecoration(
                              labelText: 'Currency',
                            ),
                            items: MockData.currencies
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ))
                                .toList(),
                            onChanged: receipt.isInReport
                                ? null
                                : (value) => setState(() => _selectedCurrency = value),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: MockData.categories
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ))
                          .toList(),
                      onChanged: receipt.isInReport
                          ? null
                          : (value) => setState(() => _selectedCategory = value),
                    ),

                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        prefixIcon: Icon(Icons.notes),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      enabled: !receipt.isInReport,
                    ),

                    const SizedBox(height: 32),

                    // Save button
                    if (!receipt.isInReport)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveReceipt,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Save & Confirm'),
                      ),

                    if (receipt.isInReport)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This receipt is part of a report and cannot be edited.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildImage(Receipt receipt) {
    if (receipt.imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: receipt.imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (_, __, ___) => const Center(
          child: Icon(Icons.error),
        ),
      );
    } else {
      return Image.file(
        File(receipt.imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.receipt, size: 48),
        ),
      );
    }
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: imageUrl.startsWith('http')
          ? PhotoView(
              imageProvider: CachedNetworkImageProvider(imageUrl),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
            )
          : PhotoView(
              imageProvider: FileImage(File(imageUrl)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
            ),
    );
  }
}
