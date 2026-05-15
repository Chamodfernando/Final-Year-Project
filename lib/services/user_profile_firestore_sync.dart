import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Max duration for a single foreground segment (clock skew / debugger pauses).
const int _kMaxForegroundSessionMs = 6 * 60 * 60 * 1000;

/// Writes `users/{uid}` so the admin web panel and analytics can list app users.
///
/// Firestore rules should allow the signed-in user to create/update their own doc,
/// e.g. `allow create, update: if request.auth != null && request.auth.uid == userId`.
/// For admin reads, use a separate admin rule or custom claims as appropriate.
class UserProfileFirestoreSync {
  UserProfileFirestoreSync._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Upserts profile for [FirebaseAuth.instance.currentUser].
  static Future<void> syncCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final ref = _db.collection('users').doc(user.uid);
      final snap = await ref.get();

      final name = (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : (user.isAnonymous ? 'Guest' : 'User');

      final data = <String, dynamic>{
        'email': user.email ?? '',
        'name': name,
        'role': user.isAnonymous ? 'Guest' : 'User',
        'isAnonymous': user.isAnonymous,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!snap.exists) {
        data['joined'] = DateTime.now().toUtc().toIso8601String();
      }

      await ref.set(data, SetOptions(merge: true));
    } on FirebaseException catch (e, st) {
      debugPrint(
        'UserProfileFirestoreSync: Firestore write failed (${e.code}): ${e.message}\n'
        '→ Add Firestore rules for `users/{userId}` (see docs/firestore-users-rules.txt) '
        'or run admin_panel backfill: npm run sync-auth-to-firestore\n$st',
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('UserProfileFirestoreSync: failed for ${user.uid}: $e\n$st');
      }
    }
  }

  /// Records time the app spent in the foreground for **signed-in (non-guest)** users.
  /// Called when the app goes to background; updates [totalForegroundMs] and
  /// [foregroundSessionCount] on `users/{uid}` for admin analytics.
  static Future<void> recordForegroundSession(Duration foreground) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    var ms = foreground.inMilliseconds;
    if (ms < 500) return;
    if (ms > _kMaxForegroundSessionMs) ms = _kMaxForegroundSessionMs;

    try {
      final ref = _db.collection('users').doc(user.uid);
      await ref.set(
        <String, dynamic>{
          'totalForegroundMs': FieldValue.increment(ms),
          'foregroundSessionCount': FieldValue.increment(1),
          'lastForegroundSessionMs': ms,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e, st) {
      debugPrint(
        'UserProfileFirestoreSync: foreground session write failed (${e.code}): '
        '${e.message}\n$st',
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('UserProfileFirestoreSync: recordForegroundSession failed: $e\n$st');
      }
    }
  }
}
