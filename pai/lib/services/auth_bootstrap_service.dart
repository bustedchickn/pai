import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthBootstrapResult {
  const AuthBootstrapResult({
    required this.usesFirebaseAuth,
    this.uid,
    this.isAnonymous = false,
    this.email,
    this.displayName,
    this.linkedProviders = const [],
  });

  const AuthBootstrapResult.local()
    : usesFirebaseAuth = false,
      uid = null,
      isAnonymous = false,
      email = null,
      displayName = null,
      linkedProviders = const [];

  final bool usesFirebaseAuth;
  final String? uid;
  final bool isAnonymous;
  final String? email;
  final String? displayName;
  final List<String> linkedProviders;

  bool get isGoogleLinked => linkedProviders.contains('google.com');
  bool get canLinkGoogle => usesFirebaseAuth && !isGoogleLinked;

  String get accountLabel {
    if (!usesFirebaseAuth) {
      return 'Local only';
    }
    if (isGoogleLinked) {
      return 'Linked to Google';
    }
    if (isAnonymous) {
      return 'Anonymous account';
    }
    return 'Firebase account';
  }

  AuthBootstrapResult copyWith({
    bool? usesFirebaseAuth,
    Object? uid = _unsetAuthValue,
    bool? isAnonymous,
    Object? email = _unsetAuthValue,
    Object? displayName = _unsetAuthValue,
    List<String>? linkedProviders,
  }) {
    return AuthBootstrapResult(
      usesFirebaseAuth: usesFirebaseAuth ?? this.usesFirebaseAuth,
      uid: uid == _unsetAuthValue ? this.uid : uid as String?,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      email: email == _unsetAuthValue ? this.email : email as String?,
      displayName: displayName == _unsetAuthValue
          ? this.displayName
          : displayName as String?,
      linkedProviders: linkedProviders ?? this.linkedProviders,
    );
  }

  factory AuthBootstrapResult.fromUser(User user) {
    final linkedProviders = [
      for (final provider in user.providerData)
        if (provider.providerId.isNotEmpty) provider.providerId,
    ]..sort();
    return AuthBootstrapResult(
      usesFirebaseAuth: true,
      uid: user.uid,
      isAnonymous: user.isAnonymous,
      email: user.email,
      displayName: user.displayName,
      linkedProviders: List<String>.unmodifiable(linkedProviders),
    );
  }
}

const Object _unsetAuthValue = Object();

enum GoogleLinkStatus {
  linked,
  signedIn,
  alreadyLinked,
  cancelled,
  credentialAlreadyInUse,
  unsupported,
  failed,
}

class GoogleLinkResult {
  const GoogleLinkResult({
    required this.status,
    required this.message,
    this.authResult,
  });

  final GoogleLinkStatus status;
  final String message;
  final AuthBootstrapResult? authResult;

  bool get isSuccess =>
      status == GoogleLinkStatus.linked ||
      status == GoogleLinkStatus.signedIn ||
      status == GoogleLinkStatus.alreadyLinked;
}

abstract class AuthBootstrapService {
  Future<AuthBootstrapResult> ensureSignedIn();
  Future<AuthBootstrapResult> ensureSignedInAnonymously();
  Future<AuthBootstrapResult> refreshCurrentUser();
  Future<GoogleLinkResult> signInOrLinkGoogle();
}

class FirebaseAuthBootstrapService implements AuthBootstrapService {
  FirebaseAuthBootstrapService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    WindowsGoogleOAuthService? windowsGoogleOAuthService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _windowsGoogleOAuthService =
           windowsGoogleOAuthService ?? WindowsGoogleOAuthService();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final WindowsGoogleOAuthService _windowsGoogleOAuthService;
  bool _googleInitialized = false;
  static const String _appleGoogleClientId = String.fromEnvironment(
    'PAI_APPLE_GOOGLE_CLIENT_ID',
  );
  static const String _appleGoogleServerClientId = String.fromEnvironment(
    'PAI_APPLE_GOOGLE_SERVER_CLIENT_ID',
  );

  @override
  Future<AuthBootstrapResult> ensureSignedIn() {
    return ensureSignedInAnonymously();
  }

  @override
  Future<AuthBootstrapResult> ensureSignedInAnonymously() async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;

    if (user == null) {
      throw StateError('Firebase Auth did not return a signed-in user.');
    }

    return AuthBootstrapResult.fromUser(user);
  }

  @override
  Future<AuthBootstrapResult> refreshCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthBootstrapResult.local();
    }

    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null) {
      return const AuthBootstrapResult.local();
    }
    return AuthBootstrapResult.fromUser(refreshed);
  }

  @override
  Future<GoogleLinkResult> signInOrLinkGoogle() async {
    final currentUser = _auth.currentUser;
    final currentAuthState = currentUser == null
        ? null
        : AuthBootstrapResult.fromUser(currentUser);
    if (currentAuthState?.isGoogleLinked ?? false) {
      return GoogleLinkResult(
        status: GoogleLinkStatus.alreadyLinked,
        message: 'This account is already linked to Google.',
        authResult: currentAuthState,
      );
    }

    try {
      final authenticatedUser = kIsWeb
          ? await _signInOrLinkWithGoogleOnWeb(currentUser)
          : await _signInOrLinkWithGoogleOnNative(currentUser);
      final linkedAnonymousUser =
          currentUser != null && currentUser.isAnonymous;
      return GoogleLinkResult(
        status: linkedAnonymousUser
            ? GoogleLinkStatus.linked
            : GoogleLinkStatus.signedIn,
        message: linkedAnonymousUser
            ? 'Account linked successfully.'
            : 'Signed in with Google.',
        authResult: AuthBootstrapResult.fromUser(authenticatedUser),
      );
    } on GoogleSignInException catch (error) {
      return GoogleLinkResult(
        status:
            error.code == GoogleSignInExceptionCode.canceled ||
                error.code == GoogleSignInExceptionCode.interrupted
            ? GoogleLinkStatus.cancelled
            : GoogleLinkStatus.failed,
        message: switch (error.code) {
          GoogleSignInExceptionCode.canceled ||
          GoogleSignInExceptionCode.interrupted =>
            'Google sign-in was cancelled.',
          GoogleSignInExceptionCode.clientConfigurationError =>
            'Google sign-in is not configured correctly for this app yet.',
          GoogleSignInExceptionCode.uiUnavailable =>
            'Google sign-in is not available on this device right now.',
          _ => 'Google sign-in failed. Please try again.',
        },
      );
    } on WindowsGoogleOAuthException catch (error) {
      return GoogleLinkResult(
        status: switch (error.code) {
          'cancelled' => GoogleLinkStatus.cancelled,
          'configuration-error' => GoogleLinkStatus.unsupported,
          _ => GoogleLinkStatus.failed,
        },
        message: error.message,
      );
    } on FirebaseAuthException catch (error) {
      return GoogleLinkResult(
        status: switch (error.code) {
          'provider-already-linked' => GoogleLinkStatus.alreadyLinked,
          'credential-already-in-use' ||
          'account-exists-with-different-credential' =>
            GoogleLinkStatus.credentialAlreadyInUse,
          'popup-closed-by-user' ||
          'cancelled-popup-request' => GoogleLinkStatus.cancelled,
          _ => GoogleLinkStatus.failed,
        },
        message: switch (error.code) {
          'provider-already-linked' =>
            'This account is already linked to Google.',
          'credential-already-in-use' ||
          'account-exists-with-different-credential' =>
            'This Google account is already associated with another account.',
          'popup-closed-by-user' ||
          'cancelled-popup-request' => 'Google sign-in was cancelled.',
          _ => error.message ?? 'Google sign-in failed.',
        },
        authResult: error.code == 'provider-already-linked'
            ? await refreshCurrentUser()
            : null,
      );
    } on UnsupportedError catch (_) {
      return const GoogleLinkResult(
        status: GoogleLinkStatus.unsupported,
        message: 'Google sign-in is not available on this platform yet.',
      );
    } catch (_) {
      return const GoogleLinkResult(
        status: GoogleLinkStatus.failed,
        message: 'Google sign-in failed. Please try again.',
      );
    }
  }

  Future<User> _signInOrLinkWithGoogleOnWeb(User? user) async {
    final provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');
    final credential = user != null && user.isAnonymous
        ? await user.linkWithPopup(provider)
        : await _auth.signInWithPopup(provider);
    final linkedUser = credential.user ?? _auth.currentUser;
    if (linkedUser == null) {
      throw StateError('Firebase Auth did not return a signed-in user.');
    }
    return linkedUser;
  }

  Future<User> _signInOrLinkWithGoogleOnNative(User? user) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final googleTokens = await _windowsGoogleOAuthService.authenticate();
      final credential = GoogleAuthProvider.credential(
        accessToken: googleTokens.accessToken,
        idToken: googleTokens.idToken,
      );
      return _signInOrLinkWithCredential(user, credential);
    }

    if (!_supportsNativeGoogleSignIn) {
      throw UnsupportedError(
        'Google sign-in is not available on this platform.',
      );
    }

    await _ensureGoogleInitialized();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError(
        'Google sign-in is not available on this platform.',
      );
    }

    final googleAccount = await _googleSignIn.authenticate(
      scopeHint: const ['email', 'profile'],
    );
    final googleAuth = googleAccount.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google sign-in did not return an ID token.',
      );
    }

    final firebaseCredential = GoogleAuthProvider.credential(idToken: idToken);
    return _signInOrLinkWithCredential(user, firebaseCredential);
  }

  Future<User> _signInOrLinkWithCredential(
    User? user,
    OAuthCredential credential,
  ) async {
    final userCredential = user != null && user.isAnonymous
        ? await user.linkWithCredential(credential)
        : await _auth.signInWithCredential(credential);
    final linkedUser = userCredential.user ?? _auth.currentUser;
    if (linkedUser == null) {
      throw StateError('Firebase Auth did not return a signed-in user.');
    }
    return linkedUser;
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) {
      return;
    }

    await _googleSignIn.initialize(
      clientId: _googleClientIdForCurrentPlatform,
      serverClientId: _googleServerClientIdForCurrentPlatform,
    );
    _googleInitialized = true;
  }

  String? get _googleClientIdForCurrentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _appleGoogleClientId.isEmpty ? null : _appleGoogleClientId;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return null;
    }
  }

  String? get _googleServerClientIdForCurrentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _appleGoogleServerClientId.isEmpty
            ? null
            : _appleGoogleServerClientId;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return null;
    }
  }

  bool get _supportsNativeGoogleSignIn {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }
}

class LocalAuthBootstrapService implements AuthBootstrapService {
  const LocalAuthBootstrapService();

  @override
  Future<AuthBootstrapResult> ensureSignedIn() async {
    return const AuthBootstrapResult.local();
  }

  @override
  Future<AuthBootstrapResult> ensureSignedInAnonymously() async {
    return const AuthBootstrapResult.local();
  }

  @override
  Future<AuthBootstrapResult> refreshCurrentUser() async {
    return const AuthBootstrapResult.local();
  }

  @override
  Future<GoogleLinkResult> signInOrLinkGoogle() async {
    return const GoogleLinkResult(
      status: GoogleLinkStatus.unsupported,
      message:
          'Google sign-in is only available when Firebase Auth is enabled.',
    );
  }
}

class WindowsGoogleOAuthTokens {
  const WindowsGoogleOAuthTokens({
    required this.accessToken,
    required this.idToken,
  });

  final String accessToken;
  final String idToken;
}

class WindowsGoogleOAuthException implements Exception {
  const WindowsGoogleOAuthException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => 'WindowsGoogleOAuthException($code, $message)';
}

class WindowsGoogleOAuthService {
  WindowsGoogleOAuthService({
    http.Client? httpClient,
    String clientId = _defaultWindowsGoogleClientId,
    int redirectPort = _defaultWindowsGoogleRedirectPort,
  }) : _httpClient = httpClient ?? http.Client(),
       _clientId = clientId.trim(),
       _redirectPort = redirectPort;

  static const int _defaultWindowsGoogleRedirectPort = int.fromEnvironment(
    'PAI_WINDOWS_GOOGLE_REDIRECT_PORT',
    defaultValue: 53171,
  );
  static const String _defaultWindowsGoogleClientId = String.fromEnvironment(
    'PAI_WINDOWS_GOOGLE_CLIENT_ID',
  );
  static const String _redirectHost = '127.0.0.1';
  static const String _redirectPath = '/oauth2redirect';

  final http.Client _httpClient;
  final String _clientId;
  final int _redirectPort;

  Uri get _redirectUri =>
      Uri.parse('http://$_redirectHost:$_redirectPort$_redirectPath');

  Future<WindowsGoogleOAuthTokens> authenticate() async {
    if (_clientId.isEmpty) {
      throw const WindowsGoogleOAuthException(
        code: 'configuration-error',
        message:
            'Windows Google sign-in is not configured yet. Set the '
            'PAI_WINDOWS_GOOGLE_CLIENT_ID Dart define for the desktop OAuth '
            'client.',
      );
    }

    final codeVerifier = _randomUrlSafeValue(64);
    final codeChallenge = _codeChallengeFor(codeVerifier);
    final state = _randomUrlSafeValue(32);

    // flutter_web_auth_2 listens on 127.0.0.1 for Windows loopback callbacks.
    final authorizationUri =
        Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'client_id': _clientId,
          'redirect_uri': _redirectUri.toString(),
          'response_type': 'code',
          'scope': 'openid email profile',
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
          'state': state,
          'prompt': 'select_account',
        });

    late final String callbackUrl;
    try {
      callbackUrl = await FlutterWebAuth2.authenticate(
        url: authorizationUri.toString(),
        callbackUrlScheme: 'http://$_redirectHost:$_redirectPort',
        options: const FlutterWebAuth2Options(useWebview: false),
      );
    } on PlatformException catch (error) {
      final isCancelled =
          error.code.toUpperCase() == 'CANCELED' ||
          (error.message?.toLowerCase().contains('cancel') ?? false);
      throw WindowsGoogleOAuthException(
        code: isCancelled ? 'cancelled' : 'browser-callback-failed',
        message: isCancelled
            ? 'Google sign-in was cancelled.'
            : 'PAI could not receive the Windows browser sign-in callback.',
      );
    } catch (_) {
      throw const WindowsGoogleOAuthException(
        code: 'browser-callback-failed',
        message: 'PAI could not complete the Windows browser sign-in flow.',
      );
    }

    final callbackUri = Uri.parse(callbackUrl);
    final returnedState = callbackUri.queryParameters['state'];
    if (returnedState == null || returnedState != state) {
      throw const WindowsGoogleOAuthException(
        code: 'browser-callback-failed',
        message: 'The Windows Google sign-in response was invalid.',
      );
    }

    final errorCode = callbackUri.queryParameters['error'];
    if (errorCode != null) {
      throw WindowsGoogleOAuthException(
        code: errorCode == 'access_denied'
            ? 'cancelled'
            : 'browser-callback-failed',
        message: errorCode == 'access_denied'
            ? 'Google sign-in was cancelled.'
            : callbackUri.queryParameters['error_description'] ??
                  'Google sign-in returned an error in the browser.',
      );
    }

    final authorizationCode = callbackUri.queryParameters['code'];
    if (authorizationCode == null || authorizationCode.isEmpty) {
      throw const WindowsGoogleOAuthException(
        code: 'browser-callback-failed',
        message: 'Google sign-in did not return an authorization code.',
      );
    }

    return _exchangeCodeForTokens(
      authorizationCode: authorizationCode,
      codeVerifier: codeVerifier,
    );
  }

  Future<WindowsGoogleOAuthTokens> _exchangeCodeForTokens({
    required String authorizationCode,
    required String codeVerifier,
  }) async {
    final response = await _httpClient.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'code': authorizationCode,
        'code_verifier': codeVerifier,
        'grant_type': 'authorization_code',
        'redirect_uri': _redirectUri.toString(),
      },
    );

    Map<String, dynamic> payload = const <String, dynamic>{};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsGoogleOAuthException(
        code: 'token-exchange-failed',
        message:
            payload['error_description'] as String? ??
            payload['error'] as String? ??
            'Google sign-in could not finish exchanging the desktop OAuth code.',
      );
    }

    final accessToken = payload['access_token'] as String?;
    final idToken = payload['id_token'] as String?;
    if (accessToken == null ||
        accessToken.isEmpty ||
        idToken == null ||
        idToken.isEmpty) {
      throw const WindowsGoogleOAuthException(
        code: 'token-exchange-failed',
        message: 'Google sign-in completed without the tokens Firebase needs.',
      );
    }

    return WindowsGoogleOAuthTokens(accessToken: accessToken, idToken: idToken);
  }

  String _codeChallengeFor(String codeVerifier) {
    final digest = sha256.convert(utf8.encode(codeVerifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String _randomUrlSafeValue(int length) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return String.fromCharCodes(
      List<int>.generate(
        length,
        (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ),
    );
  }
}
