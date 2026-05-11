import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'app_colors.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Top small label
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        l10n.welcomeToApp,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontSize: 12,
                          color: AppColors.subtleText,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Center logo + title + subtitle
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: constraints.maxHeight * 0.20,
                        child: Center(
                          child: Image.asset(
                            'assets/images/ceylon_trails_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'CEYLON TRAILS',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.discoverTagline,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: AppColors.subtleText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  _BottomSection(l10n: l10n),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BottomSection extends StatefulWidget {
  const _BottomSection({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_BottomSection> createState() => _BottomSectionState();
}

class _BottomSectionState extends State<_BottomSection> {
  bool _guestBusy = false;

  void _goToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  /// Firestore rules often require `request.auth != null`. Guest had no user on
  /// physical devices → permission denied / empty reads; emulator sometimes had
  /// a leftover session. Anonymous sign-in gives every guest a stable UID.
  ///
  /// [signInAnonymously] can hang on bad networks or iOS keychain / Play Services
  /// issues — always time out and still open the dashboard.
  Future<void> _goToDashboardAsGuest(BuildContext context) async {
    if (_guestBusy) return;
    setState(() => _guestBusy = true);
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        try {
          await auth
              .signInAnonymously()
              .timeout(const Duration(seconds: 12));
        } on FirebaseAuthException catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Anonymous guest sign-in failed (${e.code}). '
                  'Enable Anonymous in Firebase Auth if lists stay empty. Opening app anyway…',
                ),
                duration: const Duration(seconds: 6),
              ),
            );
          }
        } on TimeoutException {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Sign-in is taking too long (network or Firebase). '
                  'Opening the app anyway — try again or check Wi‑Fi.',
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Guest sign-in skipped: $e'),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not continue as guest: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _guestBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Get Started button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _guestBusy ? null : () => _goToLogin(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                l10n.getStarted,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Continue as Guest button
          SizedBox(
            width: 220,
            height: 48,
            child: OutlinedButton(
              onPressed: _guestBusy ? null : () => _goToDashboardAsGuest(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                side: BorderSide(
                  color: AppColors.primaryGreen.withOpacity(0.4),
                  width: 1.2,
                ),
              ),
              child: _guestBusy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : Text(
                      l10n.continueAsGuest,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
