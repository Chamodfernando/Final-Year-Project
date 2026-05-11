import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'app_colors.dart';
import 'ar_view_screen.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'services/ar_model_path_resolver.dart';
import 'services/voice_narration_settings.dart';
import 'services/voice_narration_service.dart';
import 'services/session_asset_cache_service.dart';
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
  /// Optional AR-only glb (Firestore `modelPathAr`). Otherwise bundled `*_ar.glb` is used when present.
  final String? modelPathAr;
  final String? modelPathArClose;
  final String? modelPathArFar;
  final String? modelPathArWall;
  final String? modelPathArCeiling;

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
    this.modelPathAr,
    this.modelPathArClose,
    this.modelPathArFar,
    this.modelPathArWall,
    this.modelPathArCeiling,
  });

  @override
  State<ArtifactDetailScreen> createState() => _ArtifactDetailScreenState();
}

class _ArtifactDetailScreenState extends State<ArtifactDetailScreen> {
  bool _historyExpanded = true;
  bool _factsExpanded = false;
  bool _showModelFullscreen = false;
  bool _isNarrating = false;
  bool _isNarrationPaused = false;
  final GlobalKey _modelViewerKey = GlobalKey();
  final VoiceNarrationService _voiceNarrationService = VoiceNarrationService();
  String? _resolvedModelSrc;
  String? _resolvedArModelSrc;
  String? _resolvedArClose;
  String? _resolvedArFar;
  String? _resolvedArWall;
  String? _resolvedArCeiling;
  ImageProvider? _resolvedImageProvider;
  bool _isAssetLoading = true;
  /// Native WebView (hybrid composition) can paint for ~1s over the route below
  /// while popping; remove [ModelViewer] from the tree one frame before [Navigator.pop].
  bool _stripModelViewerForExit = false;
  bool get _hasModel => widget.modelPath != null && widget.modelPath!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _warmUpCachedAssets();
    _voiceNarrationService.setStateListener((state) {
      if (!mounted) return;
      setState(() {
        _isNarrating = state == VoiceNarrationState.speaking;
        _isNarrationPaused = state == VoiceNarrationState.paused;
      });
    });
  }

  Future<String?> _resolveAndPrefetchArOptional(String? raw) async {
    if (raw == null || raw.trim().isEmpty) return null;
    final r =
        await SessionAssetCacheService.instance.resolveModelSource(raw.trim());
    unawaited(ArModelPathResolver.prefetchForArIfAndroid(r));
    return r;
  }

  Future<void> _warmUpCachedAssets() async {
    ImageProvider? imageProvider;
    try {
      imageProvider = await SessionAssetCacheService.instance
          .resolveImageProvider(widget.imagePath);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('resolveImageProvider failed: $e\n$st');
      }
    }
    String? modelSrc;
    String? arSrc;
    String? arClose;
    String? arFar;
    String? arWall;
    String? arCeiling;
    if (_hasModel) {
      try {
        modelSrc = await SessionAssetCacheService.instance
            .resolveModelSourceForModelViewer(widget.modelPath!);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('resolveModelSourceForModelViewer failed: $e\n$st');
        }
        modelSrc = widget.modelPath!.trim();
      }
      try {
        arSrc = await ArModelPathResolver.resolveForAr(
          primaryPath: widget.modelPath!,
          modelPathAr: widget.modelPathAr,
        );
        unawaited(ArModelPathResolver.prefetchForArIfAndroid(arSrc));
        arClose = await _resolveAndPrefetchArOptional(widget.modelPathArClose);
        arFar = await _resolveAndPrefetchArOptional(widget.modelPathArFar);
        arWall = await _resolveAndPrefetchArOptional(widget.modelPathArWall);
        arCeiling = await _resolveAndPrefetchArOptional(widget.modelPathArCeiling);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('AR path resolve failed: $e\n$st');
        }
      }
    }
    if (!mounted) return;
    setState(() {
      if (imageProvider != null) {
        _resolvedImageProvider = imageProvider;
      }
      _resolvedModelSrc = modelSrc;
      _resolvedArModelSrc = arSrc;
      _resolvedArClose = arClose;
      _resolvedArFar = arFar;
      _resolvedArWall = arWall;
      _resolvedArCeiling = arCeiling;
      _isAssetLoading = false;
    });
  }

  Future<void> _openAr() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_hasModel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noModelForAr),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!mounted) return;

    final arPathForScreen = _resolvedArModelSrc ??
        _resolvedModelSrc ??
        widget.modelPath!;
    if (kDebugMode) {
      final usingArOverride = widget.modelPathAr != null &&
          widget.modelPathAr!.trim().isNotEmpty &&
          _resolvedArModelSrc != null;
      debugPrint(
        'CeylonTrails AR: using ${usingArOverride ? "light (modelPathAr)" : "fallback"} '
        '→ $arPathForScreen',
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ARViewScreen(
          title: widget.title,
          modelPath: arPathForScreen,
          arModelClose: _resolvedArClose,
          arModelFar: _resolvedArFar,
          arModelWall: _resolvedArWall,
          arModelCeiling: _resolvedArCeiling,
          mode: ARExperienceMode.surfacePlacement,
        ),
      ),
    );
  }

  void _openFullscreen() {
    if (_hasModel) {
      setState(() => _showModelFullscreen = true);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageFullscreenScreen(
          title: widget.title,
          imagePath: widget.imagePath,
        ),
      ),
    );
  }

  /// Pops this route after removing the 3D platform view so it cannot "stick"
  /// on top of [LocationDetailScreen] during the transition (Android WebView).
  void _handleArtifactPop() {
    if (_showModelFullscreen) {
      setState(() => _showModelFullscreen = false);
      return;
    }
    setState(() => _stripModelViewerForExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  String _buildNarrationText() {
    final facts = widget.quickFacts.isEmpty
        ? ''
        : 'Quick facts: ${widget.quickFacts.join('. ')}.';
    return 'Here is the story of ${widget.title}. '
        '${widget.siteName}. '
        'It belongs to the ${widget.timePeriod} period. '
        'The primary material is ${widget.material}, '
        'with dimensions ${widget.dimensions}. '
        '${widget.history}. '
        '$facts';
  }

  Future<void> _toggleNarration() async {
    if (_isNarrating || _isNarrationPaused) {
      await _voiceNarrationService.stop();
      return;
    }

    final text = _buildNarrationText();
    try {
      final locale = await VoiceNarrationSettings.getLocale();
      final rate = await VoiceNarrationSettings.getRate();
      await _voiceNarrationService.speak(text, locale: locale, rate: rate);
    } catch (_) {}
  }

  Future<void> _togglePauseResumeNarration() async {
    if (_isNarrationPaused) {
      await _voiceNarrationService.resume();
      return;
    }
    if (_isNarrating) {
      await _voiceNarrationService.pause();
    }
  }

  @override
  void dispose() {
    _voiceNarrationService.stop();
    super.dispose();
  }

  Widget _buildReusableModelViewer() {
    if (_stripModelViewerForExit) {
      return ColoredBox(
        color: AppColors.primaryGreen,
        child: const SizedBox.expand(),
      );
    }
    final modelSrc = _resolvedModelSrc ?? widget.modelPath!;
    if (kDebugMode) {
      final s = modelSrc.trim();
      debugPrint(
        'CeylonModelViewer: ArtifactDetail ModelViewer src (${s.length} chars)='
        '${s.length > 100 ? '${s.substring(0, 100)}…' : s}',
      );
    }
    // `model_viewer_plus` serves `<model-viewer>` over loopback HTTP with bundled
    // JS and `/model` streaming `https`, `file://` (cached GLB), or assets.
    return ModelViewer(
      key: _modelViewerKey,
      backgroundColor: Colors.transparent,
      src: modelSrc,
      alt: "A 3D model of ${widget.title}",
      autoRotate: true,
      cameraControls: true,
      disableZoom: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleArtifactPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryGreen,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 4.0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: () => _handleArtifactPop(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.artifactDetails,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _isNarrationPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 22,
                            color: (_isNarrating || _isNarrationPaused)
                                ? Colors.amber
                                : Colors.white54,
                          ),
                          onPressed:
                              (_isNarrating || _isNarrationPaused)
                                  ? _togglePauseResumeNarration
                                  : null,
                        ),
                        IconButton(
                          icon: Icon(
                            (_isNarrating || _isNarrationPaused)
                                ? Icons.stop_circle_rounded
                                : Icons.volume_up_rounded,
                            size: 22,
                            color: (_isNarrating || _isNarrationPaused)
                                ? Colors.amber
                                : Colors.white,
                          ),
                          onPressed: _toggleNarration,
                        ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                                  clipBehavior: Clip.hardEdge,
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: ColoredBox(
                                      // Opaque: match [Scaffold] / app brand green; avoid transparent
                                      // platform-view compositing glitches on Android.
                                      color: AppColors.primaryGreen,
                                      child: _hasModel
                                          ? (_showModelFullscreen
                                              ? const SizedBox.shrink()
                                              : (_isAssetLoading
                                                  ? const Center(
                                                      child: CircularProgressIndicator(),
                                                    )
                                                  : _buildReusableModelViewer()))
                                          : (_resolvedImageProvider != null
                                              ? Image(
                                                  image: _resolvedImageProvider!,
                                                  fit: BoxFit.cover,
                                                )
                                              : const Center(
                                                  child: CircularProgressIndicator(),
                                                )),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    const _ControlButton(
                                      icon: Icons.restart_alt_rounded,
                                      label: 'Reset',
                                    ),
                                    const _ControlButton(
                                      icon: Icons.threed_rotation_rounded,
                                      label: 'Rotate',
                                    ),
                                    _ControlButton(
                                      icon: Icons.fullscreen_rounded,
                                      label: 'Full Screen',
                                      onTap: _openFullscreen,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_hasModel) {
                                  _openFullscreen();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "3D Model not available for this artifact yet.",
                                      ),
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
                              child: Text(
                                l10n.viewInFull3D,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openAr,
                              icon: const Icon(
                                Icons.view_in_ar_rounded,
                                color: Colors.white,
                              ),
                              label: Text(
                                l10n.openArCamera,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.white70,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                              icon: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.amber,
                                size: 20,
                              ),
                              label: Text(
                                l10n.ask,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.amber,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
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
                                    padding: const EdgeInsets.only(right: 8.0),
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
                                      horizontal: 8.0,
                                    ),
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
                                    padding: const EdgeInsets.only(left: 8.0),
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
                          _ExpandableCard(
                            title: l10n.historyAndStory,
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
                          _ExpandableCard(
                            title: l10n.quickFacts,
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
              if (_showModelFullscreen && _hasModel)
                Positioned.fill(
                  child: Container(
                    color: AppColors.primaryGreen,
                    child: SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 6.0,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => setState(
                                    () => _showModelFullscreen = false,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: _buildReusableModelViewer(),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 28),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Drag to rotate',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageFullscreenScreen extends StatefulWidget {
  final String title;
  final String imagePath;

  const _ImageFullscreenScreen({
    required this.title,
    required this.imagePath,
  });

  @override
  State<_ImageFullscreenScreen> createState() => _ImageFullscreenScreenState();
}

class _ImageFullscreenScreenState extends State<_ImageFullscreenScreen> {
  ImageProvider? _imageProvider;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final provider = await SessionAssetCacheService.instance.resolveImageProvider(
      widget.imagePath,
    );
    if (!mounted) return;
    setState(() => _imageProvider = provider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: _imageProvider == null
              ? const CircularProgressIndicator()
              : Image(image: _imageProvider!, fit: BoxFit.contain),
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
