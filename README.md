
# StudyPal: Your AI Study Companion

StudyPal is a cross-platform Flutter application designed to help students manage their studies, collaborate, and leverage AI-powered features for enhanced productivity. This project integrates Firebase for authentication, storage, and real-time data, and supports Google Sign-In and Gemini AI integration (API key not included).

## Features
- User authentication (Email/Password, Google Sign-In)
- AI-powered study assistant (Gemini integration)
- File uploads and downloads
- Real-time chat and collaboration
- Media and file picker support
- Responsive UI with custom themes
- Integration tests and golden tests

## Getting Started

### Prerequisites
- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.10.0)
- Firebase project setup (Android/iOS/Web)
- Google Cloud Gemini API key (not included in repo)

### Installation
1. Clone the repository:
	```sh
	git clone https://github.com/Saad285/AKTI-FINAL-STUDYPAL_YOUR-_AI_STUDY_COMPANION.git
	cd AKTI-FINAL-STUDYPAL_YOUR-_AI_STUDY_COMPANION
	```
2. Install dependencies:
	```sh
	flutter pub get
	```
3. Add your Firebase configuration files:
	- Place `google-services.json` in `android/app/`
	- Place `GoogleService-Info.plist` in `ios/Runner/`
4. Add your Gemini API key in a file (not tracked by git):
	- Example: `lib/studypal/providers/gemini_api_key.dart`

### Running the App
```sh
flutter run
```

### Running Tests
```sh
flutter test
flutter test --update-goldens
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
```

## Folder Structure
- `lib/` - Main application code
- `integration_test/` - Integration tests
- `test/` - Unit and golden tests
- `test_driver/` - Integration test driver
- `android/`, `ios/`, `web/`, `macos/`, `linux/`, `windows/` - Platform-specific code

## Security
- **Do not commit your Gemini API key or other secrets.**
- Use `.gitignore` to exclude sensitive files.

## License
This project is for educational purposes. See LICENSE file if present.

## Contributors
- Saad285
- [Your Name Here]

---
For issues or feature requests, please open an issue on GitHub.
