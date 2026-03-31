import 'package:format_docs/features/rules/data/rules_api_client.dart';
import 'package:format_docs/features/rules/repository/rules_repository.dart';
import 'package:format_docs/features/rules/view_model/rules_view_model.dart';
import 'package:format_docs/features/review_docs/data/review_docs_api_client.dart';
import 'package:format_docs/features/review_docs/repository/review_docs_repository.dart';
import 'package:format_docs/features/review_docs/view_model/review_docs_file_view_model.dart';
import 'package:format_docs/features/review_docs/view_model/review_docs_view_model.dart';
import 'package:format_docs/features/review_html/data/review_html_api_client.dart';
import 'package:format_docs/features/review_html/repository/review_html_repository.dart';
import 'package:format_docs/features/review_html/view_model/review_html_view_model.dart';
import 'package:format_docs/features/supabase/auth/auth_repository.dart';
import 'package:format_docs/features/supabase/auth/auth_view_model.dart';
import 'package:format_docs/features/supabase/services/string_env.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final getIt = GetIt.instance;

class Initializer {
  Initializer._();

  static const _functionsUrlInstanceName = 'functionsUrl';

  static Future<void> initDependencies() async {
    _registerCore();
    _registerRules();
    _registerReviewDocs();
    _registerReviewHtml();
    _registerReviewViewModels();
  }

  static void _registerCore() {
    getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

    getIt.registerLazySingleton<AuthRepositoryInterface>(
      () => AuthRepository(client: getIt<SupabaseClient>()),
    );

    getIt.registerLazySingleton<AuthViewModel>(
      () => AuthViewModel(repository: getIt<AuthRepositoryInterface>()),
    );

    getIt.registerLazySingleton<String>(
      () => StringEnv.supabaseFunctionsUrl,
      instanceName: _functionsUrlInstanceName,
    );
  }

  static void _registerRules() {
    getIt.registerLazySingleton<RulesApiClient>(
      () => RulesApiClient(
        functionsUrl: getIt<String>(instanceName: _functionsUrlInstanceName),
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

  static void _registerReviewDocs() {
    getIt.registerLazySingleton<ReviewDocsApiClient>(
      () => ReviewDocsApiClient(
        functionsUrl: getIt<String>(instanceName: _functionsUrlInstanceName),
        supabaseClient: getIt<SupabaseClient>(),
      ),
    );

    getIt.registerLazySingleton<ReviewDocsRepositoryInterface>(
      () => ReviewDocsRepository(apiClient: getIt<ReviewDocsApiClient>()),
    );
  }

  static void _registerReviewHtml() {
    getIt.registerLazySingleton<ReviewHtmlApiClient>(
      () => ReviewHtmlApiClient(
        functionsUrl: getIt<String>(instanceName: _functionsUrlInstanceName),
        supabaseClient: getIt<SupabaseClient>(),
      ),
    );

    getIt.registerLazySingleton<ReviewHtmlRepositoryInterface>(
      () => ReviewHtmlRepository(apiClient: getIt<ReviewHtmlApiClient>()),
    );
  }

  static void _registerReviewViewModels() {
    getIt.registerLazySingleton<ReviewDocsFileViewModel>(
      () => ReviewDocsFileViewModel(
        repository: getIt<ReviewDocsRepositoryInterface>(),
      ),
    );

    getIt.registerLazySingleton<ReviewHtmlViewModel>(
      () => ReviewHtmlViewModel(
        repository: getIt<ReviewHtmlRepositoryInterface>(),
      ),
    );

    getIt.registerLazySingleton<ReviewDocsViewModel>(
      () => ReviewDocsViewModel(
        docsFileViewModel: getIt<ReviewDocsFileViewModel>(),
        reviewHtmlViewModel: getIt<ReviewHtmlViewModel>(),
      ),
    );
  }
}
