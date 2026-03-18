import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:format_docs/features/supabase/auth/repositories/interfaces/i_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthViewModel extends ChangeNotifier {
  final IAuthRepository _repository;

  late final StreamSubscription<AuthState> _authSubscription;

  AuthViewModel({required IAuthRepository repository})
    : _repository = repository {
    _init();
  }

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void _init() {
    _user = _repository.currentUser;
    _status =
        _user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;

    _authSubscription = _repository.authStateChanges.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
          _user = data.session?.user;
          _status = AuthStatus.authenticated;
        case AuthChangeEvent.signedOut:
          _user = null;
          _status = AuthStatus.unauthenticated;
        default:
          break;
      }
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    _setLoading();
    try {
      await _repository.signInWithGoogle();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> signOut() async {
    _setLoading();
    try {
      await _repository.signOut();
    } catch (e) {
      _setError(e.toString());
    }
  }

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
