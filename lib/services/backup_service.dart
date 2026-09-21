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
    final Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(content);
      if (parsed is! Map<String, dynamic>) throw const FormatException();
      decoded = parsed;
    } on FormatException {
      throw const FormatException('এটি একটি বৈধ JSON ফাইল নয়।');
    }
    if (decoded['data'] is! Map) {
      throw const FormatException('এটি একটি বৈধ বাইতুলমাল ব্যাকআপ ফাইল নয়।');
    }
    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    for (final key in ['protisthan', 'criteria', 'ward', 'entry']) {
      if (data[key] is! List) {
        throw FormatException('ব্যাকআপ ফাইলের গঠন সঠিক নয় — "$key" তালিকা পাওয়া যায়নি।');
      }
    }
    _validateRows(data);
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

  /// Row-level structural + referential-integrity checks, run BEFORE
  /// [restore] ever deletes anything — a truncated/hand-edited/corrupt
  /// file should fail loudly here rather than wiping local data and then
  /// crashing (or silently inserting orphaned rows) partway through
  /// [DatabaseHelper.importAllData].
  void _validateRows(Map<String, dynamic> data) {
    List<Map> rows(String key) => (data[key] as List? ?? const [])
        .map((r) {
          if (r is! Map) throw FormatException('ব্যাকআপ ফাইলের "$key" তালিকায় অবৈধ সারি আছে।');
          return r;
        })
        .toList();

    Set<Object?> requireFields(List<Map> rows, String table, List<String> fields) {
      final ids = <Object?>{};
      for (final r in rows) {
        for (final f in fields) {
          if (r[f] == null) {
            throw FormatException('ব্যাকআপ ফাইলের "$table" টেবিলে "$f" ফিল্ড অনুপস্থিত।');
          }
        }
        if (r['uuid'] is! String || (r['uuid'] as String).isEmpty) {
          throw FormatException('ব্যাকআপ ফাইলের "$table" টেবিলে অবৈধ uuid আছে।');
        }
        ids.add(r['id']);
      }
      return ids;
    }

    void requireReference(List<Map> rows, String table, String field, Set<Object?> validIds) {
      for (final r in rows) {
        if (!validIds.contains(r[field])) {
          throw FormatException('ব্যাকআপ ফাইলের "$table" টেবিলে একটি সারি অস্তিত্বহীন "$field" নির্দেশ করছে।');
        }
      }
    }

    final protisthanRows = rows('protisthan');
    final criteriaRows = rows('criteria');
    final wardRows = rows('ward');
    final entryRows = rows('entry');
    final remittanceRows = data['remittance'] is List ? rows('remittance') : const <Map>[];

    final protisthanIds = requireFields(protisthanRows, 'protisthan', ['id', 'name', 'created_at']);
    final criteriaIds = requireFields(criteriaRows, 'criteria', ['id', 'protisthan_id', 'name', 'created_at']);
    final wardIds = requireFields(wardRows, 'ward', ['id', 'protisthan_id', 'name', 'created_at']);
    requireFields(entryRows, 'entry', ['id', 'ward_id', 'criteria_id', 'month', 'year', 'amount']);
    if (remittanceRows.isNotEmpty) {
      requireFields(remittanceRows, 'remittance', ['id', 'protisthan_id', 'month', 'year']);
    }

    requireReference(criteriaRows, 'criteria', 'protisthan_id', protisthanIds);
    requireReference(wardRows, 'ward', 'protisthan_id', protisthanIds);
    requireReference(entryRows, 'entry', 'ward_id', wardIds);
    requireReference(entryRows, 'entry', 'criteria_id', criteriaIds);
    if (remittanceRows.isNotEmpty) {
      requireReference(remittanceRows, 'remittance', 'protisthan_id', protisthanIds);
    }
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
