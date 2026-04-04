 import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'viewer_3d_screen.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'widgets/ai_chat_panel.dart';

class ArtifactDetailScreen extends StatefulWidget {
  final String title;
  final String siteName; // e.g. "Found at Polonnaruwa"
  final String imagePath;
  final String timePeriod;
  final String material;
  final String dimensions;
  final String history;
  final List<String> quickFacts;
  final String? modelPath;

  const ArtifactDetailScreen({
    super.key,
    required this.title,
    required this.siteName,
    required this.imagePath,
    required this.timePeriod,
    required this.material,
    required this.dimensions,
    required this.history,
    required this.quickFacts,
    this.modelPath,
  });

  @override
  State<ArtifactDetailScreen> createState() => _ArtifactDetailScreenState();
}

class _ArtifactDetailScreenState extends State<ArtifactDetailScreen> {
  bool _historyExpanded = true;
  bool _factsExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Artifact Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.ios_share_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      // TODO: share
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 3D preview + controls
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Square preview area
                           ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                color: Colors.black.withOpacity(0.35),
                                child: (widget.modelPath != null && widget.modelPath!.isNotEmpty)
                                    ? ModelViewer(
                                        backgroundColor: Colors.transparent,
                                        src: widget.modelPath!,
                                        alt: "A 3D model of ${widget.title}",
                                        autoRotate: true,
                                        cameraControls: true,
                                        disableZoom: true,
                                      )
                                    : Image.asset(
                                        widget.imagePath,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Three control buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              const _ControlButton(
                                icon: Icons.restart_alt_rounded,
                                label: 'Reset',
                              ),
                              const _ControlButton(
                                icon: Icons.search_rounded,
                                label: 'Zoom',
                              ),
                              _ControlButton(
                                icon: Icons.fullscreen_rounded,
                                label: 'Full Screen',
                                onTap: () {
                                  if (widget.modelPath != null && widget.modelPath!.isNotEmpty) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => Viewer3DScreen(
                                          title: widget.title,
                                          modelPath: widget.modelPath!,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // View in full 3D button
                     SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (widget.modelPath != null && widget.modelPath!.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => Viewer3DScreen(
                                  title: widget.title,
                                  modelPath: widget.modelPath!,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("3D Model not available for this artifact yet."),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25C667),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'View in Full 3D',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ASK? button for AI Integration
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => AIChatPanel(
                              artifactTitle: widget.title,
                              history: widget.history,
                              quickFacts: widget.quickFacts,
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 20),
                        label: const Text(
                          'ASK?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.amber, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title & site link
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        // TODO: maybe navigate back to location details
                      },
                      child: Text(
                        widget.siteName,
                        style: const TextStyle(
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          color: Colors.white70,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stats row (Time period / Material / Dimensions)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding:
                              const EdgeInsets.only(right: 8.0), // space from divider
                              child: _InfoColumn(
                                icon: Icons.schedule_rounded,
                                label: 'Time Period',
                                value: widget.timePeriod,
                              ),
                            ),
                          ),
                          const _StatsDivider(),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0), // space both sides
                              child: _InfoColumn(
                                icon: Icons.landscape_rounded,
                                label: 'Material',
                                value: widget.material,
                              ),
                            ),
                          ),
                          const _StatsDivider(),
                          Expanded(
                            child: Padding(
                              padding:
                              const EdgeInsets.only(left: 8.0), // space from divider
                              child: _InfoColumn(
                                icon: Icons.straighten_rounded,
                                label: 'Dimensions',
                                value: widget.dimensions,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // History & Story
                    _ExpandableCard(
                      title: 'History & Story',
                      isExpanded: _historyExpanded,
                      onToggle: () {
                        setState(() {
                          _historyExpanded = !_historyExpanded;
                        });
                      },
                      child: Text(
                        widget.history,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Colors.white70,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Quick Facts
                    _ExpandableCard(
                      title: 'Quick Facts',
                      isExpanded: _factsExpanded,
                      onToggle: () {
                        setState(() {
                          _factsExpanded = !_factsExpanded;
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.quickFacts
                            .map(
                              (fact) => Padding(
                            padding:
                            const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    fact,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------- Small helper widgets -------------------------- */

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical divider between stats items
class _StatsDivider extends StatelessWidget {
  const _StatsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.12),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.white70,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandableCard extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  const _ExpandableCard({
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (_) => onToggle(),
          tilePadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
          const EdgeInsets.fromLTRB(16, 0, 16, 12),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }
}
