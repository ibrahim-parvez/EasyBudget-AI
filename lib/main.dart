// lib/main.dart
import 'package:EasyBudgetAI/pages/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// NEW: HouseholdProvider for global currentHouseholdId
class HouseholdProvider extends ChangeNotifier {
  String? _currentHouseholdId;

  String? get currentHouseholdId => _currentHouseholdId;

  void setHousehold(String? id) {
    _currentHouseholdId = id;
    notifyListeners();
  }

  void clearHousehold() {
    _currentHouseholdId = null;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HouseholdProvider()), // NEW
      ],
      child: const EasyBudgetApp(),
    ),
  );
}

class EasyBudgetApp extends StatelessWidget {
  const EasyBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EasyBudget AI',
      theme: AppThemes.light,
      darkTheme: AppThemes.dark,
      themeMode: themeProvider.mode,
      builder: (context, child) {
        // Detect actual brightness: either themeMode or system default
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final isDark = themeProvider.mode == ThemeMode.dark ||
            (themeProvider.mode == ThemeMode.system &&
                platformBrightness == Brightness.dark);

        // Set the system UI overlay (status bar icons) dynamically
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark, // Android
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,     // iOS
        ));

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: child!,
        );
      },
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}

/// AuthGate remains unchanged
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in → go HomePage
        if (snapshot.hasData) {
          return const HomePage();
        }

        // If user canceled Google login or is signed out → go LoginPage
        return const LoginPage();
      },
    );
  }
}
