import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:smart_health_app/core/services/app_language_controller.dart';
import 'package:smart_health_app/features/auth/auth.dart';
import 'package:smart_health_app/features/health_assistant/health_assistant.dart';
import 'package:smart_health_app/ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguageController.instance.loadSavedLocale();
  runApp(const SmartHealthApp());
}

class SmartHealthApp extends StatelessWidget {
  const SmartHealthApp({super.key});

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
          initialRoute: "/",
        );
      },
    );
  }
}
