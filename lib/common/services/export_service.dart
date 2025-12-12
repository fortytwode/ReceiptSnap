import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import 'database_service.dart';

/// Result of email sending attempt
enum EmailSendResult {
  success,
  fallbackUsed,
  failed,
}

/// Service for exporting data to CSV
class ExportService {
  final DatabaseService _db;

  ExportService(this._db);

  /// Export all receipts to CSV
  Future<String> exportReceiptsToCsv() async {
    final receipts = await _db.getReceipts();
    final dateFormat = DateFormat('yyyy-MM-dd');

    final buffer = StringBuffer();

    // Header row
    buffer.writeln('ID,Merchant,Date,Amount,Currency,Category,Note,Status,Report ID,Created At');

    // Data rows
    for (final receipt in receipts) {
      buffer.writeln([
        _escapeCsv(receipt.id),
        _escapeCsv(receipt.merchant ?? ''),
        receipt.date != null ? dateFormat.format(receipt.date!) : '',
        receipt.amount?.toString() ?? '',
        _escapeCsv(receipt.currency ?? ''),
        _escapeCsv(receipt.category ?? ''),
        _escapeCsv(receipt.note ?? ''),
        receipt.ocrStatus.displayName,
        _escapeCsv(receipt.reportId ?? ''),
        dateFormat.format(receipt.createdAt),
      ].join(','));
    }

    return buffer.toString();
  }

  /// Export all reports to CSV
  Future<String> exportReportsToCsv() async {
    final reports = await _db.getReports();
    final dateFormat = DateFormat('yyyy-MM-dd');

    final buffer = StringBuffer();

    // Header row
    buffer.writeln('ID,Title,Status,Total Amount,Currency,Receipt Count,Approver Email,Start Date,End Date,Created At');

    // Data rows
    for (final report in reports) {
      buffer.writeln([
        _escapeCsv(report.id),
        _escapeCsv(report.title),
        report.status.displayName,
        report.totalAmount.toStringAsFixed(2),
        _escapeCsv(report.currency),
        report.receiptCount.toString(),
        _escapeCsv(report.approverEmail ?? ''),
        report.startDate != null ? dateFormat.format(report.startDate!) : '',
        report.endDate != null ? dateFormat.format(report.endDate!) : '',
        dateFormat.format(report.createdAt),
      ].join(','));
    }

    return buffer.toString();
  }

  /// Export a single report with its receipts to CSV
  Future<String> exportReportDetailToCsv(String reportId) async {
    final report = await _db.getReport(reportId);
    if (report == null) throw Exception('Report not found');

    final dateFormat = DateFormat('yyyy-MM-dd');
    final buffer = StringBuffer();

    // Report header
    buffer.writeln('EXPENSE REPORT');
    buffer.writeln('Title,${_escapeCsv(report.title)}');
    buffer.writeln('Status,${report.status.displayName}');
    buffer.writeln('Total Amount,${report.formattedTotal}');
    buffer.writeln('Receipt Count,${report.receiptCount}');
    buffer.writeln('Approver,${_escapeCsv(report.approverEmail ?? 'N/A')}');
    buffer.writeln('Created,${dateFormat.format(report.createdAt)}');
    buffer.writeln('');

    // Receipts header
    buffer.writeln('RECEIPTS');
    buffer.writeln('Merchant,Date,Amount,Currency,Category,Note');

    // Receipt rows
    for (final receipt in report.receipts) {
      buffer.writeln([
        _escapeCsv(receipt.merchant ?? 'Unknown'),
        receipt.date != null ? dateFormat.format(receipt.date!) : '',
        receipt.amount?.toStringAsFixed(2) ?? '',
        _escapeCsv(receipt.currency ?? ''),
        _escapeCsv(receipt.category ?? ''),
        _escapeCsv(receipt.note ?? ''),
      ].join(','));
    }

    return buffer.toString();
  }

  /// Save CSV to file and return path
  Future<String> saveCsvToFile(String csv, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory.path}/${filename}_$timestamp.csv');
    await file.writeAsString(csv);
    return file.path;
  }

  /// Export and share via system share sheet
  Future<void> exportAndShare({
    required String csv,
    required String filename,
    String? subject,
  }) async {
    final path = await saveCsvToFile(csv, filename);
    await Share.shareXFiles(
      [XFile(path)],
      subject: subject ?? 'ReceiptSnap Export',
    );
  }

  /// Share a report via email with optional approver
  /// Uses flutter_email_sender to open native email composer with pre-filled recipient
  /// Falls back to share sheet if email app is not available
  Future<EmailSendResult> shareReportViaEmail({
    required Report report,
    String? recipientEmail,
  }) async {
    final dateFormat = DateFormat('MMM d, yyyy');

    // Build email body
    final body = StringBuffer();
    body.writeln('Expense Report: ${report.title}');
    body.writeln('');
    body.writeln('Summary:');
    body.writeln('• Total: ${report.formattedTotal}');
    body.writeln('• Receipts: ${report.receiptCount}');
    if (report.startDate != null && report.endDate != null) {
      body.writeln('• Period: ${dateFormat.format(report.startDate!)} - ${dateFormat.format(report.endDate!)}');
    }
    body.writeln('• Submitted: ${dateFormat.format(DateTime.now())}');
    body.writeln('');
    body.writeln('Receipt Details:');
    body.writeln('');

    for (int i = 0; i < report.receipts.length; i++) {
      final receipt = report.receipts[i];
      body.writeln('${i + 1}. ${receipt.merchant ?? "Unknown"}');
      body.writeln('   Amount: ${receipt.formattedAmount}');
      if (receipt.date != null) {
        body.writeln('   Date: ${dateFormat.format(receipt.date!)}');
      }
      if (receipt.category != null) {
        body.writeln('   Category: ${receipt.category}');
      }
      body.writeln('');
    }

    body.writeln('---');
    body.writeln('Sent from ReceiptSnap');

    // Export CSV attachment
    final csv = await exportReportDetailToCsv(report.id);
    final csvPath = await saveCsvToFile(csv, 'expense_report_${report.id.substring(0, 8)}');

    final subject = 'Expense Report: ${report.title}';

    // Try flutter_email_sender first (opens native email app with pre-filled recipient)
    try {
      final email = Email(
        body: body.toString(),
        subject: subject,
        recipients: recipientEmail != null ? [recipientEmail] : [],
        attachmentPaths: [csvPath],
        isHTML: false,
      );

      await FlutterEmailSender.send(email);
      return EmailSendResult.success;
    } catch (e) {
      // Email app not available or not configured - fall back to share sheet
      // This happens when iOS Mail app is not set up, or no email apps installed
      try {
        await Share.shareXFiles(
          [XFile(csvPath)],
          subject: subject,
          text: body.toString(),
        );
        return EmailSendResult.fallbackUsed;
      } catch (shareError) {
        // Both methods failed
        rethrow;
      }
    }
  }

  /// Escape CSV special characters
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

/// Provider for ExportService
final exportServiceProvider = Provider<ExportService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return ExportService(db);
});
