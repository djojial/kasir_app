import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'package:kasir_app/halaman_utama.dart';
import 'features/auth/halaman_login.dart';
import 'core/theme_controller.dart';
import 'database/services/firestore_service.dart';
import 'core/app_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ValueNotifier<ThemeMode> _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = ValueNotifier(ThemeMode.light);
  }

  @override
  void dispose() {
    _themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF28C28);
    const goldSoft = Color(0xFFF7C27A);
    const darkText = Color(0xFF1C1B1A);
    const mutedText = Color(0xFF7C776D);
    const lightSurface = Color(0xFFFFFFFF);
    const lightBg = Color(0xFFF7F6F3);
    const lightBorder = Color(0xFFD7D3C9);
    const darkBg = Color(0xFF0E0E0E);
    const darkSurface = Color(0xFF181818);
    const darkBorder = Color(0xFF2A2A2A);
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: gold,
        secondary: goldSoft,
        surface: lightSurface,
        error: Color(0xFFB42318),
        onPrimary: Colors.white,
        onSecondary: darkText,
        onSurface: darkText,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: darkText,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: mutedText,
        ),
      ),
      dividerColor: lightBorder,
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shadowColor: const Color(0x22000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1EFEB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: gold, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkText,
          side: const BorderSide(color: lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFFF1EFEB),
        selectedColor: Color(0xFFE7DFC8),
        labelStyle: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: darkText),
        shape: StadiumBorder(),
        side: BorderSide(color: lightBorder),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF141414),
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFF1EFEB)),
        dividerThickness: 0.6,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: lightBorder),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        contentTextStyle: const TextStyle(color: mutedText),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: darkText,
        unselectedLabelColor: mutedText,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      iconTheme: const IconThemeData(color: mutedText),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: goldSoft,
        surface: darkSurface,
        error: Color(0xFFF97066),
        onPrimary: Colors.white,
        onSecondary: Color(0xFFEAE6DD),
        onSurface: Color(0xFFEAE6DD),
        onError: Colors.black,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: Color(0xFFEAE6DD),
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEAE6DD),
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEAE6DD),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Color(0xFFA6A29A),
        ),
      ),
      dividerColor: darkBorder,
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shadowColor: const Color(0x44000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1F1F1F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: gold, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEAE6DD),
          side: const BorderSide(color: darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFF202020),
        selectedColor: Color(0xFF2E2B24),
        labelStyle: TextStyle(color: Color(0xFFEAE6DD), fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: Color(0xFFEAE6DD)),
        shape: StadiumBorder(),
        side: BorderSide(color: darkBorder),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        contentTextStyle: TextStyle(color: Color(0xFFEAE6DD)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFF1F1F1F)),
        dividerThickness: 0.6,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkBorder),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFFEAE6DD),
        ),
        contentTextStyle: const TextStyle(color: Color(0xFFA6A29A)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFFEAE6DD),
        unselectedLabelColor: Color(0xFFA6A29A),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      iconTheme: const IconThemeData(color: Color(0xFFA6A29A)),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, mode, _) {
        return ThemeController(
          notifier: _themeMode,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "Kasir App",
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: mode,
            home: const _AuthGate(),
          ),
        );
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const HalamanLogin();
        }

        return StreamBuilder<Map<String, dynamic>?>(
          stream: firestore.streamUserProfile(user.uid, email: (user.email ?? '').toLowerCase()),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnap.data;
            if (profile == null) {
              if (HalamanLogin.pendingMessage == null) {
                HalamanLogin.showMessageOnNextLogin(
                  'Akun tidak terdaftar',
                );
              }
              FirebaseAuth.instance.signOut();
              return const HalamanLogin();
            }

            final role =
                (profile['role'] ?? 'operator').toString().toLowerCase();
            final disabled = profile['disabled'] == true;
            if (disabled) {
              if (HalamanLogin.pendingMessage == null) {
                HalamanLogin.showMessageOnNextLogin(
                  'Akun anda Dinonaktifkan',
                );
              }
              FirebaseAuth.instance.signOut();
              return const HalamanLogin();
            }
            return HalamanUtama(role: role);
          },
        );
      },
    );
  }
}
