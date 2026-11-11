import 'package:flutter/material.dart';

import '../../services/app_update_service.dart';
import '../../ui/ui.dart';

Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppUpdateService updateService,
  required AppUpdateCheckResult checkResult,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _AppUpdateDialog(
      updateService: updateService,
      checkResult: checkResult,
    ),
  );
}

class _AppUpdateDialog extends StatefulWidget {
  final AppUpdateService updateService;
  final AppUpdateCheckResult checkResult;

  const _AppUpdateDialog({
    required this.updateService,
    required this.checkResult,
  });

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _statusMessage;

  Future<void> _startUpdate() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _statusMessage = 'Downloading v${widget.checkResult.remoteVersionName}...';
    });

    final result = await widget.updateService.downloadAndInstallUpdate(
      widget.checkResult,
      onProgress: (value) {
        if (mounted) {
          setState(() => _progress = value);
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _downloading = false;
      _statusMessage = result.message;
    });
    if (result.started) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.checkResult;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.radius(AppRadii.dialog)),
      title: Row(
        children: [
          const Icon(Icons.system_update_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              c.isUpdateAvailable ? 'App Update Available' : 'eHospital App Version',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Installed: ${c.installed.displayLabel}',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          if (c.remoteAvailable)
            Text(
              'Latest: v${c.remoteVersionName} (build ${c.remoteVersionCode})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            )
          else
            const Text(
              'No newer Android APK release is published yet.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          if (c.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              c.releaseNotes,
              style: const TextStyle(fontSize: 12, color: AppColors.textBody),
            ),
          ],
          if (_downloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          ],
          if (_statusMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _statusMessage!,
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (c.isUpdateAvailable)
          ElevatedButton.icon(
            onPressed: _downloading ? null : _startUpdate,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(_downloading ? 'Downloading...' : 'Update Now'),
          ),
      ],
    );
  }
}
