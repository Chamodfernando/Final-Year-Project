import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location.dart';
import '../models/artifact.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of all locations
  Stream<List<Location>> streamLocations() {
    return _db.collection('locations').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Location.fromFirestore(doc)).toList());
  }

  // Stream of artifacts for a specific location
  Stream<List<Artifact>> streamArtifacts(String locationId) {
    return _db
        .collection('artifacts')
        .where('locationId', isEqualTo: locationId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Artifact.fromFirestore(doc)).toList());
  }
}
