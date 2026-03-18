class StringEnv {
  const StringEnv._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const supabaseFunctionsUrl = String.fromEnvironment('SUPABASE_FUNCTIONS_URL');

  static void validate() {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
      if (supabaseFunctionsUrl.isEmpty) 'SUPABASE_FUNCTIONS_URL',
    ];

    if (missing.isNotEmpty) {
      throw StateError(
        'Missing environment variables: ${missing.join(', ')}\n'
        'Run with --dart-define=KEY=VALUE or use a .env launch config.',
      );
    }
  }
}
