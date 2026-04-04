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
    required this.locationId,
  });

  factory Artifact.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Artifact(
      id: doc.id,
      title: data['title'] ?? '',
      siteName: data['siteName'] ?? '',
      imagePath: data['imagePath'] ?? '',
      timePeriod: data['timePeriod'] ?? '',
      material: data['material'] ?? '',
      dimensions: data['dimensions'] ?? '',
      history: data['history'] ?? '',
      quickFacts: data['quickFacts'] is List 
          ? List<String>.from(data['quickFacts']) 
          : (data['quickFacts'] != null && data['quickFacts'] != '' ? [data['quickFacts'].toString()] : []),
      modelPath: data['modelPath'],
      locationId: data['locationId'] ?? '',
    );
  }
}
