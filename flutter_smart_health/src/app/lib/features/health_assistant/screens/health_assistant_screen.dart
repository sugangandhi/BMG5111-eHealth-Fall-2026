import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ai_assistant_module_definition.dart';
import '../widgets/ai_assistant_module_picker.dart';
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
        description: 'Direct communication with Dr. Patel and clinic triage on WhatsApp.',
        icon: Icons.message_rounded,
        builder: (_) => _buildWhatsAppCareBody(),
      ),
    ];
  }

  Widget _buildWhatsAppCareBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat, size: 48, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 20),
            const Text(
              "Clinic WhatsApp Integration",
              style: TextStyle(fontSize: 20, fontWeight: '700'),
            ),
            const SizedBox(height: 10),
            const Text(
              "Send messages, log vitals, or send voice notes directly to the clinic care team. Your messages are automatically transcribed with Whisper and routed to Dr. Patel's triage inbox.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse("https://wa.me/16132616383?text=Hi%20Doctor,%20checking%20in%20from%20Smart%20Health%20Mobile%20App");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(url);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text("Open Clinic WhatsApp"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInsideModule = _activeModule != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isInsideModule ? _activeModule!.label : 'Choose an AI tool',
          style: const TextStyle(fontWeight: '700', fontSize: 18),
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
