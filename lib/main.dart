import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:newsgram/SplashScreen.dart';
import 'package:newsgram/homepage.dart';
import 'package:newsgram/signuppage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // Initialize Supabase only
  await Supabase.initialize(
    url: 'https://khusmzcejezstsngqhhs.supabase.co',
    anonKey: dotenv.env['ANON_KEY'] ?? '',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    storageOptions: const StorageClientOptions(
      retryAttempts: 3, 
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Newsgram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const AuthWrapper(), // Use a wrapper widget
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Hide splash after 2 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen for the first 2 seconds
    if (_showSplash) {
      return const SplashScreen();
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Once we have the auth state, stop loading
        if (snapshot.hasData) {
          Future.microtask(() {
            if (mounted && _isLoading) {
              setState(() {
                _isLoading = false;
              });
            }
          });
        }

        // Check authentication state
        final session = snapshot.data?.session;
        return session == null ? const SignUpPage() : Homepage(viewUser: Supabase.instance.client.auth.currentUser);
      },
    );
  }
}

