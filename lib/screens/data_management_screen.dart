import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/app_data_provider.dart';
import '../services/backup_service.dart';
import '../utils/safe_padding.dart';
import '../widgets/confirm_dialog.dart';

/// ডেটা ব্যবস্থাপনা — full-database JSON export/import (backup & restore).
/// An additional feature beyond the SRS, requested so the user can move
/// data between devices or keep a manual backup while Phase 1 has no
/// cloud sync.
class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  final _backupService = BackupService();
  bool _busy = false;
  String? _statusText;

  Future<void> _export(Strings s) async {
    setState(() {
      _busy = true;
      _statusText = s.dataExportingStatus;
    });
    try {
      await _backupService.exportAndShare(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.dataExportDone)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.dataExportFailed('$e'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(Strings s) async {
    setState(() {
      _busy = true;
      _statusText = s.dataReadingStatus;
    });
    try {
      final BackupPreview? preview;
      try {
        preview = await _backupService.pickBackupFile(s);
      } on FormatException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
        return;
      }
      if (preview == null) return; // cancelled
      if (!mounted) return;
      setState(() => _busy = false);

      final confirmed = await showConfirmDialog(
        context,
        title: s.dataReplaceTitle,
        message: s.dataReplaceMessage(
          preview.protisthanCount,
          preview.wardCount,
          preview.criteriaCount,
          preview.entryCount,
        ),
        confirmLabel: s.dataReplaceButton,
      );
      if (!confirmed || !mounted) return;

      setState(() {
        _busy = true;
        _statusText = s.dataRestoringLocalStatus;
      });
      await _backupService.restore(preview);
      if (!mounted) return;

      setState(() => _statusText = s.dataSyncingCloudStatus);
      await context.read<AppDataProvider>().refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.dataImportDone)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.dataImportFailed('$e'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.dataManagementTitle)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: safeBodyPadding(context),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.upload_file_outlined),
                        const SizedBox(width: 8),
                        Text(s.dataExportCardTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(s.dataExportCardBody),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.download_outlined),
                      label: Text(s.dataExportButton),
                      onPressed: _busy ? null : () => _export(s),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download_for_offline_outlined),
                        const SizedBox(width: 8),
                        Text(s.dataImportCardTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(s.dataImportCardBody),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_open_outlined),
                      label: Text(s.dataImportButton),
                      onPressed: _busy ? null : () => _import(s),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              if (_statusText != null) ...[
                const SizedBox(height: 12),
                Center(child: Text(_statusText!, textAlign: TextAlign.center)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
