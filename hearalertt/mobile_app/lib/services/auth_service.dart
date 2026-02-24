import 'package:firebase_auth/firebase_auth.dart';

/// Handles Firebase Anonymous Authentication.
///
/// On first launch a unique UID is created and persisted by Firebase.
/// Subsequent launches reuse the same UID — no login screen ever shown.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// The UID of the currently signed-in anonymous user, or null if not yet
  /// signed in.
  String? get uid => _auth.currentUser?.uid;

  /// Sign in anonymously (idempotent — reuses existing session).
  Future<String> signInAnonymously() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;

    final cred = await _auth.signInAnonymously();
    return cred.user!.uid;
  }

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
