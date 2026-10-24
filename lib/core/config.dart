/// Backend address.
/// Android emulator -> http://10.0.2.2:8000 (default)
/// Real phone       -> flutter run --dart-define=API_BASE_URL=http://<your-pc-ip>:8000
const String apiBaseUrl =
String.fromEnvironment('API_BASE_URL', defaultValue: 'https://replypilot-backend-recc.onrender.com');