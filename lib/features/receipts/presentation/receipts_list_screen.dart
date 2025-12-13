import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common/models/models.dart';
import '../../../common/services/router_service.dart';
import '../../../common/widgets/widgets.dart';
import '../providers/receipts_provider.dart';

class ReceiptsListScreen extends ConsumerStatefulWidget {
  const ReceiptsListScreen({super.key});

  @override
  ConsumerState<ReceiptsListScreen> createState() => _ReceiptsListScreenState();
}

class _ReceiptsListScreenState extends ConsumerState<ReceiptsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;

  final List<Map<String, String>> _statusFilters = [
    {'value': '', 'label': 'All'},
    {'value': 'draft', 'label': 'Draft'},
    {'value': 'in_report', 'label': 'In Report'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    ref.read(receiptsProvider.notifier).setSearchQuery(query.isEmpty ? null : query);
  }

  void _onStatusFilter(String status) {
    setState(() {
      _selectedStatus = status.isEmpty ? null : status;
    });
    ref.read(receiptsProvider.notifier).setStatusFilter(_selectedStatus);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receiptsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search receipts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearch,
            ),
          ),

          // Filter chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _buildContent(state, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ReceiptsState state, ThemeData theme) {
    if (state.isLoading && state.receipts.isEmpty) {
      return const LoadingWidget(message: 'Loading receipts...');
    }

    if (state.error != null && state.receipts.isEmpty) {
      return ErrorDisplay(
        message: state.error!,
        onRetry: () => ref.read(receiptsProvider.notifier).refresh(),
      );
    }

    if (state.receipts.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No receipts yet',
        subtitle: 'Scan your first receipt to get started',
        actionLabel: 'Scan Receipt',
        onAction: () => context.push(AppRoutes.capture),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(receiptsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.receipts.length,
        itemBuilder: (context, index) {
          final receipt = state.receipts[index];
          return _ReceiptCard(receipt: receipt);
        },
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Receipt receipt;

  const _ReceiptCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/receipt/${receipt.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 80,
                  child: receipt.imageUrl.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: receipt.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.receipt, size: 32),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.receipt, size: 32),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.receipt, size: 32),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Merchant
                    Text(
                      receipt.merchant ?? 'Unknown merchant',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Date
                    Text(
                      receipt.date != null
                          ? dateFormat.format(receipt.date!)
                          : 'Date unknown',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Status pill - receipts shown here are either not in a report
                    // or in a draft report (submitted report receipts are filtered out)
                    StatusPill.ocrStatus(
                      receipt.ocrStatus,
                      isInDraftReport: receipt.isInReport,
                    ),
                  ],
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    receipt.formattedAmount,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (receipt.category != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      receipt.category!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
