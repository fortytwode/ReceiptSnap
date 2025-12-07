# ReceiptSnap

A receipt-scanning expense tracking app built with Flutter.

## Features

- **Receipt Capture**: Snap photos of receipts using your camera or pick from gallery
- **OCR Processing**: Automatic extraction of merchant, date, amount, and currency
- **Receipt Management**: View, edit, and organize your receipts
- **Expense Reports**: Group receipts into expense reports for submission
- **Report Submission**: Submit reports to approvers with one tap
- **Light/Dark Theme**: Automatic system theme detection with beautiful UI

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or later)
- Dart SDK (included with Flutter)
- For iOS: Xcode 14.0 or later
- For Android: Android Studio with Android SDK

### Installation

1. **Clone the repository**
   ```bash
   cd /Users/Shamanth/ReceiptSnap
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # iOS Simulator
   flutter run -d ios

   # Android Emulator
   flutter run -d android

   # Or run on connected device
   flutter run
   ```

### Platform Setup

#### iOS

The app requires camera and photo library permissions. These are already configured in `ios/Runner/Info.plist`:

- `NSCameraUsageDescription`: Camera access for capturing receipts
- `NSPhotoLibraryUsageDescription`: Photo library access for selecting existing receipts

To run on iOS:
```bash
cd ios
pod install
cd ..
flutter run -d ios
```

#### Android

The app requires camera and storage permissions. These are already configured in `android/app/src/main/AndroidManifest.xml`:

- `CAMERA`: Camera access for capturing receipts
- `READ_MEDIA_IMAGES` (Android 13+): Photo library access
- `READ_EXTERNAL_STORAGE` (Android 12 and below): Legacy storage access

## Project Structure

```
lib/
├── main.dart                 # Entry point
├── app.dart                  # App widget with theme and router
├── common/
│   ├── models/               # Data models (Receipt, Report, User)
│   ├── services/             # API client, storage, image services
│   ├── theme/                # Light/dark theme configuration
│   ├── utils/                # Helper functions
│   └── widgets/              # Reusable UI components
└── features/
    ├── onboarding/           # Onboarding flow with Liquid Glass
    ├── auth/                 # Authentication (anonymous/email)
    ├── receipts/             # Receipt list, capture, detail
    ├── reports/              # Report list, create, detail
    └── account/              # Account settings
```

## Configuration

### API Configuration

Update the API base URL and toggle mock mode in `lib/common/services/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = 'https://your-api-url.com';
  static const bool mockMode = false; // Set to false for real API
}
```

### Mock Mode

The app includes a mock mode for development that simulates:
- Receipt upload and OCR processing
- Report creation and submission
- User authentication

Set `mockMode = true` in `api_config.dart` to use mock data.

## API Endpoints

The app expects the following REST API endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/anonymous` | Anonymous login |
| POST | `/auth/login` | Email login |
| GET | `/receipts` | List receipts |
| GET | `/receipts/{id}` | Get receipt details |
| POST | `/receipts` | Upload receipt (multipart) |
| PUT | `/receipts/{id}` | Update receipt |
| DELETE | `/receipts/{id}` | Delete receipt |
| GET | `/reports` | List reports |
| GET | `/reports/{id}` | Get report details |
| POST | `/reports` | Create report |
| POST | `/reports/{id}/submit` | Submit report |

## Tech Stack

- **State Management**: Riverpod
- **Navigation**: GoRouter
- **HTTP Client**: Dio
- **Image Handling**: image_picker, flutter_image_compress
- **Caching**: cached_network_image
- **Storage**: SharedPreferences

## Liquid Glass (iOS)

The onboarding screens feature a "Liquid Glass" effect on iOS using a native platform view. The implementation uses `UIVisualEffectView` with blur effects to create a glass-like appearance.

On Android, a gradient background is used as a fallback.

## Phase II Features (Planned)

The following features are planned for future releases:

- Email ingestion (forward receipts as emails)
- Multiple approvers and role-based access
- Multi-currency conversion
- Automatic categorization with ML
- PDF receipt support
- Push notifications for approvals

## Testing

Run unit tests:
```bash
flutter test
```

Run integration tests:
```bash
flutter test integration_test
```

## Building for Release

### iOS
```bash
flutter build ios --release
```

### Android
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

## License

This project is proprietary software. All rights reserved.

## Support

For issues and feature requests, please contact the development team.
