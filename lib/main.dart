import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://hsbgqbyumyvcxczwuvqv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzYmdxYnl1bXl2Y3hjend1dnF2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkwODE2OTcsImV4cCI6MjA2NDY1NzY5N30.aZJVU1x76CTI7wYhYBZ5WDYH_PAUibE_iG2zxZQTzK8',
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}