import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common/models/models.dart';
import '../../../common/services/services.dart';
import '../../../common/theme/app_theme.dart';
import '../../../common/widgets/widgets.dart';
import '../../receipts/providers/receipts_provider.dart';
import '../providers/reports_provider.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  final String reportId;

  const ReportDetailScreen({
    super.key,
    required this.reportId,
  });

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    // Get the default recipient email and currency from storage
    final storage = ref.read(storageServiceProvider);
    final defaultEmail = storage.defaultRecipientEmail;
    final defaultCurrency = storage.defaultCurrency;

    // Show the appropriate dialog based on whether we have a default email
    Map<String, String>? result;
    if (defaultEmail != null && defaultEmail.isNotEmpty) {
      // Show dialog with option to use default or change
      result = await _showDefaultEmailDialog(defaultEmail, defaultCurrency);
    } else {
      // Show dialog to enter email for the first time
      result = await _showFirstTimeEmailDialog(defaultCurrency);
    }

    // User cancelled
    if (result == null) return;

    final recipientEmail = result['email']!;
    final reportCurrency = result['currency']!;

    // Save email as default if it's new or changed
    if (recipientEmail != defaultEmail) {
      await storage.setDefaultRecipientEmail(recipientEmail);
    }

    setState(() => _isSubmitting = true);

    final report = await ref
        .read(submitReportProvider.notifier)
        .submitReport(widget.reportId, currency: reportCurrency);

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (report != null) {
      // Refresh reports list
      ref.read(reportsProvider.notifier).refresh();
      // Refresh this report detail
      ref.refresh(reportDetailProvider(widget.reportId));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      // Send email via Firebase (automatic) or fall back to local email composer
      if (mounted) {
        try {
          // Try Firebase email first (sends automatically without user interaction)
          final firebaseEmailService = ref.read(firebaseEmailServiceProvider);
          final firebaseResult = await firebaseEmailService.sendReport(
            report: report,
            recipientEmail: recipientEmail,
          );

          if (firebaseResult == FirebaseEmailResult.success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Report sent to $recipientEmail'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            // Firebase not configured or failed - fall back to local email composer
            debugPrint('Firebase email not available, using local email composer');
            final exportService = ref.read(exportServiceProvider);
            final emailResult = await exportService.shareReportViaEmail(
              report: report,
              recipientEmail: recipientEmail,
            );

            // Show feedback if fallback was used
            if (emailResult == EmailSendResult.fallbackUsed && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email app not configured. Share sheet opened instead.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          // Sharing is optional, don't show error if user cancels
          debugPrint('Share cancelled or failed: $e');
        }
      }
    } else {
      final error = ref.read(submitReportProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to submit report'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<Map<String, String>?> _showFirstTimeEmailDialog(String defaultCurrency) async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedCurrency = defaultCurrency;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Submit Report'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the email address of the person who should receive this report:',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Recipient Email',
                      hintText: 'manager@company.com',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an email address';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Report Currency',
                      prefixIcon: Icon(Icons.attach_money),
                      helperText: 'All amounts will be converted to this currency',
                    ),
                    items: MockData.currencies
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedCurrency = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This email will be saved as your default recipient for future reports.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Once submitted, you won\'t be able to edit this report.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, {
                    'email': emailController.text.trim(),
                    'currency': selectedCurrency,
                  });
                }
              },
              child: const Text('Submit & Share'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, String>?> _showDefaultEmailDialog(String defaultEmail, String defaultCurrency) async {
    final emailController = TextEditingController(text: defaultEmail);
    final formKey = GlobalKey<FormState>();
    bool useDefault = true;
    String selectedCurrency = defaultCurrency;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Submit Report'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ready to finalize this expense report?'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.email, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Send to: $defaultEmail',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      setDialogState(() {
                        useDefault = !useDefault;
                        if (useDefault) {
                          emailController.text = defaultEmail;
                        }
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          useDefault ? Icons.radio_button_off : Icons.radio_button_checked,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('Send to a different email'),
                      ],
                    ),
                  ),
                  if (!useDefault) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Recipient Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an email address';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Report Currency',
                      prefixIcon: Icon(Icons.attach_money),
                      helperText: 'All amounts will be converted to this currency',
                    ),
                    items: MockData.currencies
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedCurrency = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Once submitted, you won\'t be able to edit this report.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (useDefault || formKey.currentState!.validate()) {
                  Navigator.pop(context, {
                    'email': emailController.text.trim(),
                    'currency': selectedCurrency,
                  });
                }
              },
              child: const Text('Submit & Share'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareReport(Report report) async {
    try {
      final exportService = ref.read(exportServiceProvider);
      final result = await exportService.shareReportViaEmail(report: report);

      if (result == EmailSendResult.fallbackUsed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email app not configured. Share sheet opened instead.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Share failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Show options to add a receipt to this report
  void _showAddReceiptOptions(String reportId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add Receipt',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              subtitle: const Text('Capture with camera'),
              onTap: () {
                Navigator.pop(ctx);
                // Navigate to capture and pass reportId for auto-add
                context.push('/capture?reportId=$reportId');
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select existing photo'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/capture?reportId=$reportId');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Manual Entry'),
              subtitle: const Text('For cash expenses without a receipt'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/manual-entry?reportId=$reportId');
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Add Existing Receipt'),
              subtitle: const Text('Select from confirmed receipts'),
              onTap: () {
                Navigator.pop(ctx);
                _showSelectReceiptDialog(reportId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Show dialog to select existing confirmed receipts
  Future<void> _showSelectReceiptDialog(String reportId) async {
    final receiptsService = ref.read(receiptsServiceProvider);
    final availableReceipts = await receiptsService.getAvailableForReport();

    if (!mounted) return;

    if (availableReceipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No confirmed receipts available to add'),
        ),
      );
      return;
    }

    final selectedIds = await showDialog<List<String>>(
      context: context,
      builder: (context) => _SelectReceiptsDialog(receipts: availableReceipts),
    );

    if (selectedIds == null || selectedIds.isEmpty || !mounted) return;

    // Add selected receipts to report
    final reportsService = ref.read(reportsServiceProvider);
    for (final id in selectedIds) {
      await reportsService.addReceiptToReport(reportId, id);
    }

    ref.invalidate(reportDetailProvider(widget.reportId));
    ref.read(receiptsProvider.notifier).refresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${selectedIds.length} receipt(s) to report'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportDetailProvider(widget.reportId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        actions: [
          // Show share button for submitted/approved reports
          reportAsync.whenOrNull(
            data: (report) => report.status != ReportStatus.draft
                ? IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Share Report',
                    onPressed: () => _shareReport(report),
                  )
                : null,
          ),
        ].whereType<Widget>().toList(),
      ),
      body: reportAsync.when(
        loading: () => const LoadingWidget(message: 'Loading report...'),
        error: (error, _) => ErrorDisplay(
          message: error.toString(),
          onRetry: () => ref.refresh(reportDetailProvider(widget.reportId)),
        ),
        data: (report) => LoadingOverlay(
          isLoading: _isSubmitting,
          message: 'Submitting report...',
          child: _buildReportContent(report, theme),
        ),
      ),
    );
  }

  Widget _buildReportContent(Report report, ThemeData theme) {
    final dateFormat = DateFormat.yMMMd();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      StatusPill.reportStatus(report.status),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Date range
                  if (report.startDate != null || report.endDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateRange(report, dateFormat),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),

                  if (report.approverEmail != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Approver: ${report.approverEmail}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],

                  const Divider(height: 24),

                  // Totals
                  _buildTotalsSection(report, theme),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Receipts section header with Add button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Receipts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (report.status == ReportStatus.draft)
                TextButton.icon(
                  onPressed: () => _showAddReceiptOptions(report.id),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (report.receipts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No receipts in this report',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    if (report.status == ReportStatus.draft) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddReceiptOptions(report.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Receipt'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ...report.receipts.map((receipt) => _ReceiptTile(
                  receipt: receipt,
                  onTap: () => context.push('/receipt/${receipt.id}'),
                  reportCurrency: report.currency,
                  currencyService: ref.read(currencyServiceProvider),
                )),

          const SizedBox(height: 24),

          // Comment section
          if (report.comment != null && report.comment!.isNotEmpty) ...[
            Text(
              'Comment',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(report.comment!),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Status-specific content
          if (report.status == ReportStatus.rejected) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report Rejected',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please review the feedback and resubmit.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (report.status == ReportStatus.approved) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This report has been approved!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Submit button (for draft only)
          if (report.status == ReportStatus.draft)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Submit Report'),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatDateRange(Report report, DateFormat format) {
    if (report.startDate != null && report.endDate != null) {
      return '${format.format(report.startDate!)} - ${format.format(report.endDate!)}';
    } else if (report.startDate != null) {
      return 'From ${format.format(report.startDate!)}';
    } else if (report.endDate != null) {
      return 'Until ${format.format(report.endDate!)}';
    }
    return '';
  }

  Widget _buildTotalsSection(Report report, ThemeData theme) {
    final currencyService = ref.read(currencyServiceProvider);
    final storage = ref.read(storageServiceProvider);
    final baseCurrency = storage.defaultCurrency;
    final hasMultipleCurrencies = report.totalsByCurrency.length > 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                report.formattedTotal,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Show converted total if multiple currencies
              if (hasMultipleCurrencies) ...[
                const SizedBox(height: 4),
                Text(
                  report.formattedTotalBreakdown,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Approx. ${currencyService.formatConvertedTotal(report.totalsByCurrency, baseCurrency)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Receipts',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              '${report.receiptCount}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  final Receipt receipt;
  final VoidCallback onTap;
  final String reportCurrency;
  final CurrencyService currencyService;

  const _ReceiptTile({
    required this.receipt,
    required this.onTap,
    required this.reportCurrency,
    required this.currencyService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

    // Check if receipt currency differs from report currency
    final receiptCurrency = receipt.currency ?? 'USD';
    final needsConversion = receiptCurrency != reportCurrency && receipt.amount != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 40,
                  height: 50,
                  child: receipt.imageUrl.isNotEmpty && receipt.imageUrl.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: receipt.imageUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            receipt.imageUrl.isEmpty ? Icons.edit_note : Icons.receipt,
                            size: 20,
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.merchant ?? 'Unknown merchant',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      receipt.date != null
                          ? dateFormat.format(receipt.date!)
                          : 'Date unknown',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Amount with optional conversion
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    receipt.formattedAmount,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (needsConversion) ...[
                    const SizedBox(height: 2),
                    Text(
                      currencyService.formatConversion(
                        amount: receipt.amount!,
                        from: receiptCurrency,
                        to: reportCurrency,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for selecting existing receipts to add to a report
class _SelectReceiptsDialog extends StatefulWidget {
  final List<Receipt> receipts;

  const _SelectReceiptsDialog({required this.receipts});

  @override
  State<_SelectReceiptsDialog> createState() => _SelectReceiptsDialogState();
}

class _SelectReceiptsDialogState extends State<_SelectReceiptsDialog> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

    return AlertDialog(
      title: const Text('Select Receipts'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.receipts.length,
          itemBuilder: (context, index) {
            final receipt = widget.receipts[index];
            final isSelected = _selectedIds.contains(receipt.id);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.add(receipt.id);
                  } else {
                    _selectedIds.remove(receipt.id);
                  }
                });
              },
              title: Text(receipt.merchant ?? 'Unknown'),
              subtitle: Text(
                '${receipt.formattedAmount} • ${receipt.date != null ? dateFormat.format(receipt.date!) : "No date"}',
              ),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: receipt.imageUrl.isNotEmpty && receipt.imageUrl.startsWith('http')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: receipt.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        receipt.imageUrl.isEmpty ? Icons.edit_note : Icons.receipt,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedIds.toList()),
          child: Text('Add ${_selectedIds.length} Receipt${_selectedIds.length != 1 ? 's' : ''}'),
        ),
      ],
    );
  }
}
