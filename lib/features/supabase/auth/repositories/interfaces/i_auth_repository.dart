import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class IAuthRepository {
  /// Returns the current logged in user, or null if not authenticated.
  User? get currentUser;

  /// Stream that emits auth state changes.
  Stream<AuthState> get authStateChanges;

  /// Signs in with Google OAuth.
  Future<void> signInWithGoogle();

  /// Signs out the current user.
  Future<void> signOut();
}
