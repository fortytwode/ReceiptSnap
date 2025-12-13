# ReceiptSnap - Complete Documentation

## Overview

**ReceiptSnap** is a Flutter-based expense tracking application that allows users to capture receipts, extract data via OCR, organize expenses into reports, and submit them via email.

### Tech Stack
- **Framework:** Flutter 3.x with Dart
- **State Management:** Riverpod
- **Navigation:** GoRouter
- **Local Database:** SQLite (sqflite)
- **Persistent Storage:** SharedPreferences
- **OCR:** Google ML Kit Text Recognition
- **Email Backend:** Firebase Cloud Functions + Resend
- **Image Handling:** image_picker, flutter_image_compress, photo_view

### Architecture
```
lib/
├── main.dart                 # App entry point, Firebase init
├── app.dart                  # MaterialApp configuration
├── firebase_options.dart     # Firebase configuration (auto-generated)
├── common/
│   ├── models/              # Data models (Receipt, Report, User)
│   ├── services/            # Business logic services
│   ├── widgets/             # Reusable UI components
│   ├── theme/               # App theming (Material 3)
│   └── utils/               # Utility functions
└── features/
    ├── receipts/            # Receipt management
    ├── reports/             # Report management
    ├── account/             # User settings
    └── onboarding/          # First-launch experience
```

---

## Implemented Features

### 1. Receipt Management

#### Photo Capture
- **Camera capture** with permission handling
- **Gallery picker** for existing photos
- **Image compression** before storage (configurable quality)
- Automatic navigation to detail screen after capture

#### OCR Processing (Google ML Kit)
- **Merchant extraction** from receipt text
- **Date detection** (supports DD/MM/YYYY, YYYY-MM-DD, "Month DD, YYYY" formats)
- **Amount extraction** with keyword detection ("total", "due", "amount", etc.)
- **Currency detection** from symbols and codes
- Confidence scoring for extracted data

#### Manual Expense Entry
- For cash expenses without receipt photos
- All fields manually editable
- Auto-confirmed status (no OCR needed)
- Route: `/manual-entry`

#### Receipt Editing
- Edit merchant, date, amount, currency, category, notes
- Full-screen image viewer with zoom (photo_view)
- Confirm OCR results
- Delete receipts

#### Search & Filtering
- Search by merchant, category, or notes
- Filter options:
  - **All** - All visible receipts
  - **Draft** - Receipts not in any report
  - **In Report** - Receipts in draft reports
- Receipts in submitted reports are hidden from main list

#### Multi-Currency Support
Supported currencies (20+):
```
USD ($), EUR (€), GBP (£), INR (₹), JPY (¥), CNY (¥),
RSD (RSD), CAD (C$), AUD (A$), CHF (CHF), SEK (kr),
NOK (kr), DKK (kr), PLN (zł), CZK (Kč), HUF (Ft),
RON (lei), BGN (лв), HRK (kn), RUB (₽)
```

#### Automatic Category Inference
Categories auto-detected from merchant name:
- **Lodging** - Hotels, Airbnb, etc.
- **Transportation** - Uber, Lyft, parking, gas, transit
- **Travel** - Airlines, airports, booking sites
- **Food & Drink** - Restaurants, coffee shops, fast food
- **Office Supplies** - Staples, Office Depot, FedEx
- **Entertainment** - Cinema, concerts, streaming
- **Utilities** - Electric, phone, internet
- **Other** - Default category

---

### 2. Report Management

#### Report Creation Wizard
- **Step 1:** Enter details (title, date range, approver email)
- **Step 2:** Select receipts (shows confirmed, unlinked receipts)
- Auto-generates title: "Month YYYY Expenses"
- Links selected receipts to report on creation
- Route: `/report/create`

#### Add Receipts to Existing Reports
From report detail screen, tap "Add" to:
- **Take Photo** - Capture new receipt
- **Choose from Gallery** - Select existing photo
- **Manual Entry** - Add cash expense
- **Add Existing Receipt** - Multi-select from confirmed receipts

#### Receipt Linking
- Receipts linked via `reportId` field
- Only confirmed, unlinked receipts available for selection
- Receipts can be removed from draft reports
- Receipts in submitted reports are read-only

#### Report Submission
- **Email recipient dialog** (first time or change)
- **Currency selection** for report totals
- **Automatic email delivery** via Firebase
- **CSV attachment** with all receipt details
- Falls back to native email composer if Firebase fails

#### Report Status
- **Draft** - Editable, can add/remove receipts
- **Submitted** - Read-only, sent to approver
- (Future: Approved, Rejected)

#### UI Improvements
- Side-by-side "Save" and "Add to Report" buttons
- Simplified status filters (removed Approved/Rejected)
- Receipt cards show conversion to report currency

---

### 3. Email System

#### Firebase Cloud Functions Backend
- **Project:** team-projects-480520
- **Function:** `sendExpenseReport`
- **Region:** us-central1
- **Runtime:** Node.js 20

#### Resend Email Provider
- **Free tier:** 3,000 emails/month
- **From address:** `noreply@rocketshiphq.com` (pending domain verification)
- **API key:** Stored in `functions/.env` (gitignored)

#### Email Flow
1. User taps "Submit Report"
2. Enters/confirms recipient email
3. Selects report currency
4. App calls Firebase Cloud Function
5. Function sends email via Resend API
6. CSV attached with receipt details
7. Falls back to native email if Firebase fails

#### Email Content
- **Subject:** "Expense Report: {Report Title}"
- **Body:** Report summary with totals, receipt count, date range
- **Attachment:** CSV with all receipt details

#### Fallback Mechanism
If Firebase email fails:
1. Opens native email composer (flutter_email_sender)
2. Pre-fills recipient, subject, body
3. Attaches CSV file
4. Falls back to share sheet if no email app configured

---

### 4. Export Features

#### CSV Exports
- **All Receipts:** Complete receipt list with all fields
- **All Reports:** Report summaries with totals
- **Single Report:** Detailed receipt list for one report

#### CSV Format
```csv
ID,Merchant,Date,Amount,Currency,Category,Note,Status,Report ID,Created At
abc123,Starbucks,2025-12-13,5.50,USD,Food & Drink,,confirmed,,2025-12-13T10:00:00
```

#### Share Options
- System share sheet (share_plus)
- Native email composer (flutter_email_sender)
- Automatic file handling for both options

---

### 5. User Settings (Account Screen)

#### Preferences
- **Default Currency:** Applied to new receipts (stored in SharedPreferences)
- **Default Recipient Email:** Pre-filled on report submission

#### Export Options
- Export all receipts to CSV
- Export all reports to CSV

#### Account Info
- User name and email display
- Device-based storage info
- App version (v1.0.0)

#### Support Links (Placeholders)
- Help & FAQ
- Privacy Policy
- Terms of Service

---

## Technical Architecture

### Services Layer

| Service | Purpose |
|---------|---------|
| `AuthService` | User authentication (anonymous/email login) |
| `StorageService` | SharedPreferences wrapper for settings |
| `DatabaseService` | SQLite database operations |
| `ReceiptsService` | Receipt CRUD and business logic |
| `ReportsService` | Report CRUD and submission |
| `OcrService` | Google ML Kit text recognition |
| `ImageService` | Camera/gallery capture, compression |
| `ExportService` | CSV generation and sharing |
| `FirebaseEmailService` | Cloud Function email sending |
| `CurrencyService` | Currency formatting and conversion |
| `RouterService` | GoRouter navigation configuration |
| `ApiClient` | HTTP client (placeholder for future API) |

### Database Schema

#### Receipts Table
```sql
CREATE TABLE receipts (
  id TEXT PRIMARY KEY,
  imageUrl TEXT NOT NULL,
  merchant TEXT,
  date TEXT,
  amount REAL,
  currency TEXT,
  category TEXT,
  note TEXT,
  ocrStatus TEXT NOT NULL,
  reportId TEXT,
  createdAt TEXT NOT NULL
);

CREATE INDEX idx_receipts_reportId ON receipts(reportId);
CREATE INDEX idx_receipts_ocrStatus ON receipts(ocrStatus);
```

#### Reports Table
```sql
CREATE TABLE reports (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  status TEXT NOT NULL,
  totalAmount REAL NOT NULL,
  currency TEXT NOT NULL,
  comment TEXT,
  approverEmail TEXT,
  startDate TEXT,
  endDate TEXT,
  createdAt TEXT NOT NULL
);

CREATE INDEX idx_reports_status ON reports(status);
```

### State Management (Riverpod)

#### Core Providers
- `receiptsProvider` - Receipt list with filters
- `uploadReceiptProvider` - Upload and OCR workflow
- `receiptDetailProvider(id)` - Single receipt (family provider)
- `reportsProvider` - Report list with status filter
- `createReportProvider` - Multi-step creation state
- `submitReportProvider` - Submission workflow
- `reportDetailProvider(id)` - Single report (family provider)

#### Service Providers
- `authServiceProvider`
- `storageServiceProvider`
- `databaseServiceProvider`
- `receiptsServiceProvider`
- `reportsServiceProvider`
- `ocrServiceProvider`
- `imageServiceProvider`
- `exportServiceProvider`
- `firebaseEmailServiceProvider`
- `currencyServiceProvider`

---

## Commit History

| Commit | Description |
|--------|-------------|
| `49ccfb4` | Update email sender to use verified rocketshiphq.com domain |
| `81c667c` | Fix email normalization for Resend API compatibility |
| `9ac5e25` | Add Firebase email backend with Resend for automatic report delivery |
| `8856371` | Improve UX: side-by-side buttons, add receipt to report, simplify statuses |
| `ef2dcde` | Fix: Add Manual Entry option to FAB bottom sheet |
| `0a5d5eb` | Fix receipts filtering and improve receipt-to-report UX |
| `bacc8d5` | Add email composer, manual expense entry, and report currency features |
| `f275d92` | Fix receipt-to-report linking and add email sharing |
| `8016313` | Build 7: Fix report totals, hide in-report receipts, improve UX |
| `0f500cd` | Add Firebase ML Kit OCR and streamlined receipt-to-report flow |
| `bce7fc2` | Fix multiple bugs: amount display, currencies, reports navigation |
| `83a8d76` | Fix iOS permissions by adding permission_handler preprocessor flags |
| `2049263` | Fix page indicator dots - clearer size difference |
| `4ffa473` | Fix permissions and improve onboarding UI |
| `e58848b` | Use com.rocketshiphq.receiptSnap bundle ID |
| `0fcf3f8` | Fix bundle ID to match App Store Connect |
| `04ae424` | Improve UX: reduce clicks, fix camera errors |
| `66fdc52` | Add custom app icon |
| `cb622dc` | Initial commit: ReceiptSnap Flutter app |

---

## Configuration

### Firebase
- **Project ID:** `team-projects-480520`
- **Project Name:** Team Projects
- **iOS App ID:** `1:600074244520:ios:096b37b5f0639285028d9d`
- **Console:** https://console.firebase.google.com/project/team-projects-480520

### App Identifiers
- **Bundle ID (iOS):** `com.rocketshiphq.receiptSnap`
- **App Name:** ReceiptSnap

### Email (Resend)
- **Provider:** Resend.com
- **Free tier:** 3,000 emails/month
- **From domain:** `rocketshiphq.com` (pending DNS verification)
- **From address:** `noreply@rocketshiphq.com`
- **API key location:** `functions/.env` (gitignored)

### Cloud Functions
- **Location:** `functions/`
- **Runtime:** Node.js 20
- **Dependencies:** firebase-admin, firebase-functions, resend
- **Deploy:** `firebase deploy --only functions`

---

## Future Roadmap

### Immediate (Pending)
- [ ] Complete Resend domain verification for `rocketshiphq.com`
- [ ] Test email delivery to external recipients

### Short-term Enhancements
- [ ] PDF export with receipt images embedded
- [ ] Bulk import from gallery (select multiple photos)
- [ ] Receipt image editing (crop, rotate)
- [ ] Duplicate receipt detection

### Medium-term Features
- [ ] Approval workflow (approver can approve/reject in-app)
- [ ] Push notifications for report status changes
- [ ] Recurring reports (weekly/monthly auto-generation)
- [ ] Report templates

### Long-term Integrations
- [ ] QuickBooks export
- [ ] Xero export
- [ ] Slack notifications
- [ ] Calendar integration for travel expenses

### Analytics (Future)
- [ ] Spending trends by category
- [ ] Monthly comparisons
- [ ] Budget tracking and alerts
- [ ] Dashboard with charts

---

## Development Notes

### Running Locally
```bash
# Get dependencies
flutter pub get

# Run on iOS simulator
flutter run -d "iPhone 16 Pro"

# Build for release
flutter build ios --release
```

### Firebase Functions
```bash
# Install dependencies
cd functions && npm install

# Deploy functions
firebase deploy --only functions --project team-projects-480520

# View logs
firebase functions:log --project team-projects-480520
```

### Environment Files
- `functions/.env` - Contains `RESEND_API_KEY` (gitignored)
- `ios/Runner/GoogleService-Info.plist` - Firebase iOS config

---

*Last updated: December 13, 2025*
