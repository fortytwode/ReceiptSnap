import 'package:cached_network_image/cached_network_image.dart';
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

class CreateReportScreen extends ConsumerStatefulWidget {
  const CreateReportScreen({super.key});

  @override
  ConsumerState<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends ConsumerState<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _approverEmailController;
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final monthName = DateFormat.MMMM().format(now);
    _titleController = TextEditingController(text: '$monthName ${now.year} Report');
    _approverEmailController = TextEditingController();

    // Reset create report state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(createReportProvider.notifier).reset();
      ref.read(createReportProvider.notifier).setTitle(_titleController.text);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _approverEmailController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _startDate = date);
      ref.read(createReportProvider.notifier).setDateRange(_startDate, _endDate);
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date != null) {
      setState(() => _endDate = date);
      ref.read(createReportProvider.notifier).setDateRange(_startDate, _endDate);
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKey.currentState?.validate() != true) return;
      ref.read(createReportProvider.notifier).setTitle(_titleController.text);
      ref.read(createReportProvider.notifier).setApproverEmail(
          _approverEmailController.text.isEmpty ? null : _approverEmailController.text);
    }
    setState(() => _currentStep++);
  }

  void _prevStep() {
    setState(() => _currentStep--);
  }

  Future<void> _createReport() async {
    final report = await ref.read(createReportProvider.notifier).createReport();

    if (report != null && mounted) {
      // Refresh reports list
      ref.read(reportsProvider.notifier).refresh();
      // Refresh receipts list (receipts now have reportId)
      ref.read(receiptsProvider.notifier).refresh();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report created successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
      context.push('/report/${report.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createReportProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Report'),
      ),
      body: LoadingOverlay(
        isLoading: createState.isCreating,
        message: 'Creating report...',
        child: Column(
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / 2,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),

            // Step content
            Expanded(
              child: _currentStep == 0 ? _buildDetailsStep(theme) : _buildReceiptsStep(theme),
            ),

            // Error message
            if (createState.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppColors.error.withOpacity(0.1),
                child: Text(
                  createState.error!,
                  style: TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _prevStep,
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentStep == 0 ? _nextStep : _createReport,
                      child: Text(_currentStep == 0 ? 'Next' : 'Create Report'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the basic information for your expense report.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Report Title',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) =>
                  value?.trim().isEmpty == true ? 'Please enter a title' : null,
            ),

            const SizedBox(height: 16),

            // Date range
            Text(
              'Date Range (Optional)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _startDate != null
                            ? DateFormat.yMMMd().format(_startDate!)
                            : 'Select',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectEndDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _endDate != null
                            ? DateFormat.yMMMd().format(_endDate!)
                            : 'Select',
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Approver email
            TextFormField(
              controller: _approverEmailController,
              decoration: const InputDecoration(
                labelText: 'Approver Email (Optional)',
                prefixIcon: Icon(Icons.email),
                hintText: 'manager@company.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptsStep(ThemeData theme) {
    final availableReceipts = ref.watch(availableReceiptsProvider);
    final createState = ref.watch(createReportProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Receipts',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the receipts to include in this report.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),

        // Selected count
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.receipt,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                '${createState.selectedReceiptIds.length} receipt(s) selected',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Receipts list
        Expanded(
          child: availableReceipts.when(
            loading: () => const LoadingWidget(message: 'Loading receipts...'),
            error: (error, _) => ErrorDisplay(
              message: error.toString(),
              onRetry: () => ref.refresh(availableReceiptsProvider),
            ),
            data: (receipts) {
              if (receipts.isEmpty) {
                return EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No receipts available',
                  subtitle: 'Confirm some receipts first to add them to a report.',
                );
              }

              return Column(
                children: [
                  // Select all button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            final allIds = receipts.map((r) => r.id).toList();
                            ref.read(createReportProvider.notifier).selectAllReceipts(allIds);
                          },
                          icon: const Icon(Icons.select_all),
                          label: const Text('Select All'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            ref.read(createReportProvider.notifier).clearSelection();
                          },
                          icon: const Icon(Icons.deselect),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: receipts.length,
                      itemBuilder: (context, index) {
                        final receipt = receipts[index];
                        final isSelected =
                            createState.selectedReceiptIds.contains(receipt.id);
                        return _ReceiptCheckboxTile(
                          receipt: receipt,
                          isSelected: isSelected,
                          onToggle: () {
                            ref.read(createReportProvider.notifier).toggleReceipt(receipt.id);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReceiptCheckboxTile extends StatelessWidget {
  final Receipt receipt;
  final bool isSelected;
  final VoidCallback onToggle;

  const _ReceiptCheckboxTile({
    required this.receipt,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(),
              ),

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            ],
          ),
        ),
      ),
    );
  }
}
