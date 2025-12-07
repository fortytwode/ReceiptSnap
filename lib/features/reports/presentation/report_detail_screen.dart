import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common/models/models.dart';
import '../../../common/services/services.dart';
import '../../../common/theme/app_theme.dart';
import '../../../common/widgets/widgets.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ready to finalize this expense report?',
            ),
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
                      Icon(Icons.download, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Export as CSV from Account tab')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.share, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Share with your manager via email')),
                    ],
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    final report = await ref
        .read(submitReportProvider.notifier)
        .submitReport(widget.reportId);

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

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportDetailProvider(widget.reportId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
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

          // Receipts section
          Text(
            'Receipts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          if (report.receipts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No receipts in this report',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            )
          else
            ...report.receipts.map((receipt) => _ReceiptTile(
                  receipt: receipt,
                  onTap: () => context.push('/receipt/${receipt.id}'),
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

  const _ReceiptTile({
    required this.receipt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

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
                  child: receipt.imageUrl.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: receipt.imageUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.receipt, size: 20),
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

              // Amount
              Text(
                receipt.formattedAmount,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
