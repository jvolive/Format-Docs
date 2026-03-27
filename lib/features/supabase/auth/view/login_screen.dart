import 'package:flutter/material.dart';
import 'package:format_docs/features/home/home_page.dart';
import 'package:format_docs/features/supabase/auth/auth_view_model.dart';
import 'package:format_docs/initializer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthViewModel _authViewModel;
  bool _navigatedToHome = false;

  @override
  void initState() {
    super.initState();
    _authViewModel = getIt<AuthViewModel>();
    _authViewModel.addListener(_handleAuthStateChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthStateChange();
    });
  }

  @override
  void dispose() {
    _authViewModel.removeListener(_handleAuthStateChange);
    super.dispose();
  }

  void _handleAuthStateChange() {
    if (!mounted) return;

    if (_authViewModel.status == AuthStatus.authenticated) {
      if (_navigatedToHome) return;

      _navigatedToHome = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(HomePage.routeName);
      });
    } else {
      _navigatedToHome = false;
    }
  }

  Future<void> _onSignInPressed() async {
    await _authViewModel.signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: ListenableBuilder(
                  listenable: _authViewModel,
                  builder: (context, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Header(),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed:
                              _authViewModel.isLoading
                                  ? null
                                  : _onSignInPressed,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon:
                              _authViewModel.isLoading
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.login_rounded),
                          label: Text(
                            _authViewModel.isLoading
                                ? 'Conectando...'
                                : 'Entrar com Google',
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_authViewModel.errorMessage != null)
                          Text(
                            _authViewModel.errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.description_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 14),
        Text(
          'Doc Reviewer',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Faça login para revisar e formatar seus documentos.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
