import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts the selected app language (`en`, `fr`, `ar`).
class AppLanguageController extends ValueNotifier<Locale> {
  AppLanguageController._() : super(const Locale('en'));

  static final AppLanguageController instance = AppLanguageController._();
  static const String _prefKey = 'maxassist_app_locale_v1';

  String get languageCode => value.languageCode;

  Future<void> loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = (prefs.getString(_prefKey) ?? 'en').trim().toLowerCase();
      if (saved == 'fr' || saved == 'ar' || saved == 'en') {
        value = Locale(saved);
      }
    } catch (_) {}
  }

  Future<void> setLanguage(String code) async {
    final normalized = (code == 'fr' || code == 'ar') ? code : 'en';
    value = Locale(normalized);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, normalized);
    } catch (_) {}
  }

  static String languageLabel(String code) {
    switch (code) {
      case 'fr':
        return 'Français';
      case 'ar':
        return 'العربية';
      default:
        return 'English';
    }
  }
}

/// Complete localized strings for the standalone MaxAssist WhatsApp app (EN, FR, AR).
class AppStrings {
  final String code;
  const AppStrings(this.code);

  static AppStrings of(BuildContext context) {
    final lc = Localizations.maybeLocaleOf(context)?.languageCode ??
        AppLanguageController.instance.languageCode;
    return AppStrings(lc);
  }

  static AppStrings get current =>
      AppStrings(AppLanguageController.instance.languageCode);

  String _t(String en, String fr, String ar) {
    switch (code) {
      case 'fr':
        return fr;
      case 'ar':
        return ar;
      default:
        return en;
    }
  }

  // Brand & Login
  String get appTitle => 'MaxAssist';
  String get loginSubtitle => _t(
        'WhatsApp AI Messaging & Voice Assistant',
        'Messagerie IA WhatsApp et assistant vocal',
        'مراسلة واتساب بالذكاء الاصطناعي والمساعد الصوتي',
      );
  String get signInWithWhatsApp => _t(
        'Sign in with WhatsApp',
        'Connexion avec WhatsApp',
        'تسجيل الدخول عبر واتساب',
      );
  String get loginDescription => _t(
        'Your WhatsApp phone number is registered as your User ID to sync your contacts and chat history.',
        'Votre numéro WhatsApp est enregistré comme identifiant utilisateur pour synchroniser vos contacts et discussions.',
        'يتم تسجيل رقم واتساب الخاص بك كمعرّف مستخدم لمزامنة جهات الاتصال وسجل المحادثات.',
      );
  String get yourName => _t('Your Name', 'Votre nom', 'اسمك');
  String get yourNameHint => _t('e.g. Dr. Sugan', 'ex. Dr Sugan', 'مثال: د. سوغان');
  String get whatsappPhoneNumber =>
      _t('WhatsApp Phone Number', 'Numéro WhatsApp', 'رقم هاتف واتساب');
  String get continueWithWhatsApp =>
      _t('Continue with WhatsApp', 'Continuer avec WhatsApp', 'المتابعة عبر واتساب');
  String get signingIn => _t('Signing in...', 'Connexion...', 'جارٍ تسجيل الدخول...');
  String get enterNameError =>
      _t('Please enter your name.', 'Veuillez entrer votre nom.', 'يرجى إدخال اسمك.');
  String get enterPhoneError => _t(
        'Please enter a valid WhatsApp phone number with country code.',
        'Veuillez entrer un numéro WhatsApp valide avec l\'indicatif du pays.',
        'يرجى إدخال رقم واتساب صحيح مع رمز الدولة.',
      );

  // Chat List & Menu
  String get askOrSearchHint => _t(
        'Ask MaxAssist AI or Search',
        'Demander à MaxAssist IA ou rechercher',
        'اسأل MaxAssist AI أو ابحث',
      );
  String get aiSubtitleDefault => _t(
        'Ask me to message contacts, send AI voice notes, or schedule',
        'Demandez-moi d\'envoyer un message, une note vocale IA ou de planifier',
        'اطلب مني مراسلة جهات الاتصال أو إرسال رسالة صوتية أو الجدولة',
      );
  String get noChatsYet => _t('No chats yet', 'Aucune discussion', 'لا توجد محادثات بعد');
  String noContactsMatch(String q) => _t(
        'No contacts match "$q"',
        'Aucun contact ne correspond à « $q »',
        'لا توجد جهات اتصال تطابق "$q"',
      );
  String get pressEnterToAskAi => _t(
        'Press Enter to ask MaxAssist AI directly.',
        'Appuyez sur Entrée pour demander directement à MaxAssist IA.',
        'اضغط Enter لسؤال MaxAssist AI مباشرة.',
      );
  String get tapPlusToAddContact => _t(
        'Tap the green + button below to add a contact from your phone or enter a number.',
        'Appuyez sur le bouton vert + ci-dessous pour ajouter un contact ou saisir un numéro.',
        'اضغط على الزر الأخضر + أدناه لإضافة جهة اتصال من هاتفك أو إدخال رقم.',
      );
  String get settings => _t('Settings', 'Paramètres', 'الإعدادات');
  String get manageContacts => _t('Manage Contacts', 'Gérer les contacts', 'إدارة جهات الاتصال');
  String get logOut => _t('Log Out', 'Déconnexion', 'تسجيل الخروج');
  String get syncChats => _t('Sync Chats', 'Synchroniser', 'مزامنة المحادثات');
  String get newChatAddContact =>
      _t('New Chat / Add Contact', 'Nouvelle discussion / Ajouter', 'محادثة جديدة / إضافة جهة اتصال');

  // MaxAssist AI Chat
  String get aiHeaderSubtitle => _t(
        'Text • AI Voice Notes • Scheduling',
        'Texte • Notes vocales IA • Planification',
        'رسائل نصية • رسائل صوتية ذكية • جدولة',
      );
  String get aiEmptyDescription => _t(
        'Type or use the mic to message any contact, send an AI voice note on WhatsApp, or schedule future reminders.',
        'Écrivez ou utilisez le micro pour envoyer un message, une note vocale IA sur WhatsApp ou planifier un rappel.',
        'اكتب أو استخدم الميكروفون لمراسلة أي جهة اتصال، أو إرسال رسالة صوتية ذكية على واتساب، أو جدولة التذكيرات.',
      );
  String get chipVoiceMsg =>
      _t('🎙️ Send voice message to...', '🎙️ Envoyer une note vocale à...', '🎙️ إرسال رسالة صوتية إلى...');
  String get chipSchedule =>
      _t('⏰ Schedule a reminder', '⏰ Planifier un rappel', '⏰ جدولة تذكير');
  String get chipShowTasks =>
      _t('📋 Show scheduled tasks', '📋 Voir les tâches planifiées', '📋 عرض المهام المجدولة');
  String get aiWorking => _t('MaxAssist AI is working...', 'MaxAssist IA travaille...', 'MaxAssist AI يعمل الآن...');
  String get aiComposerHint => _t(
        'Ask MaxAssist AI to text, voice note, or schedule...',
        'Demandez à MaxAssist IA d\'écrire, d\'envoyer un audio ou de planifier...',
        'اطلب من MaxAssist AI إرسال نص أو صوت أو جدولة...',
      );
  String get messageHint => _t('Message', 'Message', 'رسالة');
  String get clearAiChat => _t('Clear AI Chat', 'Effacer la discussion IA', 'مسح محادثة الذكاء الاصطناعي');
  String sendingTo(String name) => _t(
        'Sending to $name...',
        'Envoi à $name...',
        'جارٍ الإرسال إلى $name...',
      );

  // Add Contact Sheet & Dialogs
  String get addOrSelectContact =>
      _t('Add or Select Contact', 'Ajouter ou choisir un contact', 'إضافة أو اختيار جهة اتصال');
  String get addOrSelectSubtitle => _t(
        'Create a new contact or import directly from your phone\'s address book.',
        'Créez un nouveau contact ou importez-le depuis le répertoire de votre téléphone.',
        'أنشئ جهة اتصال جديدة أو استوردها مباشرة من دفتر عناوين هاتفك.',
      );
  String get createNewContact =>
      _t('Create New Contact', 'Créer un nouveau contact', 'إنشاء جهة اتصال جديدة');
  String get createNewContactSub => _t(
        'Enter contact name and phone number',
        'Entrez le nom et le numéro de téléphone',
        'أدخل اسم جهة الاتصال ورقم الهاتف',
      );
  String get selectFromPhoneContacts =>
      _t('Select from Phone Contacts', 'Choisir depuis les contacts', 'الاختيار من جهات اتصال الهاتف');
  String get selectFromPhoneSub => _t(
        'Import contact name, number, and photo from your phone',
        'Importer le nom, le numéro et la photo depuis votre téléphone',
        'استيراد الاسم والرقم والصورة من هاتفك',
      );
  String get contactsDirectory =>
      _t('Contacts Directory', 'Répertoire des contacts', 'دليل جهات الاتصال');
  String get contactsDirectorySub => _t(
        'Search, switch, or manage saved contacts',
        'Rechercher, changer ou gérer les contacts enregistrés',
        'البحث أو التبديل أو إدارة جهات الاتصال المحفوظة',
      );
  String get cancel => _t('Cancel', 'Annuler', 'إلغاء');
  String get save => _t('Save', 'Enregistrer', 'حفظ');
  String get saveAndSelect => _t('Save & Select', 'Enregistrer et ouvrir', 'حفظ وفتح');
  String get later => _t('Later', 'Plus tard', 'لاحقاً');

  // Settings & Updates
  String get editDisplayName =>
      _t('Edit Display Name', 'Modifier le nom affiché', 'تعديل اسم العرض');
  String get whatsappAccount => _t('WhatsApp Account', 'Compte WhatsApp', 'حساب واتساب');
  String get cloudSyncActive => _t('AWS Cloud Sync Active', 'Synchronisation AWS active', 'مزامنة سحابة AWS نشطة');
  String get language => _t('Language', 'Langue', 'اللغة');
  String get chooseLanguage => _t('Choose App Language', 'Choisir la langue', 'اختر لغة التطبيق');
  String get syncChatsFromAws =>
      _t('Sync Chats from AWS', 'Synchroniser depuis AWS', 'مزامنة المحادثات من AWS');
  String get checkForUpdates =>
      _t('Check for App Updates', 'Vérifier les mises à jour', 'التحقق من تحديثات التطبيق');
  String get checkForUpdatesSub => _t(
        'Download latest MaxAssist Android build',
        'Télécharger la dernière version Android de MaxAssist',
        'تنزيل أحدث إصدار أندرويد من MaxAssist',
      );
  String get updateAvailable =>
      _t('Update Available', 'Mise à jour disponible', 'يتوفر تحديث جديد');
  String get downloadAndInstall =>
      _t('Download & Install', 'Télécharger et installer', 'تنزيل وتثبيت');
  String get alreadyLatestVersion => _t(
        'You are already on the latest version',
        'Vous avez déjà la dernière version',
        'أنت تستخدم أحدث إصدار بالفعل',
      );
  String get logOutTitle => _t('Log Out?', 'Se déconnecter ?', 'تسجيل الخروج؟');
  String get logOutConfirmText => _t(
        'You will return to the WhatsApp Login screen. Your chats stay safely backed up in AWS under your registered phone number.',
        'Vous reviendrez à l\'écran de connexion WhatsApp. Vos discussions restent sauvegardées sur AWS sous votre numéro.',
        'ستعود إلى شاشة تسجيل الدخول. تبقى محادثاتك محفوظة بأمان في AWS تحت رقم هاتفك المسجل.',
      );
  String get logOutSub => _t(
        'Sign out and switch WhatsApp phone number',
        'Se déconnecter et changer de numéro WhatsApp',
        'تسجيل الخروج وتبديل رقم واتساب',
      );

  // 4-Tab WhatsApp Bottom Navigation
  String get tabChats => _t('Chats', 'Discussions', 'الدردشات');
  String get tabCalendar => _t('Calendar', 'Calendrier', 'التقويم');
  String get tabContacts => _t('Contacts', 'Contacts', 'جهات الاتصال');
  String get tabSettings => _t('Settings', 'Paramètres', 'الإعدادات');

  // Calendar / Schedule Tab
  String get scheduledMessages =>
      _t('Scheduled Messages', 'Messages planifiés', 'الرسائل المجدولة');
  String get scheduleNew => _t('Schedule', 'Planifier', 'جدولة');
  String get noScheduledYet => _t(
        'No scheduled messages yet',
        'Aucun message planifié',
        'لا توجد رسائل مجدولة بعد',
      );
  String get noScheduledSub => _t(
        'Ask MaxAssist AI to remind any contact at any time, or tap Schedule above.',
        'Demandez à MaxAssist IA de rappeler un contact, ou appuyez sur Planifier ci-dessus.',
        'اطلب من MaxAssist AI تذكير أي جهة اتصال، أو اضغط على جدولة أعلاه.',
      );
  String get statusPending => _t('PENDING', 'EN ATTENTE', 'قيد الانتظار');
  String get statusSent => _t('SENT', 'ENVOYÉ', 'تم الإرسال');
  String get statusCancelled => _t('CANCELLED', 'ANNULÉ', 'ملغى');

  // Contacts Tab
  String get importFromPhone => _t('Phone', 'Téléphone', 'الهاتف');
  String get addContactShort => _t('Add', 'Ajouter', 'إضافة');
  String get searchContactsHint =>
      _t('Search contacts...', 'Rechercher des contacts...', 'ابحث في جهات الاتصال...');
  String get noSavedContacts =>
      _t('No saved contacts yet', 'Aucun contact enregistré', 'لا توجد جهات اتصال محفوظة بعد');
}
