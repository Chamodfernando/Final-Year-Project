import 'package:cloud_firestore/cloud_firestore.dart';

class Location {
  final String id;
  final String title;
  /// Primary city / town (from admin dropdown).
  final String city;
  final String district;
  final String description;
  final String imagePath;
  final List<String> tags;
  final double rating;

  /// WGS84 for Google Maps directions (optional; set in Firestore / admin).
  final double? latitude;
  final double? longitude;

  Location({
    required this.id,
    required this.title,
    this.city = '',
    required this.district,
    required this.description,
    required this.imagePath,
    required this.tags,
    required this.rating,
    this.latitude,
    this.longitude,
  });

  static String _str(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  static List<String> _tags(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    final one = v.toString().trim();
    return one.isEmpty ? [] : [one];
  }

  static double _rating(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static double? _scalarDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }
    return double.tryParse(v.toString());
  }

  /// Firestore occasionally yields `Map<Object?, Object?>`; normalize keys to [String].
  static Map<String, dynamic> _stringKeyMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      final out = <String, dynamic>{};
      for (final e in raw.entries) {
        out[e.key.toString()] = e.value;
      }
      return out;
    }
    return {};
  }

  /// Rough bounds for Sri Lanka — used only to resolve `[a,b]` coordinate pairs.
  static (double lat, double lng)? _latLngFromPair(double a, double b) {
    bool latBand(double v) => v >= 5.0 && v <= 12.0;
    bool lngBand(double v) => v >= 78.0 && v <= 84.0;
    if (latBand(a) && lngBand(b)) return (a, b);
    if (latBand(b) && lngBand(a)) return (b, a);
    return null;
  }

  /// Reads lat/lng from a flat map with case-insensitive keys (`LAT`, `Longitude`, …).
  static (double?, double?) _latLngFromFlatMap(Map<String, dynamic> data) {
    double? lat;
    double? lng;
    for (final e in data.entries) {
      final nk = e.key.toString().trim().toLowerCase();
      if (nk == 'latitude' || nk == 'lat') {
        lat ??= _scalarDouble(e.value);
      } else if (nk == 'longitude' || nk == 'lng' || nk == 'lon') {
        lng ??= _scalarDouble(e.value);
      }
    }
    return (lat, lng);
  }

  factory Location.fromFirestore(DocumentSnapshot doc) {
    final data = _stringKeyMap(doc.data());

    final ll0 = _latLngFromFlatMap(data);
    var lat = ll0.$1;
    var lng = ll0.$2;

    for (final key in <String>[
      'location',
      'geo',
      'geopoint',
      'coordinates',
      'position',
      'gps',
      'coords',
    ]) {
      final g = data[key];
      if (g is GeoPoint) {
        lat ??= g.latitude;
        lng ??= g.longitude;
        continue;
      }
      if (g is Map) {
        final m = _stringKeyMap(g);
        final inner = _latLngFromFlatMap(m);
        lat ??= inner.$1;
        lng ??= inner.$2;
      }
      if (g is List && g.length >= 2) {
        final a = _scalarDouble(g[0]);
        final b = _scalarDouble(g[1]);
        if (a != null && b != null) {
          final pair = _latLngFromPair(a, b);
          if (pair != null) {
            lat ??= pair.$1;
            lng ??= pair.$2;
          }
        }
      }
    }

    return Location(
      id: doc.id,
      title: _str(data['title']),
      city: _str(data['city']),
      district: _str(data['district']),
      description: _str(data['description']),
      imagePath: _str(data['imagePath']),
      tags: _tags(data['tags']),
      rating: _rating(data['rating']),
      latitude: lat,
      longitude: lng,
    );
  }
}
