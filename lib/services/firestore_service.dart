import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/location.dart';
import '../models/location_city_option.dart';
import '../models/artifact.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// All locations. Skips malformed docs so one bad row does not empty the list.
  Stream<List<Location>> streamLocations() {
    return _db.collection('locations').snapshots().map((snapshot) {
      final list = <Location>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Location.fromFirestore(doc));
        } catch (e, st) {
          debugPrint('FirestoreService: skip location ${doc.id}: $e\n$st');
        }
      }
      if (kDebugMode) {
        debugPrint(
          'Firestore locations snapshot: ${snapshot.docs.length} docs, '
          '${list.length} parsed',
        );
      }
      return list;
    });
  }

  /// Locations whose `city` field equals [city] (trimmed). Empty [city] yields no stream listen.
  Stream<List<Location>> streamLocationsByCity(String city) {
    final c = city.trim();
    if (c.isEmpty) {
      return Stream.value([]);
    }
    return _db
        .collection('locations')
        .where('city', isEqualTo: c)
        .snapshots()
        .map((snapshot) {
      final list = <Location>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Location.fromFirestore(doc));
        } catch (e, st) {
          debugPrint('FirestoreService: skip location ${doc.id}: $e\n$st');
        }
      }
      if (kDebugMode) {
        debugPrint(
          'Firestore locations by city "$c": ${snapshot.docs.length} docs, '
          '${list.length} parsed',
        );
      }
      return list;
    });
  }

  /// Distinct non-empty `city` values from all locations, with counts, sorted A→Z.
  Stream<List<LocationCityOption>> streamLocationCityOptions() {
    return _db.collection('locations').snapshots().map((snapshot) {
      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        try {
          final loc = Location.fromFirestore(doc);
          final c = loc.city.trim();
          if (c.isEmpty) continue;
          counts[c] = (counts[c] ?? 0) + 1;
        } catch (e, st) {
          debugPrint('FirestoreService: skip location ${doc.id} for city list: $e\n$st');
        }
      }
      final list = counts.entries
          .map(
            (e) => LocationCityOption(city: e.key, locationCount: e.value),
          )
          .toList()
        ..sort(
          (a, b) => a.city.toLowerCase().compareTo(b.city.toLowerCase()),
        );
      if (kDebugMode) {
        debugPrint(
          'Firestore city options: ${snapshot.docs.length} docs → ${list.length} cities',
        );
      }
      return list;
    });
  }

  /// Artifacts for [locationId] (Firestore **locations** document id).
  ///
  /// Merges two queries so artifacts match whether `locationId` was saved as a **string**
  /// or a **DocumentReference** to `locations/{id}` (common cause of “missing” rows).
  Stream<List<Artifact>> streamArtifacts(String locationId) {
    final key = locationId.trim();
    if (key.isEmpty) {
      return Stream.value([]);
    }

    final locRef = _db.collection('locations').doc(key);

    return Stream.multi((controller) {
      List<QueryDocumentSnapshot<Map<String, dynamic>>> latest1 = [];
      List<QueryDocumentSnapshot<Map<String, dynamic>>> latest2 = [];

      int tsMillis(Map<String, dynamic>? d, String field) {
        final v = d?[field];
        if (v is Timestamp) return v.millisecondsSinceEpoch;
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return parsed.millisecondsSinceEpoch;
        }
        return 0;
      }

      void emit() {
        final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final d in latest1) {
          merged[d.id] = d;
        }
        for (final d in latest2) {
          merged[d.id] = d;
        }
        var docs = merged.values.toList();
        docs.sort((a, b) {
          final da = a.data();
          final db = b.data();
          final ca = tsMillis(da, 'createdAt');
          final cb = tsMillis(db, 'createdAt');
          if (ca != cb) return cb.compareTo(ca);
          final ua = tsMillis(da, 'updatedAt');
          final ub = tsMillis(db, 'updatedAt');
          return ub.compareTo(ua);
        });

        final list = <Artifact>[];
        for (final doc in docs) {
          try {
            list.add(Artifact.fromFirestore(doc));
          } catch (e, st) {
            debugPrint('FirestoreService: skip artifact ${doc.id}: $e\n$st');
          }
        }

        if (kDebugMode) {
          debugPrint(
            'Artifacts for location "$key": stringQuery=${latest1.length}, '
            'refQuery=${latest2.length}, mergedDocs=${docs.length}, parsed=${list.length}',
          );
        }

        controller.add(list);
      }

      final sub1 = _db
          .collection('artifacts')
          .where('locationId', isEqualTo: key)
          .snapshots()
          .listen(
            (s) {
              latest1 =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(s.docs);
              emit();
            },
            onError: controller.addError,
          );

      final sub2 = _db
          .collection('artifacts')
          .where('locationId', isEqualTo: locRef)
          .snapshots()
          .listen(
            (s) {
              latest2 =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(s.docs);
              emit();
            },
            onError: controller.addError,
          );

      controller.onCancel = () {
        sub1.cancel();
        sub2.cancel();
      };
    });
  }
}
