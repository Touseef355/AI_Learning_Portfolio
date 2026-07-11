import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'screens/auth/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load saved theme preference
  final prefs     = await SharedPreferences.getInstance();
  final savedMode = prefs.getString('themeMode') ?? 'system';
  final initial   = _themeModeFrom(savedMode);

  runApp(ParkrooApp(initialThemeMode: initial));
}

ThemeMode _themeModeFrom(String value) {
  switch (value) {
    case 'light':  return ThemeMode.light;
    case 'dark':   return ThemeMode.dark;
    default:       return ThemeMode.system;
  }
}

class ParkrooApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  const ParkrooApp({super.key, this.initialThemeMode = ThemeMode.system});

  // Global notifier — any screen can call ParkrooApp.setTheme(context, ThemeMode.light)
  static final _themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Call this from Settings screen to switch theme.
  static void setTheme(ThemeMode mode) async {
    _themeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  /// Get current theme mode from anywhere.
  static ThemeMode get currentMode => _themeNotifier.value;

  @override
  State<ParkrooApp> createState() => _ParkrooAppState();
}

class _ParkrooAppState extends State<ParkrooApp> {
  @override
  void initState() {
    super.initState();
    ParkrooApp._themeNotifier.value = widget.initialThemeMode;
    ParkrooApp._themeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    ParkrooApp._themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    'Parkroo',
      debugShowCheckedModeBanner: false,
      theme:                    AppTheme.lightTheme,
      darkTheme:                AppTheme.darkTheme,
      themeMode:                ParkrooApp._themeNotifier.value,
      home:                     const SplashScreen(),
    );
  }
}
