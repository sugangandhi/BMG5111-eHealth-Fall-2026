import 'package:flutter/material.dart';


import '../models/ai_assistant_module_definition.dart';
import '../widgets/ai_assistant_module_picker.dart';
import '../widgets/health_chat_module.dart';
import '../widgets/whatsapp_inbox_module.dart';

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
  int _selectedIndex = 0;
  AiAssistantModuleDefinition? _activeModule;

  late final List<AiAssistantModuleDefinition> _modules;

  @override
  void initState() {
    super.initState();
    _modules = [
      AiAssistantModuleDefinition(
        id: 'health-chat',
        label: 'Chat',
        description: 'Ask AI questions about your vitals, health trends, and medications.',
        icon: Icons.chat_bubble_outline_rounded,
        builder: (_) => const HealthChatModule(),
      ),
      AiAssistantModuleDefinition(
        id: 'report-analyze',
        label: 'Report Analyze',
        description: 'Upload blood work or clinic PDFs for physician-grade interpretation.',
        icon: Icons.description_outlined,
        builder: widget.reportInterpreterBuilder ??
            (_) => const Center(child: Text('Clinical Report Interpreter Active')),
      ),
      AiAssistantModuleDefinition(
        id: 'nutrition-monitor',
        label: 'Nutrition Monitor',
        description: 'Analyze meals, dietary intake, and caloric recommendations.',
        icon: Icons.restaurant_outlined,
        builder: widget.nutritionMonitorBuilder ??
            (_) => const Center(child: Text('Nutrition Monitor Active')),
      ),
      AiAssistantModuleDefinition(
        id: 'whatsapp-care',
        label: 'WhatsApp Care Team',
        description: 'Direct communication with Intelligent Digital Solution and clinic triage on WhatsApp.',
        icon: Icons.message_rounded,
        builder: (_) => const WhatsAppInboxModule(),
      ),
    ];
  }



  @override
  Widget build(BuildContext context) {
    final isInsideModule = _activeModule != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isInsideModule ? _activeModule!.label : 'Choose an AI tool',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        leading: isInsideModule
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _activeModule = null;
                  });
                },
              )
            : null,
      ),
      body: isInsideModule
          ? _activeModule!.builder(context)
          : AiAssistantModulePicker(
              modules: _modules,
              selectedIndex: _selectedIndex,
              onSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              onLaunch: (module) {
                setState(() {
                  _activeModule = module;
                });
              },
            ),
    );
  }
}
