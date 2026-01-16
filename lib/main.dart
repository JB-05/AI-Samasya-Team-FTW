import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/design_tokens.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

// =============================================================================
// CONFIGURATION
// =============================================================================
const supabaseUrl = 'https://kexnagatdldpfskxjrpj.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtleG5hZ2F0ZGxkcGZza3hqcnBqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg1NTE4NDAsImV4cCI6MjA4NDEyNzg0MH0.1pwSC5KUG50JNObjEimYkJ2eHEm-M9Qi7-hgnHfDxcE';
const backendUrl = 'http://127.0.0.1:8000';
// =============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  runApp(const NeuroPlayApp());
}

SupabaseClient get supabase => Supabase.instance.client;

class NeuroPlayApp extends StatelessWidget {
  const NeuroPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroPlay',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        
        if (session != null) {
          return const HomeShell();
        }
        
        return const LoginScreen();
      },
    );
  }
}
