import 'package:flutter/material.dart';

import '../../../config/api_config.dart';
import '../../../ui/ui.dart';
import '../presentation/insights_styles.dart';

class AiClinicalSynthesisCard extends StatelessWidget {
  final bool loading;
  final String? summary;
  final String? errorMessage;
  final VoidCallback onRefresh;

  const AiClinicalSynthesisCard({
    super.key,
    required this.loading,
    required this.summary,
    this.errorMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: InsightsStyles.sectionMargin,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: AppRadii.radius(AppRadii.dialog),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: InsightsStyles.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: InsightsStyles.sectionIconDecoration,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Clinical Synthesis',
                        style: InsightsStyles.sectionTitle,
                      ),
                      Text(
                        'Wearables + clinical records summary',
                        style: InsightsStyles.sectionSubtitle,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadii.radius(AppRadii.sm),
                  ),
                  child: Text(
                    ApiConfig.aiProviderLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Regenerate AI Synthesis',
                  onPressed: loading ? null : onRefresh,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Generating holistic insight with GPT-4o...',
                      style: InsightsStyles.sectionSubtitle,
                    ),
                  ),
                ],
              )
            else if (errorMessage != null && errorMessage!.isNotEmpty)
              Text(
                errorMessage!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.orange.shade800,
                  height: 1.45,
                ),
              )
            else if (summary != null && summary!.isNotEmpty)
              Text(summary!, style: InsightsStyles.insightBody)
            else
              const Text(
                'Sync wearable or clinical data to generate a holistic AI summary.',
                style: InsightsStyles.sectionSubtitle,
              ),
          ],
        ),
      ),
    );
  }
}
