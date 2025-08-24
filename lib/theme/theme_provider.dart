import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;  // ✅ follow device setting by default

  void toggleTheme() {
    if (mode == ThemeMode.light) {
      mode = ThemeMode.dark;
    } else if (mode == ThemeMode.dark) {
      mode = ThemeMode.light;
    } else {
      // If system mode, default toggle goes to dark
      mode = ThemeMode.dark;
    }
    notifyListeners();
  }
}
