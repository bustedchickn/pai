import 'package:firebase_auth/firebase_auth.dart';

class AuthBootstrapResult {
  const AuthBootstrapResult({
    required this.usesFirebaseAuth,
    this.uid,
    this.isAnonymous = false,
  });

  const AuthBootstrapResult.local()
    : usesFirebaseAuth = false,
      uid = null,
      isAnonymous = false;

  final bool usesFirebaseAuth;
  final String? uid;
  final bool isAnonymous;
}

abstract class AuthBootstrapService {
  Future<AuthBootstrapResult> ensureSignedIn();
}

class FirebaseAuthBootstrapService implements AuthBootstrapService {
  FirebaseAuthBootstrapService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<AuthBootstrapResult> ensureSignedIn() async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;

    if (user == null) {
      throw StateError('Firebase Auth did not return a signed-in user.');
    }

    return AuthBootstrapResult(
      usesFirebaseAuth: true,
      uid: user.uid,
      isAnonymous: user.isAnonymous,
    );
  }
}

class LocalAuthBootstrapService implements AuthBootstrapService {
  const LocalAuthBootstrapService();

  @override
  Future<AuthBootstrapResult> ensureSignedIn() async {
    return const AuthBootstrapResult.local();
  }
}
