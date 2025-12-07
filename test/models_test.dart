import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_snap/common/models/models.dart';

void main() {
  group('Receipt Model', () {
    test('fromJson creates Receipt correctly', () {
      final json = {
        'id': 'receipt-001',
        'imageUrl': 'https://example.com/image.jpg',
        'merchant': 'Starbucks',
        'date': '2024-12-01T10:00:00.000Z',
        'amount': 12.50,
        'currency': 'USD',
        'category': 'Food & Drink',
        'note': 'Morning coffee',
        'ocrStatus': 'confirmed',
        'reportId': null,
        'createdAt': '2024-12-01T10:00:00.000Z',
      };

      final receipt = Receipt.fromJson(json);

      expect(receipt.id, 'receipt-001');
      expect(receipt.merchant, 'Starbucks');
      expect(receipt.amount, 12.50);
      expect(receipt.currency, 'USD');
      expect(receipt.ocrStatus, OcrStatus.confirmed);
      expect(receipt.isInReport, false);
    });

    test('toJson serializes Receipt correctly', () {
      final receipt = Receipt(
        id: 'receipt-001',
        imageUrl: 'https://example.com/image.jpg',
        merchant: 'Starbucks',
        date: DateTime.parse('2024-12-01T10:00:00.000Z'),
        amount: 12.50,
        currency: 'USD',
        ocrStatus: OcrStatus.confirmed,
        createdAt: DateTime.parse('2024-12-01T10:00:00.000Z'),
      );

      final json = receipt.toJson();

      expect(json['id'], 'receipt-001');
      expect(json['merchant'], 'Starbucks');
      expect(json['amount'], 12.50);
      expect(json['ocrStatus'], 'confirmed');
    });

    test('formattedAmount returns correct format', () {
      final receipt = Receipt(
        id: '1',
        imageUrl: 'url',
        amount: 42.50,
        currency: 'USD',
        ocrStatus: OcrStatus.confirmed,
        createdAt: DateTime.now(),
      );

      expect(receipt.formattedAmount, '\$42.50');
    });

    test('formattedAmount returns dash when amount is null', () {
      final receipt = Receipt(
        id: '1',
        imageUrl: 'url',
        ocrStatus: OcrStatus.pendingOcr,
        createdAt: DateTime.now(),
      );

      expect(receipt.formattedAmount, '-');
    });
  });

  group('Report Model', () {
    test('fromJson creates Report correctly', () {
      final json = {
        'id': 'report-001',
        'title': 'November Report',
        'status': 'draft',
        'receipts': [],
        'totalAmount': 100.50,
        'currency': 'USD',
        'createdAt': '2024-12-01T10:00:00.000Z',
      };

      final report = Report.fromJson(json);

      expect(report.id, 'report-001');
      expect(report.title, 'November Report');
      expect(report.status, ReportStatus.draft);
      expect(report.totalAmount, 100.50);
    });

    test('formattedTotal returns correct format', () {
      final report = Report(
        id: '1',
        title: 'Test Report',
        status: ReportStatus.draft,
        receipts: [],
        totalAmount: 150.75,
        currency: 'EUR',
        createdAt: DateTime.now(),
      );

      expect(report.formattedTotal, '\u20AC150.75');
    });
  });

  group('User Model', () {
    test('fromJson creates User correctly', () {
      final json = {
        'id': 'user-001',
        'name': 'John Doe',
        'email': 'john@example.com',
        'defaultCurrency': 'GBP',
      };

      final user = User.fromJson(json);

      expect(user.id, 'user-001');
      expect(user.name, 'John Doe');
      expect(user.email, 'john@example.com');
      expect(user.defaultCurrency, 'GBP');
    });

    test('copyWith creates new User with updated fields', () {
      final user = const User(
        id: 'user-001',
        name: 'John',
        defaultCurrency: 'USD',
      );

      final updated = user.copyWith(name: 'Jane', defaultCurrency: 'EUR');

      expect(updated.id, 'user-001');
      expect(updated.name, 'Jane');
      expect(updated.defaultCurrency, 'EUR');
    });
  });

  group('OcrStatus Enum', () {
    test('fromString parses correctly', () {
      expect(OcrStatus.fromString('pending_ocr'), OcrStatus.pendingOcr);
      expect(OcrStatus.fromString('needs_confirmation'), OcrStatus.needsConfirmation);
      expect(OcrStatus.fromString('confirmed'), OcrStatus.confirmed);
      expect(OcrStatus.fromString('invalid'), OcrStatus.pendingOcr);
    });

    test('toJson returns correct string', () {
      expect(OcrStatus.pendingOcr.toJson(), 'pending_ocr');
      expect(OcrStatus.needsConfirmation.toJson(), 'needs_confirmation');
      expect(OcrStatus.confirmed.toJson(), 'confirmed');
    });
  });

  group('ReportStatus Enum', () {
    test('fromString parses correctly', () {
      expect(ReportStatus.fromString('draft'), ReportStatus.draft);
      expect(ReportStatus.fromString('submitted'), ReportStatus.submitted);
      expect(ReportStatus.fromString('approved'), ReportStatus.approved);
      expect(ReportStatus.fromString('rejected'), ReportStatus.rejected);
    });
  });
}
