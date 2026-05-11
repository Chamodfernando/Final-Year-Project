import 'package:cloud_firestore/cloud_firestore.dart';

class Artifact {
  final String id;
  final String title;
  final String siteName;
  final String imagePath;
  final String timePeriod;
  final String material;
  final String dimensions;
  final String history;
  final List<String> quickFacts;
  final String? modelPath;
  /// Optional lighter `.glb` for ARCore (remote URL or `assets/...`). Falls back to [modelPath].
  final String? modelPathAr;
  /// Optional AR variants (same contract as [modelPathAr]). Chosen from plane type + tap distance.
  final String? modelPathArClose;
  final String? modelPathArFar;
  final String? modelPathArWall;
  final String? modelPathArCeiling;
  final String? markerImagePath;
  final double? markerPhysicalWidthMeters;
  /// Plain location doc id (also accepts DocumentReference in Firestore — normalized when parsing).
  final String locationId;

  Artifact({
    required this.id,
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
    this.markerImagePath,
    this.markerPhysicalWidthMeters,
    required this.locationId,
  });

  static String _str(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  static String? _strOrNull(dynamic v) {
    if (v == null) return null;
    if (v is String && v.trim().isEmpty) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String> _quickFacts(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    final one = v.toString().trim();
    return one.isEmpty ? [] : [one];
  }

  static double? _optionalDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  /// Accepts plain string id or [DocumentReference] (must match `locations/{id}`).
  static String _locationId(dynamic v) {
    if (v == null) return '';
    if (v is DocumentReference) return v.id;
    return v.toString().trim();
  }

  factory Artifact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Artifact(
      id: doc.id,
      title: _str(data['title']),
      siteName: _str(data['siteName']),
      imagePath: _str(data['imagePath']),
      timePeriod: _str(data['timePeriod']),
      material: _str(data['material']),
      dimensions: _str(data['dimensions']),
      history: _str(data['history']),
      quickFacts: _quickFacts(data['quickFacts']),
      modelPath: _strOrNull(data['modelPath']),
      modelPathAr: _strOrNull(data['modelPathAr']),
      modelPathArClose: _strOrNull(data['modelPathArClose']),
      modelPathArFar: _strOrNull(data['modelPathArFar']),
      modelPathArWall: _strOrNull(data['modelPathArWall']),
      modelPathArCeiling: _strOrNull(data['modelPathArCeiling']),
      markerImagePath: _strOrNull(data['markerImagePath']),
      markerPhysicalWidthMeters: _optionalDouble(data['markerPhysicalWidthMeters']),
      locationId: _locationId(data['locationId']),
    );
  }
}
