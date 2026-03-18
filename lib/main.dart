import 'package:flutter/material.dart';
import 'package:format_docs/features/home/home_page.dart';
import 'package:format_docs/features/supabase/auth/view/login_view.dart';
import 'package:format_docs/features/supabase/auth/view_model/auth_view_model.dart';
import 'package:format_docs/initializer.dart';

import 'features/supabase/services/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseConfig.initialize();
  await initDependencies();

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doc Reviewer',
      debugShowCheckedModeBanner: false,
      initialRoute: _resolveInitialRoute(),
      routes: {
        LoginView.routeName: (_) => const LoginView(),
        HomePage.routeName: (_) => const HomePage(),
        '/review':
            (_) => const Scaffold(
              body: Center(child: Text('Revisar documento — em breve')),
            ),
        '/rules':
            (_) => const Scaffold(
              body: Center(child: Text('Gerenciar regras — em breve')),
            ),
      },
    );
  }

  String _resolveInitialRoute() {
    final isAuthenticated = getIt<AuthViewModel>().isAuthenticated;
    return isAuthenticated ? HomePage.routeName : LoginView.routeName;
  }
}
