import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'services/locale_controller.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Do NOT load saved locale here — login screen always shows in English.
  // The saved locale is applied in HomeScreen.initState() after login.

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const GoldVaultApp());
}

/// Convenience getter for the global Supabase client.
final SupabaseClient supabase = Supabase.instance.client;

class GoldVaultApp extends StatelessWidget {
  const GoldVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild MaterialApp whenever the user picks a new language so
    // every Translations.of(...) lookup throughout the tree returns
    // strings in the new locale.
    return ValueListenableBuilder<Locale>(
      valueListenable: localeController,
      builder: (_, locale, __) {
        return MaterialApp(
          title: 'GoldVault',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LocaleController.supported
              .map((l) => l.locale)
              .toList(),
          home: const AuthGate(),
          routes: {
            '/login': (_) => const LoginScreen(),
          },
        );
      },
    );
  }
}
