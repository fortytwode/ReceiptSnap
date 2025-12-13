import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'export_service.dart';

/// Result of Firebase email sending
enum FirebaseEmailResult {
  success,
  notConfigured,
  failed,
}

/// Service for sending emails via Firebase Cloud Functions
class FirebaseEmailService {
  final ExportService _exportService;

  FirebaseEmailService(this._exportService);

  /// Send expense report via Firebase Cloud Function
  /// Returns the result of the email sending attempt
  Future<FirebaseEmailResult> sendReport({
    required Report report,
    required String recipientEmail,
  }) async {
    try {
      final dateFormat = DateFormat('MMM d, yyyy');

      // Build email body
      final body = StringBuffer();
      body.writeln('Expense Report: ${report.title}');
      body.writeln('');
      body.writeln('Summary:');
      body.writeln('• Total: ${report.formattedTotal}');
      body.writeln('• Receipts: ${report.receiptCount}');
      if (report.startDate != null && report.endDate != null) {
        body.writeln(
            '• Period: ${dateFormat.format(report.startDate!)} - ${dateFormat.format(report.endDate!)}');
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

      // Export CSV
      final csv = await _exportService.exportReportDetailToCsv(report.id);
      final csvBase64 = base64Encode(utf8.encode(csv));

      // Call Cloud Function
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendExpenseReport');

      final result = await callable.call({
        'recipientEmail': recipientEmail,
        'reportTitle': report.title,
        'bodyText': body.toString(),
        'csvBase64': csvBase64,
        'csvFilename': 'expense_report_${report.id.substring(0, 8)}.csv',
      });

      debugPrint('Firebase email result: ${result.data}');
      return FirebaseEmailResult.success;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Firebase Functions error: ${e.code} - ${e.message}');

      if (e.code == 'failed-precondition') {
        // SendGrid not configured
        return FirebaseEmailResult.notConfigured;
      }

      return FirebaseEmailResult.failed;
    } catch (e) {
      debugPrint('Error sending email via Firebase: $e');
      return FirebaseEmailResult.failed;
    }
  }
}

/// Provider for FirebaseEmailService
final firebaseEmailServiceProvider = Provider<FirebaseEmailService>((ref) {
  final exportService = ref.watch(exportServiceProvider);
  return FirebaseEmailService(exportService);
});
