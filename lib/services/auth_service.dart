import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps [FirebaseAuth] + [GoogleSignIn] behind one small API so screens
/// never touch either plugin directly. Email/password and Google are the
/// only two sign-in methods this app supports.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // The OAuth "Server client ID" (client_type 3) from google-services.json
  // — Firebase's ID-token verification checks the token's audience against
  // this, not the Android client, so it must be passed explicitly here.
  static const _serverClientId =
      '626419471655-ctdrq1vblm71teeqvp7nktn1fbr76mg9.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInitFuture;

  Future<void> _ensureGoogleInitialized() {
    return _googleInitFuture ??= _googleSignIn.initialize(
      serverClientId: _serverClientId,
    );
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Returns null if the user cancelled the Google account picker (not an
  /// error — callers should just do nothing in that case).
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google থেকে আইডি টোকেন পাওয়া যায়নি।',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // Best-effort — a failure here (e.g. Google session already gone)
    // shouldn't block the Firebase sign-out that already succeeded.
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (_) {
      // ignore
    }
  }
}
