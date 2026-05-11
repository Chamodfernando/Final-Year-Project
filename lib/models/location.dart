import 'package:cloud_firestore/cloud_firestore.dart';

class Location {
  final String id;
  final String title;
  final String district;
  final String description;
  final String imagePath;
  final List<String> tags;
  final double rating;

  Location({
    required this.id,
    required this.title,
    required this.district,
    required this.description,
    required this.imagePath,
    required this.tags,
    required this.rating,
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

  factory Location.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Location(
      id: doc.id,
      title: _str(data['title']),
      district: _str(data['district']),
      description: _str(data['description']),
      imagePath: _str(data['imagePath']),
      tags: _tags(data['tags']),
      rating: _rating(data['rating']),
    );
  }
}
