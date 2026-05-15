import 'package:flutter/material.dart';

import 'widgets/ai_chat_panel.dart';

/// General heritage Q&A (not tied to a single artifact).
///
/// Single-surface chat UI (no duplicate app bar). Pass [onCloseToHome] from
/// [MainShellScreen] so close reliably returns to HOME.
class HeritageAiGuideScreen extends StatelessWidget {
  const HeritageAiGuideScreen({super.key, this.onCloseToHome});

  final VoidCallback? onCloseToHome;

  static const Color _forest = Color(0xFF0C3B2E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _forest,
      body: SafeArea(
        child: AIChatPanel(
          embedAsFullPage: true,
          onDismiss: onCloseToHome,
          artifactTitle: 'Sri Lankan heritage',
          history:
              'Ceylon Trails covers temples, fortresses, ancient cities, and living traditions across the island. '
              'Ask about sites, history, travel tips, or how to use the app.',
          quickFacts: const [
            'Cultural Triangle: Sigiriya, Polonnaruwa, Anuradhapura, Kandy',
            'Many entries include 3D artifacts and AR where supported',
            'Use Places to browse by city',
          ],
        ),
      ),
    );
  }
}
