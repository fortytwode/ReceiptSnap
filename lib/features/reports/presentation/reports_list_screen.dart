import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common/models/models.dart';
import '../../../common/services/router_service.dart';
import '../../../common/widgets/widgets.dart';
import '../providers/reports_provider.dart';

class ReportsListScreen extends ConsumerStatefulWidget {
  const ReportsListScreen({super.key});

  @override
  ConsumerState<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends ConsumerState<ReportsListScreen> {
  String? _selectedStatus;

  final List<Map<String, String>> _statusFilters = [
    {'value': '', 'label': 'All'},
    {'value': 'draft', 'label': 'Draft'},
    {'value': 'submitted', 'label': 'Submitted'},
  ];

  void _onStatusFilter(String status) {
    setState(() {
      _selectedStatus = status.isEmpty ? null : status;
    });
    ref.read(reportsProvider.notifier).setStatusFilter(_selectedStatus);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push(AppRoutes.createReport),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _statusFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _statusFilters[index];
                  final isSelected = (_selectedStatus ?? '') == filter['value'];
                  return FilterChip(
                    label: Text(filter['label']!),
                    selected: isSelected,
                    onSelected: (_) => _onStatusFilter(filter['value']!),
                  );
                },
              ),
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(state, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ReportsState state, ThemeData theme) {
    if (state.isLoading && state.reports.isEmpty) {
      return const LoadingWidget(message: 'Loading reports...');
    }

    if (state.error != null && state.reports.isEmpty) {
      return ErrorDisplay(
        message: state.error!,
        onRetry: () => ref.read(reportsProvider.notifier).refresh(),
      );
    }

    if (state.reports.isEmpty) {
      return EmptyState(
        icon: Icons.folder_outlined,
        title: "You haven't created any reports yet",
        subtitle: 'Create a report to group your receipts',
        actionLabel: 'Create Report',
        onAction: () => context.push(AppRoutes.createReport),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(reportsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.reports.length,
        itemBuilder: (context, index) {
          final report = state.reports[index];
          return _ReportCard(report: report);
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Report report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/report/${report.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              // Footer row
              Row(
                children: [
                  // Receipt count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt,
                          size: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${report.receiptCount} receipts',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Total amount
                  Text(
                    report.formattedTotal,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
}
