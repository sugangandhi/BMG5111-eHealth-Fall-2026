import 'package:flutter/material.dart';

import '../widgets/health_chat_module.dart';

class HealthAssistantScreen extends StatefulWidget {
  final WidgetBuilder? reportInterpreterBuilder;
  final WidgetBuilder? nutritionMonitorBuilder;

  const HealthAssistantScreen({
    super.key,
    this.reportInterpreterBuilder,
    this.nutritionMonitorBuilder,
  });

  @override
  State<HealthAssistantScreen> createState() => _HealthAssistantScreenState();
}

class _HealthAssistantScreenState extends State<HealthAssistantScreen> {
  @override
  Widget build(BuildContext context) {
    return HealthChatModule(
      onBack: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
