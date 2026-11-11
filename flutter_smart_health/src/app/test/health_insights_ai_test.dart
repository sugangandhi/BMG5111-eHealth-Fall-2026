import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_health_app/config/api_config.dart';
import 'package:smart_health_app/features/insights/widgets/ai_clinical_synthesis_card.dart';

void main() {
  testWidgets('AiClinicalSynthesisCard shows GPT-4o badge, summary, and refresh action', (
    tester,
  ) async {
    ApiConfig.setRuntimeAiProviderLabel(null);
    var refreshed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiClinicalSynthesisCard(
            loading: false,
            summary: 'Activity and sleep metrics are well aligned.',
            onRefresh: () => refreshed = true,
          ),
        ),
      ),
    );

    expect(find.text('AI Clinical Synthesis'), findsOneWidget);
    expect(find.text('GPT-4o'), findsOneWidget);
    expect(find.text('Activity and sleep metrics are well aligned.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    expect(refreshed, isTrue);
  });
}
