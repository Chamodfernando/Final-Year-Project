import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'firebase_options.dart';

import 'app_colors.dart';
import 'loading_screen.dart';
import 'services/app_locale_controller.dart';
import 'services/user_profile_firestore_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final localeController = AppLocaleController.instance;
  await localeController.loadSavedLocale();
  runApp(MyApp(localeController: localeController));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.localeController});

  final AppLocaleController localeController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DateTime? _foregroundStartedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = WidgetsBinding.instance.lifecycleState;
      if (s == AppLifecycleState.resumed) {
        _foregroundStartedAt = DateTime.now();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now();
    if (state == AppLifecycleState.resumed) {
      _foregroundStartedAt = now;
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final start = _foregroundStartedAt;
      _foregroundStartedAt = null;
      if (start != null) {
        final d = now.difference(start);
        unawaited(UserProfileFirestoreSync.recordForegroundSession(d));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.localeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Ceylon Trails',
          debugShowCheckedModeBanner: false,
          locale: widget.localeController.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('si'),
            Locale('ta'),
          ],
          theme: ThemeData(
            scaffoldBackgroundColor: AppColors.background,
            useMaterial3: false,
            textTheme: const TextTheme(
              titleLarge: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              bodyMedium: TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          home: const LoadingScreen(),
        );
      },
    );
  }
}
