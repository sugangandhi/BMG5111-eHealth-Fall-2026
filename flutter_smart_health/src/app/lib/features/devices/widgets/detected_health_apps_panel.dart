import 'package:flutter/material.dart';
import 'package:health/health.dart';

import '../../../data/models/wearable_models.dart';
import '../../../services/mobile_health_registry_service.dart';
import '../../../ui/ui.dart';
import '../presentation/device_styles.dart';

class DetectedHealthAppsPanel extends StatelessWidget {
  final MobileHealthScanSnapshot? snapshot;
  final bool loading;
  final bool busy;
  final String? activeSyncSource;
  final String? lastActionMessage;
  final bool lastActionError;
  final VoidCallback onRefreshScan;
  final ValueChanged<DetectedHealthApp> onSyncApp;
  final ValueChanged<DetectedHealthApp> onOpenApp;
  final VoidCallback onOpenHealthConnectSettings;
  final VoidCallback onConnectFitbit;
  final VoidCallback onImportExportFile;

  const DetectedHealthAppsPanel({
    super.key,
    required this.snapshot,
    required this.loading,
    required this.busy,
    required this.activeSyncSource,
    required this.lastActionMessage,
    this.lastActionError = false,
    required this.onRefreshScan,
    required this.onSyncApp,
    required this.onOpenApp,
    required this.onOpenHealthConnectSettings,
    required this.onConnectFitbit,
    required this.onImportExportFile,
  });

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    final apps = snap?.apps ?? const <DetectedHealthApp>[];
    final installedCount = apps.where((a) => a.installed).length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(16),
      decoration: DeviceStyles.patientCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: DeviceStyles.simulationIconDecoration,
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detected Mobile Health Apps',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitleText(snap, installedCount),
                      style: DeviceStyles.patientMeta,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Rescan Health Apps',
                onPressed: loading || busy ? null : onRefreshScan,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPlatformStatusBanner(snap),
          if (lastActionMessage != null && lastActionMessage!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _StatusFeedbackPill(
              message: lastActionMessage!,
              isError: lastActionError,
              onAction: lastActionError &&
                      !(snap?.isWebMode ?? true) &&
                      snap?.targetPlatform == TargetPlatform.android
                  ? onOpenHealthConnectSettings
                  : null,
              actionLabel: 'Open Health Connect Permissions',
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onImportExportFile,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.radius(AppRadii.md),
                ),
              ),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text(
                'Import Health Export (CSV, XML, JSON, ZIP)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (apps.isNotEmpty) ...[
            const SizedBox(height: 14),
            ..._buildCategorizedAppTiles(
              apps: apps,
              snap: snap,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCategorizedAppTiles({
    required List<DetectedHealthApp> apps,
    required MobileHealthScanSnapshot? snap,
  }) {
    final isWebMode = snap?.isWebMode ?? false;
    final platform = snap?.targetPlatform ?? TargetPlatform.android;

    Widget buildTile(DetectedHealthApp app) => _DetectedAppTile(
      app: app,
      isWebMode: isWebMode,
      targetPlatform: platform,
      busy: busy,
      isActiveSync: activeSyncSource == app.sourceKey,
      onSync: () => onSyncApp(app),
      onUploadExport: onImportExportFile,
      onOpen: () => onOpenApp(app),
      onConnectFitbit: onConnectFitbit,
    );

    if (isWebMode) {
      return apps.map(buildTile).toList();
    }

    final installed = apps.where((a) => a.installed).toList();
    final other = apps.where((a) => !a.installed).toList();

    return [
      if (installed.isNotEmpty) ...[
        Text(
          'INSTALLED ON THIS PHONE (${installed.length})',
          style: DeviceStyles.patientMeta.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...installed.map(buildTile),
      ],
      if (other.isNotEmpty)
        Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 4),
            initiallyExpanded: installed.isEmpty,
            title: Text(
              'Other Compatible Apps (${other.length})',
              style: DeviceStyles.patientMeta.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            children: other.map(buildTile).toList(),
          ),
        ),
    ];
  }

  String _subtitleText(MobileHealthScanSnapshot? snap, int installedCount) {
    if (snap == null) return 'Scanning available health integrations...';
    if (!snap.isWebMode && snap.targetPlatform == TargetPlatform.android) {
      return '$installedCount installed app(s) detected on Android • Health Connect bridge';
    }
    if (!snap.isWebMode && snap.targetPlatform == TargetPlatform.iOS) {
      return 'iOS HealthKit bridge + cloud wearables ready';
    }
    if (snap.targetPlatform == TargetPlatform.android) {
      return 'Android browser detected • Health Connect, Google Fit, Samsung Health & Fitbit supported';
    }
    if (snap.targetPlatform == TargetPlatform.iOS) {
      return 'iPhone browser detected • Apple Health export & Fitbit Cloud supported';
    }
    return 'Universal wearable connectors & file export importer';
  }

  Widget _buildPlatformStatusBanner(MobileHealthScanSnapshot? snap) {
    if (snap == null) return const SizedBox.shrink();

    if (!snap.isWebMode && snap.targetPlatform == TargetPlatform.android) {
      final hc = snap.healthConnectStatus;
      final available = hc == HealthConnectSdkStatus.sdkAvailable;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (available ? Colors.green : Colors.orange).withValues(
            alpha: 0.08,
          ),
          borderRadius: AppRadii.radius(AppRadii.md),
          border: Border.all(
            color: (available ? Colors.green : Colors.orange).withValues(
              alpha: 0.3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              available
                  ? Icons.verified_user_rounded
                  : Icons.warning_amber_rounded,
              color: available ? Colors.green.shade700 : Colors.orange.shade800,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                available
                    ? 'Health Connect is active. Allow eHospital to read data and enable "Allow to write" in Samsung Health / your health app, then tap Sync.'
                    : 'Health Connect needs setup or update on this phone to read Samsung Health automatically.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: available
                      ? Colors.green.shade900
                      : Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: busy ? null : onOpenHealthConnectSettings,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                available ? 'Permissions' : 'Setup',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (snap.isWebMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: DeviceStyles.bannerDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.public_rounded,
              size: 17,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Web Browser Mode (Real Connections Only): Browsers cannot access Samsung Health or Health Connect directly. To use real data, upload your exported CSV/XML/JSON/ZIP file below, connect Fitbit Cloud OAuth, or install the Android APK.',
                style: DeviceStyles.bannerBody.copyWith(fontSize: 11.5),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _DetectedAppTile extends StatelessWidget {
  final DetectedHealthApp app;
  final bool isWebMode;
  final TargetPlatform targetPlatform;
  final bool busy;
  final bool isActiveSync;
  final VoidCallback onSync;
  final VoidCallback onUploadExport;
  final VoidCallback onOpen;
  final VoidCallback onConnectFitbit;

  const _DetectedAppTile({
    required this.app,
    required this.isWebMode,
    required this.targetPlatform,
    required this.busy,
    required this.isActiveSync,
    required this.onSync,
    required this.onUploadExport,
    required this.onOpen,
    required this.onConnectFitbit,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentForSource(app.sourceKey);
    final isWebLocalExportOnly = isWebMode && !app.supportsDirectWebOAuth;
    final badgeColor = app.connected
        ? Colors.green.shade700
        : isWebLocalExportOnly
        ? AppColors.primary
        : app.installed
        ? AppColors.primary
        : AppColors.textMuted;
    final badgeText = app.connected
        ? 'CONNECTED'
        : isWebLocalExportOnly
        ? 'FILE / APK'
        : app.installed
        ? 'INSTALLED'
        : 'OPTIONAL';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: AppRadii.radius(AppRadii.md),
        border: Border.all(
          color: app.installed
              ? accent.withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconForSource(app.sourceKey), color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  app.statusNote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DeviceStyles.patientMeta.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isWebMode &&
              targetPlatform == TargetPlatform.android &&
              app.installed &&
              app.packageName.isNotEmpty)
            IconButton(
              tooltip: 'Open ${app.name}',
              onPressed: busy ? null : onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          if (app.sourceKey == WearableSource.fitbit && !app.connected)
            OutlinedButton(
              onPressed: busy ? null : onConnectFitbit,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Connect',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            )
          else if (isWebLocalExportOnly)
            OutlinedButton(
              onPressed: busy ? null : onUploadExport,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Upload File',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            )
          else if (app.supportsHealthConnect || app.connected)
            ElevatedButton(
              onPressed: busy ? null : onSync,
              style: ElevatedButton.styleFrom(
                backgroundColor: app.installed ? accent : AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.radius(AppRadii.sm),
                ),
              ),
              child: isActiveSync
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sync',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  static Color _accentForSource(String sourceKey) {
    switch (sourceKey) {
      case WearableSource.samsungHealth:
        return const Color(0xFF1428A0);
      case WearableSource.healthConnect:
      case WearableSource.googleHealth:
        return const Color(0xFF0284C7);
      case WearableSource.appleHealth:
        return const Color(0xFFE11D48);
      case WearableSource.fitbit:
        return const Color(0xFF00B0B9);
      case WearableSource.garmin:
        return const Color(0xFF007CC3);
      case WearableSource.strava:
        return const Color(0xFFFC4C02);
      case WearableSource.oura:
        return const Color(0xFF475569);
      default:
        return AppColors.primary;
    }
  }

  static IconData _iconForSource(String sourceKey) {
    switch (sourceKey) {
      case WearableSource.samsungHealth:
        return Icons.directions_walk_rounded;
      case WearableSource.healthConnect:
      case WearableSource.googleHealth:
        return Icons.hub_rounded;
      case WearableSource.appleHealth:
        return Icons.favorite_rounded;
      case WearableSource.fitbit:
        return Icons.watch_rounded;
      case WearableSource.garmin:
      case WearableSource.strava:
        return Icons.directions_run_rounded;
      case WearableSource.oura:
      case WearableSource.whoop:
        return Icons.bedtime_rounded;
      default:
        return Icons.monitor_heart_rounded;
    }
  }
}

class _StatusFeedbackPill extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _StatusFeedbackPill({
    required this.message,
    required this.isError,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.orange.shade800 : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: DeviceStyles.syncResultDecorationColor(color),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              isError ? Icons.info_outline_rounded : Icons.check_circle_outline,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: color.withValues(alpha: 0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.radius(AppRadii.sm),
                      ),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
