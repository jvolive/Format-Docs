import 'package:flutter/material.dart';
import 'package:format_docs/features/supabase/auth/view_model/auth_view_model.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 48),
              _GoogleSignInButton(),
              const SizedBox(height: 16),
              _ErrorMessage(),
            ],
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
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Doc Reviewer',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Revise e formate seus documentos\nde forma automática',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = GetIt.I<AuthViewModel>();

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.status == AuthStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SupaSocialsAuth(
          socialProviders: const [OAuthProvider.google],
          colored: true,
          onSuccess: (session) {
            Navigator.of(context).pushReplacementNamed('/home');
          },
          onError: (error) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.toString())));
          },
        );
      },
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = GetIt.I<AuthViewModel>();

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.errorMessage == null) return const SizedBox.shrink();
        return Text(
          vm.errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
