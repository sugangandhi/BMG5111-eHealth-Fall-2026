import 'package:file_selector/file_selector.dart';

import '../data/models/wearable_models.dart';
import 'wearable_sync_service.dart';

/// Shared file picker + uploader for Samsung Health CSV/ZIP, Apple Health XML,
/// Google Fit JSON/CSV, or generic health export files.
Future<WearableExportImportResult?> pickAndImportHealthExport({
  required WearableSyncService syncService,
  required String patientId,
  String? providerHint,
}) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Health App Exports',
        extensions: ['csv', 'xml', 'json', 'zip'],
        mimeTypes: [
          'text/csv',
          'application/csv',
          'text/xml',
          'application/xml',
          'application/json',
          'application/zip',
        ],
        uniformTypeIdentifiers: [
          'public.comma-separated-values-text',
          'public.xml',
          'public.json',
          'public.zip-archive',
          'public.data',
        ],
      ),
    ],
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw StateError('Selected file "${file.name}" is empty.');
  }

  return syncService.importExportFile(
    patientId: patientId,
    filename: file.name,
    bytes: bytes,
    provider: providerHint,
  );
}
