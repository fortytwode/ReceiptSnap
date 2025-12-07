import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/receipts/presentation/capture_receipt_screen.dart';
import '../../features/receipts/presentation/receipt_detail_screen.dart';
import '../../features/receipts/presentation/receipts_list_screen.dart';
import '../../features/reports/presentation/create_report_screen.dart';
import '../../features/reports/presentation/report_detail_screen.dart';
import '../../features/reports/presentation/reports_list_screen.dart';
import '../widgets/main_scaffold.dart';
import 'storage_service.dart';

/// Route paths
class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String main = '/main';
  static const String receipts = '/main/receipts';
  static const String reports = '/main/reports';
  static const String account = '/main/account';
  static const String receiptDetail = '/receipt/:id';
  static const String reportDetail = '/report/:id';
  static const String createReport = '/report/create';
  static const String capture = '/capture';
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final storage = ref.watch(storageServiceProvider);

  return GoRouter(
    initialLocation: storage.isOnboardingCompleted ? AppRoutes.main : AppRoutes.onboarding,
    routes: [
      // Onboarding
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Main scaffold with bottom navigation
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.main,
            redirect: (context, state) {
              if (state.matchedLocation == AppRoutes.main) {
                return AppRoutes.receipts;
              }
              return null;
            },
          ),
          GoRoute(
            path: AppRoutes.receipts,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReceiptsListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.reports,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReportsListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.account,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AccountScreen(),
            ),
          ),
        ],
      ),

      // Receipt detail
      GoRoute(
        path: AppRoutes.receiptDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReceiptDetailScreen(receiptId: id);
        },
      ),

      // Report detail
      GoRoute(
        path: AppRoutes.reportDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReportDetailScreen(reportId: id);
        },
      ),

      // Create report
      GoRoute(
        path: AppRoutes.createReport,
        builder: (context, state) => const CreateReportScreen(),
      ),

      // Capture receipt
      GoRoute(
        path: AppRoutes.capture,
        builder: (context, state) => const CaptureReceiptScreen(),
      ),
    ],
  );
});
