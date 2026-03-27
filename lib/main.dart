import 'package:flutter/material.dart';
import 'package:format_docs/features/home/home_page.dart';
import 'package:format_docs/features/rules/view/rules_screen.dart';
import 'package:format_docs/features/supabase/auth/auth_view_model.dart';
import 'package:format_docs/features/supabase/auth/view/login_screen.dart';
import 'package:format_docs/initializer.dart';
import 'package:format_docs/features/supabase/services/supabase_config.dart';

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
        LoginScreen.routeName: (_) => const LoginScreen(),
        HomePage.routeName: (_) => const HomePage(),
        '/review':
            (_) => const Scaffold(
              body: Center(child: Text('Revisar documento — em breve')),
            ),
        RulesScreen.routeName: (_) => const RulesScreen(),
      },
    );
  }

  String _resolveInitialRoute() {
    final isAuthenticated = getIt<AuthViewModel>().isAuthenticated;
    return isAuthenticated ? HomePage.routeName : LoginScreen.routeName;
  }
}
