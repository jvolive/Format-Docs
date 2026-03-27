import 'package:format_docs/features/rules/data/rules_api_client.dart';
import 'package:format_docs/features/rules/repository/rules_repository.dart';
import 'package:format_docs/features/rules/view_model/rules_view_model.dart';
import 'package:format_docs/features/supabase/auth/auth_repository.dart';
import 'package:format_docs/features/supabase/auth/auth_view_model.dart';
import 'package:format_docs/features/supabase/services/string_env.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final getIt = GetIt.instance;

Future<void> initDependencies() async {
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  getIt.registerLazySingleton<AuthRepositoryInterface>(
    () => AuthRepository(client: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<AuthViewModel>(
    () => AuthViewModel(repository: getIt<AuthRepositoryInterface>()),
  );

  getIt.registerLazySingleton<String>(
    () => StringEnv.supabaseFunctionsUrl,
    instanceName: 'functionsUrl',
  );

  getIt.registerLazySingleton<RulesApiClient>(
    () => RulesApiClient(
      functionsUrl: getIt<String>(instanceName: 'functionsUrl'),
      supabaseClient: getIt<SupabaseClient>(),
    ),
  );

  getIt.registerLazySingleton<RulesRepositoryInterface>(
    () => RulesRepository(apiClient: getIt<RulesApiClient>()),
  );

  getIt.registerLazySingleton<RulesViewModel>(
    () => RulesViewModel(repository: getIt<RulesRepositoryInterface>()),
  );
}
