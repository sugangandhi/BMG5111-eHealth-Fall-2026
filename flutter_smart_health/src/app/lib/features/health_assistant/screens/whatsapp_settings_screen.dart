import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/app_update_service.dart';

class WhatsAppSettingsScreen extends StatefulWidget {
  final VoidCallback? onChangeWhatsAppLine;
  final VoidCallback? onSyncNow;
  final VoidCallback? onProfileUpdated;

  const WhatsAppSettingsScreen({
    super.key,
    this.onChangeWhatsAppLine,
    this.onSyncNow,
    this.onProfileUpdated,
  });

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  String _userName = 'MaxAssist User';
  String _userPhone = '';
  String _ownerId = '';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = (prefs.getString('doctor_custom_name_v1') ??
              prefs.getString('patient_username') ??
              'MaxAssist User')
          .trim();
      _userPhone = (prefs.getString('doctor_whatsapp_phone_v1') ??
              prefs.getString('patient_phone') ??
              '')
          .trim();
      _ownerId = (prefs.getString('maxassist_device_owner_id_v1') ?? '').trim();
    });
  }

  Future<void> _editDisplayName() async {
    final ctrl = TextEditingController(text: _userName);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit Display Name', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Your Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF075E54),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('doctor_custom_name_v1', updated);
      await prefs.setString('patient_username', updated);
      if (mounted) {
        setState(() => _userName = updated);
        widget.onProfileUpdated?.call();
      }
    }
  }

  Future<void> _checkForAppUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final updater = AppUpdateService();
      final info = await updater.checkForUpdate();
      if (!mounted) return;
      if (info.isUpdateAvailable) {
        final install = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Update Available', style: TextStyle(fontWeight: FontWeight.w800)),
            content: Text(
              'MaxAssist ${info.remoteVersionName} is available.\n\n${info.releaseNotes}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A884),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Download & Install'),
              ),
            ],
          ),
        );
        if (install == true && mounted) {
          final res = await updater.downloadAndInstallUpdate(info);
          if (mounted && res.message.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res.message)),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are already on the latest version (${info.installed.displayLabel}).'),
            backgroundColor: const Color(0xFF075E54),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _logOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Log Out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'You will return to the WhatsApp Login screen. Your chats stay safely backed up in AWS under your registered phone number.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('whatsapp_logged_in_v1', false);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'M';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: ListView(
        children: [
          // Profile Header (WhatsApp Settings style)
          InkWell(
            onTap: _editDisplayName,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFE2F5EE),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF075E54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111B21),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _userPhone.isNotEmpty
                              ? 'User ID: +$_userPhone'
                              : 'Tap to edit display name',
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF667781)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, color: Color(0xFF075E54), size: 20),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          ListTile(
            leading: const Icon(Icons.verified_rounded, color: Color(0xFF075E54)),
            title: const Text('WhatsApp Account', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              _userPhone.isNotEmpty ? '+$_userPhone • AWS Cloud Sync Active' : 'Not linked',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF667781)),
            ),
            onTap: () {
              Navigator.pop(context);
              widget.onChangeWhatsAppLine?.call();
            },
          ),

          ListTile(
            leading: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF075E54)),
            title: const Text('Sync Chats from AWS', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              _ownerId.isNotEmpty ? 'Account Key: $_ownerId' : 'Refresh contacts and history',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF667781)),
            ),
            onTap: () {
              Navigator.pop(context);
              widget.onSyncNow?.call();
            },
          ),

          ListTile(
            leading: _checkingUpdate
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF075E54)),
                  )
                : const Icon(Icons.system_update_rounded, color: Color(0xFF075E54)),
            title: const Text('Check for App Updates', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text(
              'Download latest MaxAssist Android build',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF667781)),
            ),
            onTap: _checkForAppUpdate,
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            title: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
            ),
            subtitle: const Text(
              'Sign out and switch WhatsApp phone number',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF667781)),
            ),
            onTap: _logOut,
          ),
        ],
      ),
    );
  }
}
