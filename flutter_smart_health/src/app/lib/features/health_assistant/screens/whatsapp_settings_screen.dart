import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_language_controller.dart';
import '../../../services/app_update_service.dart';

class WhatsAppSettingsScreen extends StatefulWidget {
  final VoidCallback? onChangeWhatsAppLine;
  final VoidCallback? onSyncNow;
  final VoidCallback? onProfileUpdated;
  final bool embedded;

  const WhatsAppSettingsScreen({
    super.key,
    this.onChangeWhatsAppLine,
    this.onSyncNow,
    this.onProfileUpdated,
    this.embedded = false,
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
    final s = AppStrings.of(context);
    final ctrl = TextEditingController(text: _userName);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(s.editDisplayName, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: s.yourName,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF075E54),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(s.save),
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

  Future<void> _showLanguagePicker() async {
    final s = AppStrings.of(context);
    final currentCode = AppLanguageController.instance.languageCode;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        Widget option(String code, String title, String subtitle) {
          final active = currentCode == code;
          return ListTile(
            leading: Icon(
              active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: active ? const Color(0xFF00A884) : const Color(0xFF94A3B8),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: const Color(0xFF111B21),
              ),
            ),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF667781))),
            onTap: () => Navigator.pop(ctx, code),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    s.chooseLanguage,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                option('en', 'English', 'Default'),
                option('fr', 'Français', 'French'),
                option('ar', 'العربية', 'Arabic (RTL)'),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && selected != currentCode) {
      await AppLanguageController.instance.setLanguage(selected);
      if (mounted) setState(() {});
    }
  }

  Future<void> _checkForAppUpdate() async {
    if (_checkingUpdate) return;
    final s = AppStrings.of(context);
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
            title: Text(s.updateAvailable, style: const TextStyle(fontWeight: FontWeight.w800)),
            content: Text(
              'MaxAssist ${info.remoteVersionName}\n\n${info.releaseNotes}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.later)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A884),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.downloadAndInstall),
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
            content: Text('${s.alreadyLatestVersion} (${info.installed.displayLabel}).'),
            backgroundColor: const Color(0xFF075E54),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _logOut() async {
    final s = AppStrings.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(s.logOutTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.logOutConfirmText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.logOut),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('whatsapp_logged_in_v1', false);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'M';
    final langLabel = AppLanguageController.languageLabel(
      AppLanguageController.instance.languageCode,
    );

    final content = ListView(
      children: [
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              s.settings,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Color(0xFF075E54),
                letterSpacing: -0.4,
              ),
            ),
          ),
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
                          _userPhone.isNotEmpty ? '+$_userPhone' : s.editDisplayName,
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

          // Language Switcher (English / Français / العربية)
          ListTile(
            key: const Key('settings_language_tile'),
            leading: const Icon(Icons.language_rounded, color: Color(0xFF075E54)),
            title: Text(s.language, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(langLabel, style: const TextStyle(fontSize: 12.5, color: Color(0xFF667781))),
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            onTap: _showLanguagePicker,
          ),

          ListTile(
            leading: const Icon(Icons.verified_rounded, color: Color(0xFF075E54)),
            title: Text(s.whatsappAccount, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              _userPhone.isNotEmpty ? '+$_userPhone • ${s.cloudSyncActive}' : s.cloudSyncActive,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF667781)),
            ),
            onTap: () {
              if (!widget.embedded) Navigator.pop(context);
              widget.onChangeWhatsAppLine?.call();
            },
          ),

          ListTile(
            leading: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF075E54)),
            title: Text(s.syncChatsFromAws, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              _ownerId.isNotEmpty ? _ownerId : s.syncChats,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF667781)),
            ),
            onTap: () {
              if (!widget.embedded) Navigator.pop(context);
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
            title: Text(s.checkForUpdates, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              s.checkForUpdatesSub,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF667781)),
            ),
            onTap: _checkForAppUpdate,
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            title: Text(
              s.logOut,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
            ),
            subtitle: Text(
              s.logOutSub,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF667781)),
            ),
            onTap: _logOut,
          ),
        ],
      );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE6F1FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          s.settings,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F1FC), Color(0xFFF3F6FA), Color(0xFFFFFFFF)],
            stops: [0.0, 0.42, 1.0],
          ),
        ),
        child: content,
      ),
    );
  }
}
