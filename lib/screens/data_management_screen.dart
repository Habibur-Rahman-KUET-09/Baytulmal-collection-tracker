import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';
import '../services/backup_service.dart';
import '../utils/bangla_utils.dart';
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

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _statusText = 'ব্যাকআপ ফাইল তৈরি হচ্ছে...';
    });
    try {
      await _backupService.exportAndShare();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ব্যাকআপ ফাইল তৈরি হয়েছে')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('এক্সপোর্ট ব্যর্থ হয়েছে: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _statusText = 'ব্যাকআপ ফাইল পড়া ও যাচাই করা হচ্ছে...';
    });
    try {
      final BackupPreview? preview;
      try {
        preview = await _backupService.pickBackupFile();
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
        title: 'বিদ্যমান ডেটা প্রতিস্থাপন করা হবে',
        message: 'এই ব্যাকআপ ফাইলে '
            '${BanglaMonths.toBanglaDigits(preview.protisthanCount)}টি থানা, '
            '${BanglaMonths.toBanglaDigits(preview.wardCount)}টি ওয়ার্ড, '
            '${BanglaMonths.toBanglaDigits(preview.criteriaCount)}টি খাত এবং '
            '${BanglaMonths.toBanglaDigits(preview.entryCount)}টি এন্ট্রি আছে।\n\n'
            'ইমপোর্ট করলে অ্যাপে বর্তমানে থাকা সকল ডেটা মুছে গিয়ে এই ব্যাকআপ দিয়ে প্রতিস্থাপিত হবে। '
            'এই কাজটি ফিরিয়ে নেওয়া যাবে না।',
        confirmLabel: 'প্রতিস্থাপন করুন',
      );
      if (!confirmed || !mounted) return;

      setState(() {
        _busy = true;
        _statusText = 'স্থানীয়ভাবে প্রতিস্থাপন করা হচ্ছে...';
      });
      await _backupService.restore(preview);
      if (!mounted) return;

      setState(() => _statusText = 'ক্লাউডে সিঙ্ক করা হচ্ছে...');
      await context.read<AppDataProvider>().refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ডেটা সফলভাবে ইমপোর্ট করা হয়েছে')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ইমপোর্ট ব্যর্থ হয়েছে: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ডেটা ব্যবস্থাপনা')),
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
                    const Row(
                      children: [
                        Icon(Icons.upload_file_outlined),
                        SizedBox(width: 8),
                        Text('ডেটা এক্সপোর্ট (Backup)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'সকল থানা, ওয়ার্ড, খাত ও এন্ট্রি ডেটা একটি JSON ফাইলে সংরক্ষণ করুন। '
                      'ফাইলটি শেয়ার করে অন্য ডিভাইসে বা নিরাপদ স্থানে রাখতে পারবেন।',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('ডেটা এক্সপোর্ট করুন'),
                      onPressed: _busy ? null : _export,
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
                    const Row(
                      children: [
                        Icon(Icons.download_for_offline_outlined),
                        SizedBox(width: 8),
                        Text('ডেটা ইমপোর্ট (Restore)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'পূর্বে এক্সপোর্ট করা একটি ব্যাকআপ (.json) ফাইল থেকে ডেটা ফিরিয়ে আনুন। '
                      'এটি অ্যাপের বর্তমান সকল ডেটা মুছে ব্যাকআপ দিয়ে প্রতিস্থাপন করবে। '
                      'ব্যাকআপের থানা যদি ক্লাউডে আগে থেকে না থাকে, ইমপোর্টের পর আপনি সাইন-ইন '
                      'থাকলে সেটি স্বয়ংক্রিয়ভাবে ক্লাউডে আপলোড হয়ে আপনি তার নির্মাতা হয়ে যাবেন।',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('ব্যাকআপ ফাইল বেছে নিন'),
                      onPressed: _busy ? null : _import,
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
