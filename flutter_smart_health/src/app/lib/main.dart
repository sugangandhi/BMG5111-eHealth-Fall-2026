import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_health_app/core/services/app_language_controller.dart';
import 'package:smart_health_app/features/auth/auth.dart';
import 'package:smart_health_app/features/health_assistant/health_assistant.dart';
import 'package:smart_health_app/ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguageController.instance.loadSavedLocale();
  final prefs = await SharedPreferences.getInstance();
  final bool? loggedInPref = prefs.getBool('whatsapp_logged_in_v1');
  final bool legacyVerified = prefs.getBool('doctor_whatsapp_verified_v1') ?? false;
  final String savedPhone = (prefs.getString('doctor_whatsapp_phone_v1') ?? '').trim();
  final bool startInChats = loggedInPref ?? (legacyVerified && savedPhone.isNotEmpty);
  runApp(SmartHealthApp(initialRoute: startInChats ? "/chats" : "/"));
}

class SmartHealthApp extends StatelessWidget {
  final String initialRoute;
  const SmartHealthApp({super.key, this.initialRoute = "/"});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguageController.instance,
      builder: (context, locale, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MaxAssist',
          locale: locale,
          theme: buildAppTheme(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('fr'),
            Locale('ar'),
          ],
          routes: {
            "/": (_) => const LoginScreen(),
            "/chats": (_) => const HealthAssistantScreen(),
            "/assistant": (_) => const HealthAssistantScreen(),
          },
          initialRoute: initialRoute,
        );
      },
    );
  }
}
