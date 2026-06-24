# Fitness Tracker

A modern, beautiful fitness tracking application built with Flutter and Dart.

## Features

### Current Implementation
- **Authentication System**
  - Login Screen with email/password validation
  - Registration Screen with strong password requirements
  - Social login options (Google, Apple)
  - "Forgot Password" link

- **Home Dashboard** - Overview of daily activities and progress
- **Activity Rings** - Visual progress indicators for Move, Exercise, and Stand goals
- **Daily Stats** - Quick view of steps, calories, heart rate, and water intake
- **Recent Workouts** - Display of past workout sessions
- **Settings Screen**
  - User profile information and edit profile option
  - Account settings (email, password, 2FA)
  - Preferences (notifications, dark mode)
  - Unit preferences (km/miles)
  - About & legal information
  - Logout button with confirmation
- **Bottom Navigation** - Easy navigation between different sections
- **Material Design 3** - Modern, clean UI with smooth interactions

## Architecture

### Project Structure
```
fitness_tracker/
├── lib/
│   ├── main.dart                 # App entry point (starts with LoginScreen)
│   ├── screens/
│   │   ├── login_screen.dart     # Authentication login page
│   │   ├── registration_screen.dart  # Account creation page
│   │   ├── home_screen.dart      # Main dashboard
│   │   └── settings_screen.dart  # User profile & settings
│   ├── widgets/
│   │   ├── stats_card.dart       # Individual stat cards
│   │   ├── activity_ring.dart    # Activity progress rings
│   │   └── workout_card.dart     # Workout display cards
│   └── themes/
│       └── app_theme.dart        # Global theme configuration
├── web/                          # Web platform files
├── assets/
│   └── images/                   # Image assets
└── pubspec.yaml                  # Dependencies
```

## Dependencies

- **google_fonts** - Custom typography
- **percent_indicator** - Progress ring visualization
- **Material Design 3** - Modern UI components

## Getting Started

### Prerequisites
- Flutter 3.0.0 or higher
- Dart 2.19.0 or higher
- Android Studio / Xcode (for iOS development)
- Chrome (for web development)

### Installation

1. Clone the repository
   ```bash
   git clone <repository-url>
   cd fitness_tracker
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Run the app
   ```bash
   # Android/iOS
   flutter run
   
   # Web
   flutter run -d chrome
   ```

### Test Credentials
The app currently uses mock authentication. You can enter any email and password to login.

- **Email**: any valid email format (e.g., test@example.com)
- **Password**: any password (6+ characters for login, 8+ with uppercase and number for signup)

## Development

### Running in Development Mode
```bash
flutter run
```

### Building for Production
```bash
flutter build apk        # Android
flutter build ios        # iOS
```

### Code Quality
```bash
flutter analyze          # Analyze code
flutter format .         # Format code
```

## Current Status
✅ Login & Registration UI Complete
✅ Settings & Profile Screen Complete
✅ Static Dashboard UI Complete
⏳ Web Platform Support (partial - issues with spaces in path)

## Planned Features
- [ ] Backend API integration (Firebase/REST)
- [ ] Real data integration from fitness devices
- [ ] Analytics screen with charts and statistics
- [ ] Goals management and tracking
- [ ] Workout details view and history
- [ ] Data persistence (local database with Hive/Sqflite)
- [ ] Push notifications
- [ ] Social features (activity sharing, friend tracking)
- [ ] Dark mode implementation
- [ ] Multi-language support
- [ ] Wearable device integration (Apple Watch, Wear OS)

## Color Scheme
- **Primary**: Indigo (#6366F1)
- **Secondary**: Green (#10B981)
- **Accent**: Amber (#F59E0B)
- **Background**: Light Gray (#F9FAFB)

## License
[Add your license here]

## Support
For issues or questions, please create an issue in the repository.
