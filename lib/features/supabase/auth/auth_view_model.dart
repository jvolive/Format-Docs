import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:format_docs/features/supabase/auth/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthViewModel extends ChangeNotifier {
  final AuthRepositoryInterface _repository;

  AuthViewModel({required AuthRepositoryInterface repository})
    : _repository = repository {
    _initialize();
  }

  StreamSubscription<AuthState>? _authSubscription;
  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  void _initialize() {
    _user = _repository.currentUser;
    _status =
        _user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;

    _authSubscription = _repository.authStateChanges.listen(_onAuthStateChange);
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _setLoading();

    try {
      final opened = await _repository.signInWithGoogle();
      if (!opened) {
        _setError('Não foi possível iniciar o login com Google.');
      }
    } catch (error) {
      _setError(_normalizeError(error));
    }
  }

  Future<void> signOut() async {
    _setLoading();

    try {
      await _repository.signOut();
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _setError(_normalizeError(error));
    }
  }

  void _onAuthStateChange(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
      case AuthChangeEvent.passwordRecovery:
      case AuthChangeEvent.mfaChallengeVerified:
        _user = state.session?.user ?? _repository.currentUser;
        _status =
            _user == null
                ? AuthStatus.unauthenticated
                : AuthStatus.authenticated;
        _errorMessage = null;
        break;
      case AuthChangeEvent.signedOut:
        _user = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = null;
        break;
      default:
        break;
    }

    notifyListeners();
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

  String _normalizeError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.replaceFirst('Exception: ', '')
        : message;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
