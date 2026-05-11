import 'dart:async';
import 'dart:io';
import 'dart:math' show pi;

import 'package:arcore_flutter_plus/arcore_flutter_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3, Vector4;

import 'services/ar_contextual_model_resolver.dart';
import 'services/ar_model_path_resolver.dart';

enum ARExperienceMode {
  surfacePlacement,
}

/// Real ARCore surface placement using Sceneform (Android only).
///
/// Tap a detected plane to anchor the artifact `.glb`. The previous placement
/// is removed when you tap again.
///
/// Optional [arModelClose] / [arModelFar] / [arModelWall] / [arModelCeiling] must
/// be **resolved** paths (same as [modelPath]) — see [ArtifactDetailScreen].
/// Native hit reports [ArCoreSurfaceKind] + distance to pick the variant per tap.
class ARViewScreen extends StatefulWidget {
  final String title;
  /// Default AR model (resolved URL or `file://`).
  final String modelPath;
  /// Tap distance &lt; ~0.55 m on floor-like surfaces (optional).
  final String? arModelClose;
  /// Tap distance ≥ ~1.8 m on floor-like surfaces (optional).
  final String? arModelFar;
  /// [ArCoreSurfaceKind.vertical] hits (optional).
  final String? arModelWall;
  /// [ArCoreSurfaceKind.horizontalDown] hits (optional).
  final String? arModelCeiling;
  final ARExperienceMode mode;

  const ARViewScreen({
    super.key,
    required this.title,
    required this.modelPath,
    this.arModelClose,
    this.arModelFar,
    this.arModelWall,
    this.arModelCeiling,
    required this.mode,
  });

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> with WidgetsBindingObserver {
  ArCoreController? _arController;
  String? _placedNodeName;
  String _status =
      'Point at desk or wall. Move slowly in a wide arc. You may see a faint grid (not always white dots). '
      'Brighten the room; aim at keyboard, cables, or wood grain for texture.';
  String? _error;
  bool _arCoreSupported = true;
  bool _arCoreInstalled = true;
  /// ARCore session is only created on the native side after camera permission
  /// is granted; we request it from Flutter first to avoid a stuck black view.
  bool _cameraReady = false;
  bool _cameraRequestDone = false;
  String? _object3DFileName;
  String? _objectUrl;
  bool _modelReady = false;
  bool _surfaceReady = false;
  int _planeDetectionCount = 0;
  /// Weighted score from plane updates (size + count) — helps weak / plain surfaces.
  double _planeTrackingScore = 0;
  DateTime? _arScanStartedAt;
  Timer? _surfaceGateTimer;
  DateTime? _lastPlacementAt;
  /// Last resolved source passed to Sceneform (skip redundant reload on repeat tap).
  String? _activeResolvedArSource;

  /// Placement pose (after tap) — used with [_placedYawRad] for live rotate/scale.
  Quaternion? _placedBaseRotation;
  double _placedYawRad = 0;
  double _placedUniformScale = 0.2;

  static const String _nodeName = 'ceylon_artifact_model';

  static const double _scaleAdjustFactor = 1.15;
  static const double _rotStepRad = pi / 12;

  /// Score needed before we call tracking “stable”. Lower = easier on basic surfaces.
  static const double _surfaceScoreTarget = 2.5;

  static const Duration _earlyUnlockAfter = Duration(seconds: 2);
  static const Duration _forceUnlockAfter = Duration(seconds: 5);

  double _computeInitialScaleFromHit(double distanceMeters) {
    // Distance-aware sizing so the model appears practical at first placement.
    // Close surfaces get smaller scale; farther surfaces get larger scale.
    final normalized = (distanceMeters / 1.8).clamp(0.0, 1.0);
    return (0.12 + (normalized * 0.16)).clamp(0.10, 0.30);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolveModelRefs(widget.modelPath);
    if (Platform.isAndroid) {
      _checkArCore();
      _requestCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _kickArResume();
    }
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _cameraRequestDone = true;
      _cameraReady = status.isGranted;
      if (!_cameraReady) {
        _status =
            'Camera permission is required for ARCore. Tap below to open settings.';
      }
    });
  }

  void _kickArResume() {
    // Native session is created in Activity.onResume; after permission / install
    // completes, poke resume again so the camera feed starts.
    try {
      _arController?.resume();
    } catch (_) {}
  }

  Future<void> _resolveModelRefs(String path) async {
    final trimmed = path.trim();
    _activeResolvedArSource = trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      _objectUrl = trimmed;
      _object3DFileName = null;
      if (kDebugMode) {
        debugPrint('CeylonTrails ARView: Sceneform will load GLB from URL → $trimmed');
      }
      if (mounted) {
        setState(() => _modelReady = true);
        _prewarmModelIfPossible();
      }
      return;
    }
    if (trimmed.startsWith('file://')) {
      final fileUri = Uri.parse(trimmed);
      final filePath = fileUri.toFilePath();
      final file = File(filePath);

      if (filePath.toLowerCase().endsWith('.glb') ||
          filePath.toLowerCase().endsWith('.gltf')) {
        _object3DFileName = trimmed;
      } else if (await file.exists()) {
        // `flutter_cache_manager` may store the GLB as `*.bin` if the
        // server doesn't provide a helpful content-type.
        // `arcore_flutter_plus` decides loader based on extension, so copy to
        // a temp `*.glb` file and pass that to ARCore.
        try {
          final tmpDir = await getTemporaryDirectory();
          // Stable name so native Sceneform cache + prefetch match the path used on tap.
          final copyPath =
              '${tmpDir.path}/ceylon_ar_${filePath.hashCode.abs()}.glb';
          await file.copy(copyPath);
          _object3DFileName = Uri.file(copyPath).toString();
        } catch (_) {
          // If copy fails, fall back to the original URI.
          _object3DFileName = trimmed;
        }
      } else {
        _object3DFileName = trimmed;
      }
      _objectUrl = null;
      if (mounted) {
        setState(() => _modelReady = true);
        _prewarmModelIfPossible();
      }
      return;
    }
    if (trimmed.startsWith('assets/')) {
      _object3DFileName =
          'file:///android_asset/flutter_assets/$trimmed';
      _objectUrl = null;
      if (mounted) {
        setState(() => _modelReady = true);
        _prewarmModelIfPossible();
      }
      return;
    }
    _object3DFileName =
        trimmed.startsWith('/') ? 'file://$trimmed' : 'file:///$trimmed';
    _objectUrl = null;
    if (mounted) {
      setState(() => _modelReady = true);
      _prewarmModelIfPossible();
    }
  }

  Future<void> _checkArCore() async {
    try {
      final installed = await ArCoreController.checkIsArCoreInstalled();
      final supported = await ArCoreController.checkArCoreAvailability();
      if (!mounted) return;
      setState(() {
        _arCoreInstalled = installed;
        _arCoreSupported = supported;
        if (!installed || !supported) {
          _status =
              'ARCore is required. Install / update Google Play Services for AR, '
              'then try again.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not check ARCore: $e');
    }
  }

  void _prewarmModelIfPossible() {
    final c = _arController;
    if (c == null || !_modelReady) return;
    final f = _object3DFileName;
    final u = _objectUrl;
    if (f == null && u == null) return;
    unawaited(
      c.prefetchReferenceModel(object3DFileName: f, objectUrl: u),
    );
  }

  void _prefetchOptionalArVariants() {
    for (final raw in <String?>[
      widget.arModelClose,
      widget.arModelFar,
      widget.arModelWall,
      widget.arModelCeiling,
    ]) {
      if (raw != null && raw.trim().isNotEmpty) {
        unawaited(ArModelPathResolver.prefetchForArIfAndroid(raw.trim()));
      }
    }
  }

  void _onArViewCreated(ArCoreController controller) {
    _arController = controller;
    _arScanStartedAt = DateTime.now();
    controller.onError = (msg) {
      if (!mounted) return;
      setState(() => _error = msg.toString());
    };
    controller.onPlaneTap = _onPlaneTap;
    controller.onPlaneDetected = _onPlaneDetected;
    _surfaceGateTimer?.cancel();
    _surfaceGateTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _maybeUnlockSurfaceByTime();
    });
    // Defer resume so the platform view has dimensions and permission state is settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kickArResume();
      Future<void>.delayed(const Duration(milliseconds: 250), _kickArResume);
      _prewarmModelIfPossible();
      _prefetchOptionalArVariants();
    });
  }

  void _markSurfaceReady(String reason) {
    if (!mounted || _surfaceReady) return;
    _surfaceGateTimer?.cancel();
    setState(() {
      _surfaceReady = true;
      if (reason == 'score') {
        _status =
            'Surface detected. Tap floor, table, or wall — closest surface wins. '
            'If this artifact has AR variants in Firebase, wall vs close vs far can load different .glbs.';
      } else if (reason == 'early') {
        _status =
            'Light tracking OK. Tap the surface — grid may be subtle; add light if taps miss.';
      } else {
        _status =
            'Try a tap on the desk. Use texture (keyboard, paper) if the view stays plain.';
      }
    });
  }

  void _maybeUnlockSurfaceByTime() {
    if (!mounted || _surfaceReady) {
      _surfaceGateTimer?.cancel();
      return;
    }
    final start = _arScanStartedAt;
    if (start == null) return;
    final elapsed = DateTime.now().difference(start);
    // Plain walls / low texture: fewer callbacks — allow tap after short scan if anything was seen.
    if (elapsed >= _earlyUnlockAfter && _planeDetectionCount >= 1) {
      _markSurfaceReady('early');
      return;
    }
    // Last resort: don’t block forever on difficult environments.
    if (elapsed >= _forceUnlockAfter) {
      _markSurfaceReady('force');
    }
  }

  void _onPlaneDetected(ArCorePlane plane) {
    if (!mounted) return;
    if (_surfaceReady) return;
    _planeDetectionCount += 1;
    final ex = plane.extendX ?? 0;
    final ez = plane.extendZ ?? 0;
    final area = ex * ez;
    // Bigger planes boost score faster; tiny updates still add 1 so basic surfaces accumulate.
    _planeTrackingScore += 1.0 + (area * 6).clamp(0, 2.5);

    if (_planeTrackingScore >= _surfaceScoreTarget || _planeDetectionCount >= 3) {
      _markSurfaceReady('score');
      return;
    }

    final pct = ((_planeTrackingScore / _surfaceScoreTarget) * 100).round().clamp(0, 99);
    setState(() {
      _status =
          'Finding surface… move slowly, add light, point at floor or wall ($pct%). '
          'Plain surfaces need a few seconds.';
    });
  }

  void _skipSurfaceWait() {
    _markSurfaceReady('force');
  }

  Future<void> _syncPlacedModelTransform() async {
    final controller = _arController;
    final name = _placedNodeName;
    final base = _placedBaseRotation;
    if (controller == null || name == null || base == null) return;
    final yaw = Quaternion.axisAngle(Vector3(0, 1, 0), _placedYawRad);
    final combined = (yaw * base).normalized();
    final rot = Vector4(combined.x, combined.y, combined.z, combined.w);
    final s = _placedUniformScale;
    try {
      await controller.updateNodeTransform(
        nodeName: name,
        scale: Vector3.all(s),
        rotation: rot,
      );
    } catch (_) {}
  }

  void _adjustPlacedScale(double factor) {
    if (_placedNodeName == null) return;
    _placedUniformScale =
        (_placedUniformScale * factor).clamp(0.03, 3.5);
    unawaited(_syncPlacedModelTransform());
  }

  void _adjustPlacedYaw(double deltaRad) {
    if (_placedNodeName == null) return;
    _placedYawRad += deltaRad;
    unawaited(_syncPlacedModelTransform());
  }

  Future<void> _onPlaneTap(List<ArCoreHitTestResult> hits) async {
    final controller = _arController;
    if (controller == null || hits.isEmpty) {
      if (mounted) {
        setState(() => _status = 'No surface hit. Aim at a floor or table.');
      }
      return;
    }

    if (!_surfaceReady) {
      if (mounted) {
        setState(
          () =>
              _status = 'Hold steady and scan a bit more before placing (surface not stable yet).',
        );
      }
      return;
    }

    final now = DateTime.now();
    if (_lastPlacementAt != null &&
        now.difference(_lastPlacementAt!).inMilliseconds < 700) {
      return;
    }
    _lastPlacementAt = now;

    final hit = hits.reduce((a, b) => a.distance <= b.distance ? a : b);
    try {
      final chosen = ArContextualModelResolver.pickResolvedPath(
        hit: hit,
        primaryAr: widget.modelPath,
        arClose: widget.arModelClose,
        arFar: widget.arModelFar,
        arWall: widget.arModelWall,
        arCeiling: widget.arModelCeiling,
      );
      final placementHint = ArContextualModelResolver.describePlacement(hit);

      if (_placedNodeName != null) {
        try {
          await controller.setLightweightSceneMode(false);
        } catch (_) {}
      }
      if (mounted) {
        setState(
          () => _status = 'Loading model… ($placementHint)',
        );
      }
      if (_placedNodeName != null) {
        await controller.removeNode(nodeName: _placedNodeName);
        _placedNodeName = null;
      }

      if (chosen != _activeResolvedArSource) {
        setState(() => _modelReady = false);
        await _resolveModelRefs(chosen);
      }

      if (!_modelReady || (_object3DFileName == null && _objectUrl == null)) {
        if (mounted) {
          setState(() => _status = 'Could not prepare model for this surface.');
        }
        return;
      }

      final node = ArCoreReferenceNode(
        name: _nodeName,
        object3DFileName: _object3DFileName,
        objectUrl: _objectUrl,
        position: hit.pose.translation,
        rotation: hit.pose.rotation,
        scale: Vector3.all(_computeInitialScaleFromHit(hit.distance)),
      );

      await controller.addArCoreNodeWithAnchor(node);
      _placedNodeName = _nodeName;
      _placedBaseRotation = Quaternion(
        hit.rotation.x,
        hit.rotation.y,
        hit.rotation.z,
        hit.rotation.w,
      ).normalized();
      _placedYawRad = 0;
      _placedUniformScale = _computeInitialScaleFromHit(hit.distance);
      await _syncPlacedModelTransform();
      try {
        await controller.setLightweightSceneMode(true);
      } catch (_) {}
      if (mounted) {
        setState(
          () => _status =
              'Model locked ($placementHint). Move around to inspect. Tap another surface to reposition.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not place model: $e');
      }
    }
  }

  Future<void> _clearPlacement() async {
    final controller = _arController;
    if (controller == null || _placedNodeName == null) return;
    try {
      await controller.removeNode(nodeName: _placedNodeName);
      _placedNodeName = null;
      _placedBaseRotation = null;
      _placedYawRad = 0;
      try {
        await controller.setLightweightSceneMode(false);
      } catch (_) {}
      if (mounted) {
        setState(() => _status = 'Placement cleared. Tap a surface to place again.');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _surfaceGateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Do not call _arController?.dispose() — this plugin can crash on dispose
    // when the platform view tears down.
    _arController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'ARCore is only available on supported Android devices.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!_arCoreInstalled || !_arCoreSupported) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_status, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _checkArCore,
                  child: const Text('Check again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_cameraRequestDone) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_cameraReady) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_status, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    await openAppSettings();
                    await _requestCamera();
                    _kickArResume();
                  },
                  child: const Text('Open settings'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _requestCamera();
                    _kickArResume();
                  },
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _clearPlacement,
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ArCoreView(
              type: ArCoreViewType.STANDARDVIEW,
              enablePlaneRenderer: true,
              enableTapRecognizer: true,
              enableUpdateListener: true,
              // Slightly tinted planes so basic surfaces are easier to see.
              planeColor: const Color(0x6640C4FF),
              debug: false,
              onArCoreViewCreated: _onArViewCreated,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.65),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? _status,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _error = null),
                        child: const Text('Dismiss'),
                      ),
                    ],
                    if (_error == null && !_surfaceReady) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _skipSurfaceWait,
                          child: const Text(
                            'Skip wait — try tap',
                            style: TextStyle(color: Colors.lightBlueAccent),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_placedNodeName != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Smaller',
                            onPressed: () =>
                                _adjustPlacedScale(1 / _scaleAdjustFactor),
                            icon: const Icon(Icons.zoom_out, color: Colors.white),
                          ),
                          IconButton(
                            tooltip: 'Larger',
                            onPressed: () => _adjustPlacedScale(_scaleAdjustFactor),
                            icon: const Icon(Icons.zoom_in, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Rotate left',
                            onPressed: () => _adjustPlacedYaw(_rotStepRad),
                            icon: const Icon(Icons.rotate_left, color: Colors.white),
                          ),
                          IconButton(
                            tooltip: 'Rotate right',
                            onPressed: () => _adjustPlacedYaw(-_rotStepRad),
                            icon: const Icon(Icons.rotate_right, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
