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

  factory Location.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Location(
      id: doc.id,
      title: data['title'] ?? '',
      district: data['district'] ?? '',
      description: data['description'] ?? '',
      imagePath: data['imagePath'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      rating: (data['rating'] ?? 0.0).toDouble(),
    );
  }
}
