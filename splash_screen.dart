import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cambridge_university/auth/services/auth_services.dart';
import 'dart:async';
import 'auth_wrapper.dart';
import 'package:cambridge_university/home/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _startAnimation = false;

  @override
  void initState() {
    super.initState();
    // animations
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _startAnimation = true);
    });
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(seconds: 4));

    if (!mounted) return;

    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String? role = await AuthService().getCurrentUserRole();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 1000),
            pageBuilder: (context, anim, rel) => DashboardScreen(userRole: role ?? 'student'),
            transitionsBuilder: (context, anim, rel, child) => FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryDark = Color(0xFF03045E);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFa2cffe), Color(0xFF00509D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // MAIN TITLE ANIMATION
            AnimatedOpacity(
              duration: const Duration(milliseconds: 1200),
              opacity: _startAnimation ? 1.0 : 0.0,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 1200),
                padding: EdgeInsets.only(bottom: _startAnimation ? 0 : 30),
                child: Text(
                  'CAMBRIDGE\nUNIVERSITY',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: primaryDark,
                    letterSpacing: 6,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(2, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // SUBTITLE ANIMATION
            AnimatedOpacity(
              duration: const Duration(milliseconds: 1500),
              opacity: _startAnimation ? 1.0 : 0.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: primaryDark.withOpacity(0.3), width: 1),
                    bottom: BorderSide(color: primaryDark.withOpacity(0.3), width: 1),
                  ),
                ),
                child: Text(
                  'EXCELLENCE IN LEARNING',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: primaryDark.withOpacity(0.8),
                    letterSpacing: 5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 60),

            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _startAnimation ? 0.6 : 0.0,
              child: const SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  color: primaryDark,
                  minHeight: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}