import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';   // ⬅️ NEW
import 'app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                'Profile and Settings',
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
                              const Text(
                                'Profile & Settings',
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
                              'Explorer since $explorerYear',
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
                          title: 'Saved Places',
                          onTap: () {
                            // TODO: navigate to saved places
                          },
                        ),
                        _SettingsRow(
                          icon: Icons.palette_outlined,
                          iconBg: const Color(0xFFE7F2EA),
                          iconColor: AppColors.primaryGreen,
                          title: 'Saved Artifacts',
                          onTap: () {
                            // TODO: navigate to saved artifacts
                          },
                        ),

                        const SizedBox(height: 16),

                        // APP SETTINGS
                        Text(
                          'APP SETTINGS',
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
                          title: 'Download Offline Content',
                          onTap: () {
                            // TODO
                          },
                        ),
                        _SettingsRow(
                          icon: Icons.language_rounded,
                          iconBg: const Color(0xFFE7F2EA),
                          iconColor: AppColors.primaryGreen,
                          title: 'Language',
                          subtitle: 'English / සිංහල / தமிழ்',
                          onTap: () {
                            // TODO
                          },
                        ),

                        const SizedBox(height: 16),

                        // ACCOUNT
                        Text(
                          'ACCOUNT',
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
                          title: 'Notifications',
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
                          title: 'Log Out',
                          titleColor: const Color(0xFFD4453A),
                          showDivider: false,
                          onTap: () async {
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
