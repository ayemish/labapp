import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app.dart';
import 'auth_service.dart';
import 'verify_email_page.dart';
import 'vendor_dashboard.dart';
import 'role_selection_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'LabApp',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      // FIX: Use FirebaseAuth.instance.authStateChanges() instead of authService.userStream
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('=== AUTH WRAPPER UPDATE ===');
        print('Connection state: ${snapshot.connectionState}');
        print('Has data: ${snapshot.hasData}');
        print('User: ${snapshot.data?.email}');
        print('Email verified: ${snapshot.data?.emailVerified}');
        print('AuthService userRole: ${authService.userRole}');
        print('AuthService isLoggedIn: ${authService.isLoggedIn}');
        print('========================');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // 1. No user logged in
        if (user == null) {
          print('No user - going to RoleSelectionPage');
          return RoleSelectionPage();
        }

        // 2. User exists but email not verified
        if (!user.emailVerified) {
          print('User exists but email not verified - going to VerifyEmailPage');
          return VerifyEmailPage();
        }

        // 3. User exists and email verified - check role
        // The check here relies on the corrected AuthService to have already
        // determined the role before this rebuild.
        if (authService.userRole.isEmpty) {
          print('Email verified but role not determined - showing loading');
          // This should only show momentarily if the asynchronous role check
          // in the listener/signIn hasn't completed.
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Determining your role...'),
                ],
              ),
            ),
          );
        }

        // 4. Route based on user role
        if (authService.userRole == 'vendor') {
          print('Role is vendor - going to VendorDashboard');
          return VendorDashboard();
        } else if (authService.userRole == 'customer') {
          print('Role is customer - going to App');
          return App();
        }

        // 5. Error state
        print('No role found - showing error');
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Unable to determine user role',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => authService.signOut(),
                  child: Text('Sign Out'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}