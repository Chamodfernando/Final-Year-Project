import 'package:vector_math/vector_math_64.dart';

import 'arcore_pose.dart';

/// ARCore plane classification from native tap (`surfaceKind`).
abstract final class ArCoreSurfaceKind {
  static const horizontalUp = 'horizontal_up';
  static const horizontalDown = 'horizontal_down';
  static const vertical = 'vertical';
  static const instant = 'instant';
  static const unknown = 'unknown';
}

class ArCoreHitTestResult {
  late double distance;

  late Vector3 translation;

  late Vector4 rotation;

  late String nodeName;

  late ArCorePose pose;

  /// [Plane.Type] ordinal from ARCore, or `-1` for instant / unknown.
  int planeTypeOrdinal = -1;

  /// One of [ArCoreSurfaceKind] values.
  String surfaceKind = ArCoreSurfaceKind.unknown;

  ArCoreHitTestResult.fromMap(Map<dynamic, dynamic> map) {
    distance = (map['distance'] as num).toDouble();
    pose = ArCorePose.fromMap(map['pose'] as Map<dynamic, dynamic>);
    translation = pose.translation;
    rotation = pose.rotation;
    nodeName = map['name']?.toString() ?? '';
    final po = map['planeTypeOrdinal'];
    if (po is int) {
      planeTypeOrdinal = po;
    } else if (po is num) {
      planeTypeOrdinal = po.toInt();
    }
    final sk = map['surfaceKind'];
    if (sk is String && sk.isNotEmpty) {
      surfaceKind = sk;
    }
  }
}
