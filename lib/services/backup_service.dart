import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';

const int kBackupSchemaVersion = 1;

/// Full-database JSON backup/restore — an additional feature (beyond the
/// SRS) so the single user can move data between devices or keep a manual
/// backup, since Phase 1 has no cloud sync. Exports every table as-is
/// (including the stable uuid/timestamp columns from FR-7.3) so a restore
/// reproduces the exact same data.
class BackupService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<File> exportToFile() async {
    final tables = await _db.exportAllData();
    final payload = {
      'app': 'baytulmal_collection_tracker',
      'schema_version': kBackupSchemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'data': tables,
    };
    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${dir.path}/baytulmal_backup_$stamp.json');
    await file.writeAsString(jsonString, flush: true);
    return file;
  }

  Future<void> exportAndShare() async {
    final file = await exportToFile();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'বাইতুলমাল কালেকশন ট্র্যাকার — ডেটা ব্যাকআপ',
      ),
    );
  }

  /// Opens a file picker for the user to choose a `.json` backup file.
  /// Returns null if the user cancelled.
  Future<BackupPreview?> pickBackupFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = file?.path;
    if (path == null) return null;

    final content = await File(path).readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> || decoded['data'] is! Map) {
      throw const FormatException('এটি একটি বৈধ বাইতুলমাল ব্যাকআপ ফাইল নয়।');
    }
    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    for (final key in ['protisthan', 'criteria', 'ward', 'entry']) {
      if (data[key] is! List) {
        throw const FormatException('ব্যাকআপ ফাইলের গঠন সঠিক নয়।');
      }
    }
    return BackupPreview(
      data: data,
      protisthanCount: (data['protisthan'] as List).length,
      wardCount: (data['ward'] as List).length,
      criteriaCount: (data['criteria'] as List).length,
      entryCount: (data['entry'] as List).length,
      exportedAt: decoded['exported_at'] as String?,
    );
  }

  /// Replaces ALL local data with the previewed backup. Destructive —
  /// caller must confirm with the user first.
  Future<void> restore(BackupPreview preview) async {
    await _db.importAllData(preview.data);
  }
}

class BackupPreview {
  final Map<String, dynamic> data;
  final int protisthanCount;
  final int wardCount;
  final int criteriaCount;
  final int entryCount;
  final String? exportedAt;

  BackupPreview({
    required this.data,
    required this.protisthanCount,
    required this.wardCount,
    required this.criteriaCount,
    required this.entryCount,
    required this.exportedAt,
  });
}
