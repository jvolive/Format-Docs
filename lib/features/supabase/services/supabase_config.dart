import 'package:format_docs/features/supabase/services/string_env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  static Future<void> initialize() async {
    StringEnv.validate();

    await Supabase.initialize(
      url: StringEnv.supabaseUrl,
      anonKey: StringEnv.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;
}
