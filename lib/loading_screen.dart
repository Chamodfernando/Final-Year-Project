import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'login_screen.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                        'Welcome to CEYLON TRAILS',
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
                        "Discover Sri Lanka's heritage, one\ntrail at a time.",
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

                  const _BottomSection(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BottomSection extends StatelessWidget {
  const _BottomSection();

  void _goToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: () => _goToLogin(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Get Started',
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
              onPressed: () => _goToLogin(context),
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
              child: Text(
                'Continue as Guest',
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
