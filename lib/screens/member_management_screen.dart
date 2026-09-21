import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/membership.dart';
import '../models/protisthan.dart';
import '../providers/app_data_provider.dart';
import '../services/cloud_sync_service.dart';
import '../utils/safe_padding.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';

/// সদস্য ব্যবস্থাপনা — একটি থানার members/ সাবকালেকশন দেখা, ইমেইল দিয়ে নতুন
/// সদস্য যোগ করা, রোল পরিবর্তন এবং সদস্য বাদ দেওয়া (FR: role-based access
/// control — creator/admin/collector/member)। সবাই তালিকা দেখতে পারে, কিন্তু
/// শুধু admin/creator অ্যাকশন (যোগ/রোল পরিবর্তন/বাদ) করতে পারবে — দেখুন
/// [ProtisthanRoleX.canManageUsers]।
class MemberManagementScreen extends StatefulWidget {
  final Protisthan protisthan;
  const MemberManagementScreen({super.key, required this.protisthan});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  final _cloud = CloudSyncService.instance;
  List<Membership> _members = [];
  bool _loading = true;

  ProtisthanRole? get _myRole => context.read<AppDataProvider>().roleFor(widget.protisthan);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final members = await _cloud.getMembers(widget.protisthan.uuid);
    String label(Membership m) => (m.displayName?.isNotEmpty == true ? m.displayName! : (m.email ?? m.uid)).toLowerCase();
    members.sort((a, b) {
      final byRole = a.role.index.compareTo(b.role.index);
      return byRole != 0 ? byRole : label(a).compareTo(label(b));
    });
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  bool _canManage(ProtisthanRole target) {
    final my = _myRole;
    if (my == null) return false;
    if (my == ProtisthanRole.creator) return target != ProtisthanRole.creator;
    if (my == ProtisthanRole.admin) {
      return target == ProtisthanRole.member || target == ProtisthanRole.collector;
    }
    return false;
  }

  List<ProtisthanRole> get _assignableRoles {
    if (_myRole == ProtisthanRole.creator) {
      return [ProtisthanRole.admin, ProtisthanRole.collector, ProtisthanRole.member];
    }
    return [ProtisthanRole.collector, ProtisthanRole.member];
  }

  Future<void> _addMember() async {
    final s = Strings.of(context);
    final result = await _showAddMemberDialog(s);
    if (result == null) return;
    final uid = await _cloud.findUidByEmail(result.email);
    if (!mounted) return;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.memberNoUserFound)),
      );
      return;
    }
    try {
      await _cloud.addOrUpdateMember(widget.protisthan.uuid, uid, result.role, email: result.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.memberAdded)),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<_AddMemberResult?> _showAddMemberDialog(Strings s) {
    final emailController = TextEditingController();
    var selectedRole = _assignableRoles.last;
    return showDialog<_AddMemberResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(s.addMemberTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 254,
                    decoration: InputDecoration(
                      labelText: s.memberEmailLabel,
                      hintText: 'user@example.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProtisthanRole>(
                    initialValue: selectedRole,
                    decoration: InputDecoration(labelText: s.memberRoleLabel),
                    items: _assignableRoles
                        .map((r) => DropdownMenuItem(value: r, child: Text(s.roleLabel(r))))
                        .toList(),
                    onChanged: (r) => setDialogState(() => selectedRole = r ?? selectedRole),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(s.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final email = emailController.text.trim();
                    if (!_isValidEmail(email)) return;
                    Navigator.of(dialogContext).pop(_AddMemberResult(email, selectedRole));
                  },
                  child: Text(s.addButton),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changeRole(Membership m) async {
    final s = Strings.of(context);
    final options = _myRole == ProtisthanRole.creator
        ? ProtisthanRole.values.where((r) => r != ProtisthanRole.creator).toList()
        : [ProtisthanRole.collector, ProtisthanRole.member];
    var selected = m.role;
    final newRole = await showDialog<ProtisthanRole>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(s.memberChangeRoleTitle(m.displayName ?? m.email ?? m.uid)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: options
                    .map(
                      (r) => RadioListTile<ProtisthanRole>(
                        title: Text(s.roleLabel(r)),
                        value: r,
                        // ignore: deprecated_member_use
                        groupValue: selected,
                        // ignore: deprecated_member_use
                        onChanged: (v) => setDialogState(() => selected = v ?? selected),
                      ),
                    )
                    .toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(s.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selected),
                  child: Text(s.save),
                ),
              ],
            );
          },
        );
      },
    );
    if (newRole == null || newRole == m.role) return;
    await _cloud.addOrUpdateMember(
      widget.protisthan.uuid,
      m.uid,
      newRole,
      email: m.email,
      displayName: m.displayName,
    );
    _load();
  }

  Future<void> _removeMember(Membership m) async {
    final s = Strings.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: s.memberRemoveTitle,
      message: s.memberRemoveMessage(m.displayName ?? m.email ?? m.uid),
    );
    if (!confirmed) return;
    await _cloud.removeMember(widget.protisthan.uuid, m.uid);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final canAdd = _myRole?.canManageUsers ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(s.memberManagementTitle(widget.protisthan.name))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? EmptyState(
                  icon: Icons.group_outlined,
                  message: s.emptyMembersMessage,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: safeBodyPadding(context, amount: 12, fab: canAdd),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final m = _members[index];
                      final manageable = _canManage(m.role);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(m.displayName?.isNotEmpty == true ? m.displayName! : (m.email ?? m.uid)),
                          subtitle: Text(m.email ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(label: Text(s.roleLabel(m.role))),
                              if (manageable)
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'role') _changeRole(m);
                                    if (value == 'remove') _removeMember(m);
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(value: 'role', child: Text(s.memberChangeRoleMenuItem)),
                                    PopupMenuItem(value: 'remove', child: Text(s.memberRemoveMenuItem)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: canAdd
          ? FloatingActionButton(onPressed: _addMember, child: const Icon(Icons.person_add_outlined))
          : null,
    );
  }
}

class _AddMemberResult {
  final String email;
  final ProtisthanRole role;
  const _AddMemberResult(this.email, this.role);
}

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool _isValidEmail(String email) => email.length <= 254 && _emailPattern.hasMatch(email);
