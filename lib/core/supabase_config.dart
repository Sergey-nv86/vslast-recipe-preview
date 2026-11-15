class SupabaseConfig {
  // This repository is an isolated preview. Never fall back to production.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lpuzgzgyxqfwnwpfbefw.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_VSsRlb6ITGZrWa6oz70HsQ_mQkfJfJi',
  );
}
