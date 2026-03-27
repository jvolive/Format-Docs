import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthRepositoryInterface {
  User? get currentUser;
  Stream<AuthState> get authStateChanges;
  Future<bool> signInWithGoogle();
  Future<void> signOut();
}

class AuthRepository implements AuthRepositoryInterface {
  final SupabaseClient _client;

  const AuthRepository({required SupabaseClient client}) : _client = client;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<bool> signInWithGoogle() async {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _resolveRedirectTo(),
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  String? _resolveRedirectTo() {
    if (!kIsWeb) return null;
    final currentUrl = Uri.base;
    return currentUrl.replace(query: null, fragment: null).toString();
  }
}
