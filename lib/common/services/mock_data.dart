import '../models/models.dart';

/// Mock data for development and testing
class MockData {
  static const String mockUserId = 'mock-user-001';
  static const String mockToken = 'mock-token-xyz';

  static User get mockUser => const User(
        id: mockUserId,
        name: 'Demo User',
        email: 'demo@receiptsnap.test',
        defaultCurrency: 'USD',
      );

  static List<Receipt> get mockReceipts => [
        Receipt(
          id: 'receipt-001',
          imageUrl: 'https://picsum.photos/seed/r1/400/600',
          merchant: 'Starbucks',
          date: DateTime.now().subtract(const Duration(days: 1)),
          amount: 12.50,
          currency: 'USD',
          category: 'Food & Drink',
          note: 'Morning coffee',
          ocrStatus: OcrStatus.confirmed,
          reportId: null,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        Receipt(
          id: 'receipt-002',
          imageUrl: 'https://picsum.photos/seed/r2/400/600',
          merchant: 'Uber',
          date: DateTime.now().subtract(const Duration(days: 2)),
          amount: 24.80,
          currency: 'USD',
          category: 'Transportation',
          note: 'Client meeting',
          ocrStatus: OcrStatus.confirmed,
          reportId: null,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        Receipt(
          id: 'receipt-003',
          imageUrl: 'https://picsum.photos/seed/r3/400/600',
          merchant: 'Office Depot',
          date: DateTime.now().subtract(const Duration(days: 3)),
          amount: 89.99,
          currency: 'USD',
          category: 'Office Supplies',
          note: 'Printer paper and pens',
          ocrStatus: OcrStatus.needsConfirmation,
          reportId: null,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        Receipt(
          id: 'receipt-004',
          imageUrl: 'https://picsum.photos/seed/r4/400/600',
          merchant: null,
          date: null,
          amount: null,
          currency: null,
          category: null,
          note: null,
          ocrStatus: OcrStatus.pendingOcr,
          reportId: null,
          createdAt: DateTime.now(),
        ),
        Receipt(
          id: 'receipt-005',
          imageUrl: 'https://picsum.photos/seed/r5/400/600',
          merchant: 'Hilton Hotels',
          date: DateTime.now().subtract(const Duration(days: 10)),
          amount: 245.00,
          currency: 'USD',
          category: 'Lodging',
          note: 'Conference stay',
          ocrStatus: OcrStatus.confirmed,
          reportId: 'report-001',
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
        Receipt(
          id: 'receipt-006',
          imageUrl: 'https://picsum.photos/seed/r6/400/600',
          merchant: 'Delta Airlines',
          date: DateTime.now().subtract(const Duration(days: 12)),
          amount: 450.00,
          currency: 'USD',
          category: 'Travel',
          note: 'Flight to NYC',
          ocrStatus: OcrStatus.confirmed,
          reportId: 'report-001',
          createdAt: DateTime.now().subtract(const Duration(days: 12)),
        ),
      ];

  static List<Report> get mockReports => [
        Report(
          id: 'report-001',
          title: 'November 2024 Business Trip',
          status: ReportStatus.submitted,
          receipts: mockReceipts.where((r) => r.reportId == 'report-001').toList(),
          totalAmount: 695.00,
          currency: 'USD',
          comment: 'NYC conference trip',
          approverEmail: 'manager@company.com',
          startDate: DateTime.now().subtract(const Duration(days: 15)),
          endDate: DateTime.now().subtract(const Duration(days: 10)),
          createdAt: DateTime.now().subtract(const Duration(days: 8)),
        ),
        Report(
          id: 'report-002',
          title: 'December 2024 Report',
          status: ReportStatus.draft,
          receipts: [],
          totalAmount: 0.0,
          currency: 'USD',
          comment: null,
          approverEmail: null,
          startDate: DateTime.now().subtract(const Duration(days: 30)),
          endDate: DateTime.now(),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

  static List<String> get categories => [
        'Food & Drink',
        'Transportation',
        'Lodging',
        'Travel',
        'Office Supplies',
        'Entertainment',
        'Utilities',
        'Other',
      ];

  static List<String> get currencies => [
        'USD', // US Dollar
        'EUR', // Euro
        'GBP', // British Pound
        'INR', // Indian Rupee
        'JPY', // Japanese Yen
        'CAD', // Canadian Dollar
        'AUD', // Australian Dollar
        'CHF', // Swiss Franc
        'RSD', // Serbian Dinar
        'CNY', // Chinese Yuan
        'KRW', // South Korean Won
        'MXN', // Mexican Peso
        'BRL', // Brazilian Real
        'SGD', // Singapore Dollar
        'HKD', // Hong Kong Dollar
        'NZD', // New Zealand Dollar
        'SEK', // Swedish Krona
        'NOK', // Norwegian Krone
        'DKK', // Danish Krone
        'PLN', // Polish Zloty
        'THB', // Thai Baht
        'AED', // UAE Dirham
        'ZAR', // South African Rand
      ];
}
