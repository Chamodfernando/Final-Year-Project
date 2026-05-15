import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/user_profile_firestore_sync.dart';
import 'heritage_ai_guide_screen.dart';
import 'home_dashboard_screen.dart';
import 'locations.dart';
import 'profile_screen.dart';
import 'shell_nav.dart';

/// Post-login root: persistent HOME / MAP / AI / PROFILE bar on all main tabs.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellColors {
  static const Color forest = Color(0xFF0C3B2E);
  static const Color navActiveChip = Color(0xFF165040);
}

void _shellHapticTap() {
  HapticFeedback.selectionClick();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late final MainShellController _shell;

  @override
  void initState() {
    super.initState();
    _shell = MainShellController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UserProfileFirestoreSync.syncCurrentUser();
    });
  }

  @override
  void dispose() {
    _shell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: _shell,
      builder: (context, _) {
        return MainShellScope(
          controller: _shell,
          child: Scaffold(
            body: IndexedStack(
              index: _shell.tabIndex.clamp(0, 3),
              sizing: StackFit.expand,
              children: [
                const HomeDashboardScreen(),
                LocationsScreen(
                  key: ValueKey<int>(_shell.locationsKey),
                  initialSection: _shell.locationsSection,
                  initialCityFilter: _shell.locationsCityFilter,
                  focusPlacesCitySearch: _shell.locationsFocusSearch,
                  showHeritageBottomBar: false,
                  onRequestProfileTab: _shell.goProfile,
                ),
                HeritageAiGuideScreen(onCloseToHome: _shell.goHome),
                ProfileScreen(onBackToHome: _shell.goHome),
              ],
            ),
            bottomNavigationBar: Material(
              color: _MainShellColors.forest,
              elevation: 12,
              child: Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8 + bottomInset),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _ShellNavItem(
                        label: 'HOME',
                        icon: Icons.home_outlined,
                        selected: _shell.tabIndex == 0,
                        onTap: () {
                          _shellHapticTap();
                          _shell.goHome();
                        },
                      ),
                    ),
                    Expanded(
                      child: _ShellNavItem(
                        label: 'MAP',
                        icon: Icons.map_outlined,
                        selected: _shell.tabIndex == 1,
                        onTap: () {
                          _shellHapticTap();
                          _shell.showMapTab();
                        },
                      ),
                    ),
                    Expanded(
                      child: _ShellNavItem(
                        label: 'AI',
                        icon: Icons.auto_awesome_outlined,
                        selected: _shell.tabIndex == 2,
                        onTap: () {
                          _shellHapticTap();
                          _shell.goAi();
                        },
                      ),
                    ),
                    Expanded(
                      child: _ShellNavItem(
                        label: 'PROFILE',
                        icon: Icons.person_outline_rounded,
                        selected: _shell.tabIndex == 3,
                        onTap: () {
                          _shellHapticTap();
                          _shell.goProfile();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = Colors.white.withValues(alpha: 0.55);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _MainShellColors.navActiveChip : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : inactive,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: selected ? Colors.white : inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
