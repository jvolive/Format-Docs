import 'package:flutter/foundation.dart';
import 'package:format_docs/features/supabase/auth/repositories/interfaces/i_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository implements IAuthRepository {
  final SupabaseClient _client;

  const AuthRepository({required SupabaseClient client}) : _client = client;

  @override
  User? get currentUser => _client.auth.currentSession?.user;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.formatdocs://login-callback',
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
