import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';   // ⬅️ NEW
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'app_colors.dart';
import 'services/app_locale_controller.dart';
import 'services/session_asset_cache_service.dart';
import 'services/voice_narration_settings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _narrationLocale = VoiceNarrationSettings.defaultLocale;
  double _narrationRate = VoiceNarrationSettings.defaultRate;

  @override
  void initState() {
    super.initState();
    _loadNarrationSettings();
  }

  Future<void> _loadNarrationSettings() async {
    final locale = await VoiceNarrationSettings.getLocale();
    final rate = await VoiceNarrationSettings.getRate();
    if (!mounted) return;
    setState(() {
      _narrationLocale = locale;
      _narrationRate = rate;
    });
  }

  Future<void> _openNarrationSettings() async {
    String selectedLocale = _narrationLocale;
    double selectedRate = _narrationRate;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.voiceNarrationSettings,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 14),
                  Text(l10n.narrationLanguage),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedLocale,
                    items: const [
                      DropdownMenuItem(value: 'en-US', child: Text('English')),
                      DropdownMenuItem(value: 'si-LK', child: Text('Sinhala')),
                      DropdownMenuItem(value: 'ta-LK', child: Text('Tamil')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => selectedLocale = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  Text('${l10n.narrationSpeed} (${selectedRate.toStringAsFixed(2)})'),
                  Slider(
                    value: selectedRate,
                    min: 0.30,
                    max: 0.70,
                    divisions: 8,
                    label: selectedRate.toStringAsFixed(2),
                    onChanged: (value) {
                      setModalState(() => selectedRate = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await VoiceNarrationSettings.setLocale(selectedLocale);
                        await VoiceNarrationSettings.setRate(selectedRate);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    await _loadNarrationSettings();
  }

  Future<void> _openAppLanguageSettings() async {
    String selectedLangCode = AppLocaleController.instance.locale.languageCode;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appLanguage,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedLangCode,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'si', child: Text('සිංහල')),
                      DropdownMenuItem(value: 'ta', child: Text('தமிழ்')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => selectedLangCode = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await AppLocaleController.instance.setLocale(Locale(selectedLangCode));
                        if (selectedLangCode == 'si') {
                          await VoiceNarrationSettings.setLocale('si-LK');
                        } else if (selectedLangCode == 'ta') {
                          await VoiceNarrationSettings.setLocale('ta-LK');
                        } else {
                          await VoiceNarrationSettings.setLocale('en-US');
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // ------- Read current Firebase user -------
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName != null &&
        user!.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : 'Explorer';

    // Fallback to email if no name at all
    final email = user?.email ?? '';

    // Creation time -> "Explorer since 2024"
    final created = user?.metadata.creationTime;
    final explorerYear = created?.year.toString() ?? '2024';

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Small label at the very top
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                l10n.profileAndSettings,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: AppColors.subtleText,
                ),
              ),
            ),

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 430),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top bar inside card: back + centered title
                        SizedBox(
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                    color: AppColors.primaryGreen,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                              Text(
                                l10n.profileSettingsTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Avatar + name + subtitle
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 110,
                              width: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.background,
                                border: Border.all(
                                  color: AppColors.primaryGreen.withOpacity(0.4),
                                  width: 3,
                                ),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/profile_avatar.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.explorerSince(explorerYear),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.subtleText.withOpacity(0.9),
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.subtleText.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 16),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.black.withOpacity(0.06),
                        ),
                        const SizedBox(height: 12),

                        // PERSONALIZATION
                        Text(
                          'PERSONALIZATION',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.subtleText.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 8),

                        _SettingsRow(
                          icon: Icons.bookmark_border_rounded,
                          iconBg: const Color(0xFFE7F2EA),
                          iconColor: AppColors.primaryGreen,
                          title: l10n.savedPlaces,
                          onTap: () {
                            // TODO: navigate to saved places
                          },
                        ),
                        _SettingsRow(
                          icon: Icons.palette_outlined,
                          iconBg: const Color(0xFFE7F2EA),
                          iconColor: AppColors.primaryGreen,
                          title: l10n.savedArtifacts,
                          onTap: () {
                            // TODO: navigate to saved artifacts
                          },
                        ),

                        const SizedBox(height: 16),

                        // APP SETTINGS
                        Text(
                          l10n.appSettings.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.subtleText.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 8),

                        _SettingsRow(
                          icon: Icons.download_for_offline_outlined,
                          iconBg: const Color(0xFFE7F2EA),
                          iconColor: AppColors.primaryGreen,
                          title: l10n.downloadOfflineContent,
                          onTap: () {
                            // TODO
                          },
                        ),
                        _SettingsRow(
                          icon: Icons.translate_rounded,
                          iconBg: const Color(0xFFE7F2EA),
                          iconColor: AppColors.primaryGreen,
                          title: l10n.appLanguage,
                          subtitle:
                              AppLocaleController.instance.locale.languageCode == 'si'
                                  ? 'සිංහල'
                                  : AppLocaleController.instance.locale.languageCode == 'ta'
                                  ? 'தமிழ்'
                                  : 'English',
                          onTap: _openAppLanguageSettings,
                        ),
                        _SettingsRow(
                          icon: Icons.language_rounded,
                          iconBg: const Color(0xFFE7F2EA),
                          iconColor: AppColors.primaryGreen,
                          title: l10n.voiceNarration,
                          subtitle:
                              '${_narrationLocale.replaceAll('-', ' ')} • speed ${_narrationRate.toStringAsFixed(2)}',
                          onTap: _openNarrationSettings,
                        ),

                        const SizedBox(height: 16),

                        // ACCOUNT
                        Text(
                          l10n.account.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.subtleText.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 8),

                        _SettingsRow(
                          icon: Icons.notifications_none_rounded,
                          iconBg: const Color(0xFFE7F2EA),
                          iconColor: AppColors.primaryGreen,
                          title: l10n.notifications,
                          onTap: () {
                            // TODO
                          },
                        ),

                        const SizedBox(height: 20),

                        // Log out row
                        _SettingsRow(
                          icon: Icons.logout_rounded,
                          iconBg: const Color(0xFFFCE9E7),
                          iconColor: const Color(0xFFD4453A),
                          title: l10n.logOut,
                          titleColor: const Color(0xFFD4453A),
                          showDivider: false,
                          onTap: () async {
                            await SessionAssetCacheService.instance.clearSessionCache();
                            await FirebaseAuth.instance.signOut();
                            // Go back to first route (loading / login)
                            // Adjust this if you have a named route setup.
                            // ignore: use_build_context_synchronously
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------- Helper row widget --------------------------- */

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final bool showDivider;
  final VoidCallback? onTap; // ⬅️ NEW

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.showDivider = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.subtleText.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.tabInactive,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.black.withOpacity(0.04),
          ),
      ],
    );
  }
}
