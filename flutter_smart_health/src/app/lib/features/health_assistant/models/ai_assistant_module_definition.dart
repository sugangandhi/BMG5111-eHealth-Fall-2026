import 'package:flutter/material.dart';

class AiAssistantModuleDefinition {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;

  const AiAssistantModuleDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.builder,
  });
}
