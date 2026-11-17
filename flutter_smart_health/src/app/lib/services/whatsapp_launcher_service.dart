import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppDetectionResult {
  final bool hasRegular;
  final bool hasBusiness;

  const WhatsAppDetectionResult({
    required this.hasRegular,
    required this.hasBusiness,
  });

  bool get hasMultiple => hasRegular && hasBusiness;
  bool get hasAny => hasRegular || hasBusiness;
}

class WhatsAppLauncherService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.smart_health_app/whatsapp_launcher',
  );

  static const String prefKey = 'preferred_whatsapp_package';
  static const String pkgRegular = 'com.whatsapp';
  static const String pkgBusiness = 'com.whatsapp.w4b';

  static bool get isAndroidNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<WhatsAppDetectionResult> detectInstalledApps() async {
    if (!isAndroidNative) {
      return const WhatsAppDetectionResult(hasRegular: false, hasBusiness: false);
    }
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('detectWhatsAppApps');
      if (res != null) {
        return WhatsAppDetectionResult(
          hasRegular: res['hasRegular'] == true,
          hasBusiness: res['hasBusiness'] == true,
        );
      }
    } catch (_) {}
    return const WhatsAppDetectionResult(hasRegular: false, hasBusiness: false);
  }

  static Future<Map<String, String>?> pickDeviceContact() async {
    if (!isAndroidNative) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('pickContact');
      if (res != null) {
        final name = (res['name'] ?? '').toString().trim();
        final rawPhone = (res['phone'] ?? '').toString().trim();
        final phone = rawPhone.replaceAll(RegExp(r'\D'), '');
        if (phone.isNotEmpty) {
          return {
            'name': name.isNotEmpty ? name : 'Contact ($phone)',
            'phone': phone,
            'rawPhone': rawPhone,
          };
        }
      }
    } catch (e) {
      debugPrint('[WhatsAppLauncherService] pickDeviceContact error: $e');
    }
    return null;
  }

  static Future<bool> launchDirectPackage({
    required String package,
    String phone = '16134045586',
    String message = '',
  }) async {
    if (!isAndroidNative) {
      return fallbackLaunchWeb(phone: phone, message: message);
    }
    try {
      final success = await _channel.invokeMethod<bool>('launchWhatsAppPackage', {
        'package': package,
        'phone': phone,
        'text': message,
      });
      if (success == true) return true;
    } catch (_) {}
    return fallbackLaunchWeb(phone: phone, message: message);
  }

  static Future<bool> fallbackLaunchWeb({
    String phone = '16134045586',
    String message = '',
  }) async {
    final encoded = Uri.encodeComponent(message);
    final webUri = Uri.parse('https://wa.me/$phone?text=$encoded');
    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(webUri);
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> launchWhatsApp({
    required BuildContext context,
    String phone = '16134045586',
    String message = '',
  }) async {
    if (!isAndroidNative) {
      await fallbackLaunchWeb(phone: phone, message: message);
      return;
    }

    final detection = await detectInstalledApps();

    // 1. If only Business is installed
    if (detection.hasBusiness && !detection.hasRegular) {
      await launchDirectPackage(package: pkgBusiness, phone: phone, message: message);
      return;
    }

    // 2. If only Regular is installed
    if (detection.hasRegular && !detection.hasBusiness) {
      await launchDirectPackage(package: pkgRegular, phone: phone, message: message);
      return;
    }

    // 3. If neither is explicitly detected by package manager
    if (!detection.hasAny) {
      await fallbackLaunchWeb(phone: phone, message: message);
      return;
    }

    // 4. BOTH are installed: check saved preference
    final prefs = await SharedPreferences.getInstance();
    final savedPref = prefs.getString(prefKey);
    if (savedPref == pkgBusiness || savedPref == pkgRegular) {
      await launchDirectPackage(package: savedPref!, phone: phone, message: message);
      return;
    }

    // 5. Prompt user with App Chooser modal
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool remember = true;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    "Choose WhatsApp App",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "You have both WhatsApp apps installed. Which one do you want to use for clinic chat?",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  // WhatsApp Business Option
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.green.shade300),
                    ),
                    tileColor: const Color(0xFFF0FDF4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF25D366),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 20),
                    ),
                    title: const Text(
                      "WhatsApp Business",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    subtitle: const Text(
                      "Recommended for Clinic & Doctor consultations",
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF166534)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (remember) {
                        await prefs.setString(prefKey, pkgBusiness);
                      }
                      await launchDirectPackage(package: pkgBusiness, phone: phone, message: message);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Regular WhatsApp Option
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    tileColor: const Color(0xFFF8FAFC),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                    ),
                    title: const Text(
                      "WhatsApp Messenger",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    subtitle: const Text(
                      "Standard personal WhatsApp account",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (remember) {
                        await prefs.setString(prefKey, pkgRegular);
                      }
                      await launchDirectPackage(package: pkgRegular, phone: phone, message: message);
                    },
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: remember,
                    title: const Text(
                      "Remember my choice for future chats",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) {
                      setModalState(() {
                        remember = val ?? true;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> resetPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKey);
  }
}
