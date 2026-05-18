import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cambridge_university/home/dashboard_screen.dart';
import 'package:cambridge_university/auth/services/auth_services.dart';
import 'package:cambridge_university/auth/login_screen.dart';
import 'signup_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool isLogin = true;

  void toggle() => setState(() => isLogin = !isLogin);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<String?>(
            future: AuthService().getCurrentUserRole(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return DashboardScreen(userRole: roleSnapshot.data ?? 'student');
            },
          );
        }

        return Scaffold(
          body: PopScope(
            canPop: isLogin,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (!isLogin) toggle();
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFa2cffe), Color(0xFF00509D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: isLogin
                        ? LoginScreen(key: const ValueKey('Login'), onToggle: toggle)
                        : SignupScreen(key: const ValueKey('Signup'), onToggle: toggle),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}