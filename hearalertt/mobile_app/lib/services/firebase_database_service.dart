import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mobile_app/models/models.dart';
import 'package:mobile_app/services/auth_service.dart';

/// Singleton service for all Firebase Realtime Database operations.
///
/// All data is scoped under `/users/{uid}/` so each device is tracked
/// independently in the Firebase Console — no login required (anonymous auth).
///
/// DB structure:
/// ```
/// /users/{uid}
///   lastSeen: <timestamp>
///   /alerts/{push_key}  → label, confidence, type, timestamp
///   /contacts/contact_N → name, phone, relation
/// ```
class FirebaseDatabaseService {
  static final FirebaseDatabaseService _instance =
      FirebaseDatabaseService._internal();
  factory FirebaseDatabaseService() => _instance;
  FirebaseDatabaseService._internal();

  // If the database is outside us-central1 or the JSON is missing the URL,
  // we must provide it explicitly.
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://hear-alert-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  final AuthService _auth = AuthService();

  // ── Scoped references (require UID) ────────────────────────────────────────

  String get _uid {
    final uid = _auth.uid;
    assert(uid != null, 'AuthService.signInAnonymously() must be called first');
    return uid!;
  }

  DatabaseReference get _userRef => _db.ref('users/$_uid');
  DatabaseReference get _alertsRef => _db.ref('users/$_uid/alerts');
  DatabaseReference get _contactsRef => _db.ref('users/$_uid/contacts');

  // ══════════════════════════════════════════════════════════════════════════
  // USER PRESENCE
  // ══════════════════════════════════════════════════════════════════════════

  /// Update the user's `lastSeen` timestamp and optional device metadata.
  Future<void> updatePresence({
    String? platform,
    String? appVersion,
  }) async {
    final data = <String, dynamic>{
      'lastSeen': ServerValue.timestamp,
    };
    if (platform != null) data['deviceInfo/platform'] = platform;
    if (appVersion != null) data['deviceInfo/appVersion'] = appVersion;
    await _userRef.update(data);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ALERT HISTORY
  // ══════════════════════════════════════════════════════════════════════════

  /// Push a sound alert event to Firebase under this user's node.
  Future<void> logAlert({
    required String label,
    required double confidence,
    required String type,
    String? localId,
  }) async {
    await _alertsRef.push().set({
      'label': label,
      'confidence': confidence,
      'type': type,
      'localId': localId,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Convenience method: log a [SoundEvent] directly.
  Future<void> logSoundEvent(SoundEvent event) => logAlert(
        label: event.label,
        confidence: event.confidence,
        type: event.type,
        localId: event.id,
      );

  /// Real-time stream of this user's alerts, newest first.
  Stream<List<Map<String, dynamic>>> get alertsStream {
    return _alertsRef.orderByChild('timestamp').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Map<String, dynamic>>[];

      final raw = Map<String, dynamic>.from(data as Map);
      final list = raw.entries.map((e) {
        final entry = Map<String, dynamic>.from(e.value as Map);
        entry['id'] = e.key;
        return entry;
      }).toList();

      list.sort((a, b) {
        final ta = (a['timestamp'] as int?) ?? 0;
        final tb = (b['timestamp'] as int?) ?? 0;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  /// Delete one alert by push key.
  Future<void> deleteAlert(String alertId) =>
      _alertsRef.child(alertId).remove();

  /// Clear all alerts for this user.
  Future<void> clearAllAlerts() => _alertsRef.remove();

  // ══════════════════════════════════════════════════════════════════════════
  // EMERGENCY CONTACTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Overwrite this user's contacts list in Firebase.
  Future<void> saveContacts(List<Contact> contacts) async {
    final map = <String, dynamic>{};
    for (var i = 0; i < contacts.length; i++) {
      map['contact_$i'] = contacts[i].toJson();
    }
    await _contactsRef.set(map);
  }

  /// Real-time stream of this user's contacts.
  Stream<List<Contact>> get contactsStream {
    return _contactsRef.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Contact>[];
      final raw = Map<String, dynamic>.from(data as Map);
      return raw.values
          .map((v) => Contact.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
    });
  }

  /// Fetch contacts once (for initial load fallback).
  Future<List<Contact>> fetchContactsOnce() async {
    final snapshot = await _contactsRef.get();
    if (!snapshot.exists || snapshot.value == null) return [];
    final raw = Map<String, dynamic>.from(snapshot.value as Map);
    return raw.values
        .map((v) => Contact.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  /// Clear all contacts for this user.
  Future<void> clearContacts() => _contactsRef.remove();
}
