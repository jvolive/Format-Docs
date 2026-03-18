import 'package:format_docs/features/supabase/auth/repositories/auth_repository.dart';
import 'package:format_docs/features/supabase/auth/repositories/interfaces/i_auth_repository.dart';
import 'package:format_docs/features/supabase/auth/view_model/auth_view_model.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final getIt = GetIt.instance;

Future<void> initDependencies() async {
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  getIt.registerLazySingleton<IAuthRepository>(
    () => AuthRepository(client: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<AuthViewModel>(
    () => AuthViewModel(repository: getIt<IAuthRepository>()),
  );
}
