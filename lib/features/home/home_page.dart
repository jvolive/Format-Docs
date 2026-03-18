import 'package:flutter/material.dart';
import 'package:format_docs/features/supabase/auth/view_model/auth_view_model.dart';
import 'package:get_it/get_it.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const routeName = '/home';

  @override
  Widget build(BuildContext context) {
    final vm = GetIt.I<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doc Reviewer'),
        actions: [
          ListenableBuilder(
            listenable: vm,
            builder: (context, _) {
              return Row(
                children: [
                  if (vm.user?.userMetadata?['avatar_url'] != null)
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(
                        vm.user!.userMetadata!['avatar_url'] as String,
                      ),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      await vm.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    },
                    child: const Text('Sair'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListenableBuilder(
              listenable: vm,
              builder: (context, _) {
                final name = vm.user?.userMetadata?['full_name'] as String?;
                return Text(
                  name != null ? 'Olá, $name!' : 'Olá!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'O que deseja fazer hoje?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _ActionCard(
                    icon: Icons.find_in_page_outlined,
                    title: 'Revisar documento',
                    description: 'Analise e corrija a formatação do seu .docx',
                    onTap: () => Navigator.of(context).pushNamed('/review'),
                  ),
                  _ActionCard(
                    icon: Icons.tune_outlined,
                    title: 'Gerenciar regras',
                    description: 'Configure gatilhos e substituições de texto',
                    onTap: () => Navigator.of(context).pushNamed('/rules'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
