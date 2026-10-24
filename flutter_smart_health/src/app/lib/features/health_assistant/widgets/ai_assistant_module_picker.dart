import 'package:flutter/material.dart';
import '../models/ai_assistant_module_definition.dart';

class AiAssistantModulePicker extends StatelessWidget {
  final List<AiAssistantModuleDefinition> modules;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<AiAssistantModuleDefinition> onLaunch;

  const AiAssistantModulePicker({
    super.key,
    required this.modules,
    required this.selectedIndex,
    required this.onSelected,
    required this.onLaunch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab indicator header for direct switching
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: List.generate(modules.length, (index) {
              final mod = modules[index];
              final isSelected = index == selectedIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(mod.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) onSelected(index);
                  },
                ),
              );
            }),
          ),
        ),
        // Scrollable cards list / PageView
        Expanded(
          child: ListView.builder(
            key: const ValueKey('ai-module-picker-pages'),
            padding: const EdgeInsets.all(16),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final mod = modules[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: index == selectedIndex
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                      width: index == selectedIndex ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('ai-module-${mod.id}'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      onSelected(index);
                      onLaunch(mod);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              mod.icon,
                              size: 32,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mod.label,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mod.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
