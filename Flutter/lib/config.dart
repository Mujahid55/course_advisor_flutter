import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  AppConfig._();

  static const int port = 8000;

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:$port';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:$port';
    } catch (_) {}
    return 'http://localhost:$port';
  }
}
