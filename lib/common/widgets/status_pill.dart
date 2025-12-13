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

  /// Factory for OCR status
  /// isInDraftReport: receipt is in a draft report (not yet submitted)
  /// isInSubmittedReport: receipt is in a submitted/approved/rejected report
  factory StatusPill.ocrStatus(
    OcrStatus status, {
    bool isInReport = false,
    bool isInDraftReport = false,
    bool isInSubmittedReport = false,
  }) {
    // If in submitted report, show that prominently
    if (isInSubmittedReport) {
      return const StatusPill(
        label: 'Submitted',
        backgroundColor: AppColors.submitted,
      );
    }

    // If in draft report, show that
    if (isInDraftReport || isInReport) {
      return const StatusPill(
        label: 'In Draft',
        backgroundColor: AppColors.inReport,
      );
    }

    switch (status) {
      case OcrStatus.pendingOcr:
        return const StatusPill(
          label: 'Processing',
          backgroundColor: AppColors.pendingOcr,
        );
      case OcrStatus.needsConfirmation:
        return const StatusPill(
          label: 'Needs Review',
          backgroundColor: AppColors.needsConfirmation,
        );
      case OcrStatus.confirmed:
        return const StatusPill(
          label: 'Confirmed',
          backgroundColor: AppColors.confirmed,
        );
    }
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
