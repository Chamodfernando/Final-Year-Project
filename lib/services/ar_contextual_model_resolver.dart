import 'package:arcore_flutter_plus/arcore_flutter_plus.dart';

/// Picks which pre-resolved AR `.glb` path to load from [ArCoreHitTestResult.surfaceKind]
/// and camera-to-hit [ArCoreHitTestResult.distance] (meters along the view ray).
///
/// Optional Firestore paths (already resolved to `file://` / `https://` by
/// [SessionAssetCacheService]): [arClose], [arFar], [arWall], [arCeiling].
/// Any unset field falls back to [primaryAr].
class ArContextualModelResolver {
  ArContextualModelResolver._();

  /// Below this hit distance (m) → prefer [arClose] on horizontal / instant surfaces.
  static const double closeDistanceM = 0.55;

  /// At or above this hit distance (m) → prefer [arFar] on horizontal / instant surfaces.
  static const double farDistanceM = 1.8;

  static String pickResolvedPath({
    required ArCoreHitTestResult hit,
    required String primaryAr,
    String? arClose,
    String? arFar,
    String? arWall,
    String? arCeiling,
  }) {
    final k = hit.surfaceKind;
    final d = hit.distance;

    if (k == ArCoreSurfaceKind.vertical) {
      final w = _nonEmpty(arWall);
      if (w != null) return w;
    }
    if (k == ArCoreSurfaceKind.horizontalDown) {
      final c = _nonEmpty(arCeiling);
      if (c != null) return c;
    }

    if (k == ArCoreSurfaceKind.horizontalUp ||
        k == ArCoreSurfaceKind.instant ||
        k == ArCoreSurfaceKind.unknown) {
      final close = _nonEmpty(arClose);
      if (d < closeDistanceM && close != null) return close;
      final far = _nonEmpty(arFar);
      if (d >= farDistanceM && far != null) return far;
    }

    if (k == ArCoreSurfaceKind.vertical) {
      final close = _nonEmpty(arClose);
      if (d < closeDistanceM && close != null) return close;
      final far = _nonEmpty(arFar);
      if (d >= farDistanceM && far != null) return far;
    }

    return primaryAr;
  }

  static String? _nonEmpty(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static String describePlacement(ArCoreHitTestResult hit) {
    final k = hit.surfaceKind;
    final surface = switch (k) {
      ArCoreSurfaceKind.vertical => 'Wall',
      ArCoreSurfaceKind.horizontalUp => 'Floor / table',
      ArCoreSurfaceKind.horizontalDown => 'Ceiling',
      ArCoreSurfaceKind.instant => 'Surface (instant)',
      _ => 'Surface',
    };
    final d = hit.distance;
    return '$surface · ${d.toStringAsFixed(2)} m';
  }
}
