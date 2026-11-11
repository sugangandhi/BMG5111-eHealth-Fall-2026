import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_update_service.dart';
import '../../../services/e_hospital_service.dart';
import '../../../ui/ui.dart';
import '../presentation/profile_styles.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_info_row.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.fetchUsersTable,
    this.updateService,
  });

  final Future<List<dynamic>> Function()? fetchUsersTable;
  final AppUpdateService? updateService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _user;
  String? _errorMsg;
  late final AppUpdateService _updateService;
  AppVersionInfo _appVersion = const AppVersionInfo(versionName: '1.0.0', versionCode: 1);
  AppUpdateCheckResult? _updateCheck;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _updateService = widget.updateService ?? AppUpdateService();
    _loadProfile();
    _loadUpdateStatus();
  }

  Future<void> _loadUpdateStatus() async {
    if (!_updateService.isAndroidNative) return;
    final installed = await _updateService.getInstalledVersion();
    if (mounted) {
      setState(() => _appVersion = installed);
    }
    final check = await _updateService.checkForUpdate();
    if (mounted) {
      setState(() => _updateCheck = check);
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    final check = await _updateService.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      _updateCheck = check;
    });
    await showAppUpdateDialog(
      context,
      updateService: _updateService,
      checkResult: check,
    );
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final l10n = context.l10n;
    final rawId = prefs.get('patient_id');
    if (rawId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = l10n.profileNotLoggedIn;
        });
      }
      return;
    }
    final patientId = int.tryParse(rawId.toString());
    if (patientId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = l10n.profileInvalidPatientId;
        });
      }
      return;
    }

    try {
      final fetchUsers =
          widget.fetchUsersTable ?? () => EHospitalService.fetchTable('users');
      final data = await fetchUsers();
      final record = data.firstWhere((e) {
        final id = e["user_id"] ?? e["patient_id"];
        if (id == null) return false;
        return id is int
            ? id == patientId
            : id.toString() == patientId.toString();
      }, orElse: () => null);
      if (mounted) {
        setState(() {
          _user = record != null ? Map<String, dynamic>.from(record) : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = l10n.profileNetworkError(e.toString());
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final username = _user?["username"] as String?;
    final email = _user?["email"] as String?;
    final role = _user?["role"] as String?;
    final status = _user?["status"] as String?;
    final createdOn = _user?["created_on"] as String?;
    final userId =
        _user?["user_id"]?.toString() ?? _user?["patient_id"]?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileScreenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            onPressed: () => Navigator.pushNamed(context, "/settings"),
          ),
        ],
      ),
      body: _loading
          ? const LoadingStateView()
          : _errorMsg != null
          ? ErrorStateView(message: _errorMsg!)
          : _user == null
          ? EmptyStateView(message: l10n.profileNotFound)
          : SingleChildScrollView(
              child: Column(
                children: [
                  ProfileHeader(
                    username: username,
                    email: email,
                    role: role,
                    status: status,
                  ),
                  Padding(
                    padding: ProfileStyles.infoPadding,
                    child: Column(
                      children: [
                        ProfileInfoRow(
                          icon: Icons.badge_outlined,
                          label: l10n.patientIdLabel,
                          value: userId,
                        ),
                        ProfileInfoRow(
                          icon: Icons.person_outline,
                          label: l10n.usernameLabel,
                          value: username,
                        ),
                        ProfileInfoRow(
                          icon: Icons.email_outlined,
                          label: l10n.emailLabel,
                          value: email,
                        ),
                        ProfileInfoRow(
                          icon: Icons.verified_user_outlined,
                          label: l10n.roleLabel,
                          value: role,
                        ),
                        ProfileInfoRow(
                          icon: Icons.circle_outlined,
                          label: l10n.statusLabel,
                          value: status,
                        ),
                        ProfileInfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: l10n.memberSinceLabel,
                          value: createdOn,
                        ),
                        const SizedBox(height: 8),
                        _ProfileActionCard(
                          icon: Icons.settings_outlined,
                          title: l10n.settingsTitle,
                          subtitle: 'Notifications, AI model, and data sources',
                          onTap: () => Navigator.pushNamed(context, "/settings"),
                        ),
                        _ProfileActionCard(
                          icon: Icons.emergency_outlined,
                          title: l10n.emergencySosCardTitle,
                          subtitle: l10n.emergencySosCardSubtitle,
                          iconColor: Colors.red.shade600,
                          onTap: () => Navigator.pushNamed(context, "/emergency"),
                        ),
                        if (_updateService.isAndroidNative)
                          _ProfileActionCard(
                            icon: Icons.system_update_outlined,
                            title: 'App Updates',
                            subtitle: _updateCheck?.isUpdateAvailable == true
                                ? 'Update v${_updateCheck!.remoteVersionName} ready to install'
                                : 'Installed ${_appVersion.displayLabel} — check for updates',
                            highlight: _updateCheck?.isUpdateAvailable == true,
                            loading: _checkingUpdate,
                            onTap: _checkForUpdates,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final bool highlight;
  final bool loading;
  final VoidCallback onTap;

  const _ProfileActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.highlight = false,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        highlight ? Colors.green.shade700 : (iconColor ?? AppColors.primary);
    return Container(
      margin: ProfileStyles.rowMargin,
      decoration: ProfileStyles.infoRowDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.radius(AppRadii.dialog),
          onTap: loading ? null : onTap,
          child: Padding(
            padding: ProfileStyles.rowPadding,
            child: Row(
              children: [
                Container(
                  width: ProfileStyles.rowIconSize,
                  height: ProfileStyles.rowIconSize,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: AppRadii.radius(AppRadii.md),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                          color: highlight ? accent : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
