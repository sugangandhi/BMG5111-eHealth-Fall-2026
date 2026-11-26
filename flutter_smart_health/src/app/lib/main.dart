import 'package:flutter/material.dart';
import 'package:smart_health_app/features/auth/auth.dart';
import 'package:smart_health_app/features/health_assistant/health_assistant.dart';
import 'package:smart_health_app/l10n/generated/app_localizations.dart';
import 'package:smart_health_app/ui/app_theme.dart';

void main() {
  runApp(const SmartHealthApp());
}

class SmartHealthApp extends StatelessWidget {
  const SmartHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {
        "/": (_) => const LoginScreen(),
        "/chats": (_) => const HealthAssistantScreen(),
        "/assistant": (_) => const HealthAssistantScreen(),
      },
      initialRoute: "/",
    );
  }
}
