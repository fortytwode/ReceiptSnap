import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Status pill widget for displaying receipt or report status
class StatusPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const StatusPill({
    super.key,
    required this.label,
    required this.backgroundColor,
    this.textColor = Colors.white,
  });

  /// Factory for receipt status
  /// Simplified to show: Draft, In Report, or Submitted
  factory StatusPill.receiptStatus({
    required bool isInReport,
    required bool isSubmitted,
    bool isProcessing = false,
  }) {
    if (isSubmitted) {
      return const StatusPill(
        label: 'Submitted',
        backgroundColor: AppColors.submitted,
      );
    }

    if (isInReport) {
      return const StatusPill(
        label: 'In Report',
        backgroundColor: AppColors.inReport,
      );
    }

    if (isProcessing) {
      return const StatusPill(
        label: 'Processing',
        backgroundColor: AppColors.pendingOcr,
      );
    }

    return const StatusPill(
      label: 'Draft',
      backgroundColor: AppColors.draft,
    );
  }

  /// Legacy factory for OCR status - kept for backwards compatibility
  factory StatusPill.ocrStatus(
    OcrStatus status, {
    bool isInReport = false,
    bool isInDraftReport = false,
    bool isInSubmittedReport = false,
  }) {
    return StatusPill.receiptStatus(
      isInReport: isInDraftReport || isInReport,
      isSubmitted: isInSubmittedReport,
      isProcessing: status == OcrStatus.pendingOcr,
    );
  }

  /// Factory for report status
  factory StatusPill.reportStatus(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return const StatusPill(
          label: 'Draft',
          backgroundColor: AppColors.draft,
        );
      case ReportStatus.submitted:
        return const StatusPill(
          label: 'Submitted',
          backgroundColor: AppColors.submitted,
        );
      case ReportStatus.approved:
        return const StatusPill(
          label: 'Approved',
          backgroundColor: AppColors.approved,
        );
      case ReportStatus.rejected:
        return const StatusPill(
          label: 'Rejected',
          backgroundColor: AppColors.rejected,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
