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

  /// True if this account can sign in with email/password — the account
  /// screen only shows "পাসওয়ার্ড পরিবর্তন" for these (a Google-only account
  /// has no password to change).
  bool get isPasswordUser =>
      currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;

  bool get isGoogleUser =>
      currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

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

  /// Only valid for [isPasswordUser] accounts — Firebase requires a recent
  /// sign-in before a sensitive change like this, hence the reauth step.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'সাইন-ইন করা নেই।');
    }
    final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Re-authenticates right before a sensitive action (account deletion) —
  /// Firebase requires a "recent" sign-in for these. For a password
  /// account, [currentPassword] must be supplied; for a Google account it
  /// re-triggers the Google sign-in flow instead.
  Future<void> _reauthenticate({String? currentPassword}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'সাইন-ইন করা নেই।');
    }
    if (isPasswordUser) {
      if (currentPassword == null || currentPassword.isEmpty) {
        throw FirebaseAuthException(code: 'missing-password', message: 'পাসওয়ার্ড আবশ্যক।');
      }
      final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
    } else {
      await _ensureGoogleInitialized();
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message: 'Google থেকে আইডি টোকেন পাওয়া যায়নি।',
        );
      }
      await user.reauthenticateWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    }
  }

  /// Deletes the signed-in Firebase Auth account itself. Callers must
  /// clean up this user's Firestore profile/membership docs first (see
  /// CloudSyncService) and confirm with the user — this cannot be undone.
  Future<void> deleteAccount({String? currentPassword}) async {
    await _reauthenticate(currentPassword: currentPassword);
    await _auth.currentUser?.delete();
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
