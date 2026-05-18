import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cambridge_university/auth/services/auth_services.dart';
import 'package:cambridge_university/home/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onToggle;
  const LoginScreen({super.key, required this.onToggle});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final Color powderBlue = const Color(0xFFCAF0F8);
  final Color midnightBlue = const Color(0xFF03045E);

  bool _isPasswordVisible = false;
  bool _isHovered = false;
  bool _isLoading = false;

  String? _emailError;
  String? _passError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailError = null;
      _passError = null;
    });

    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();

    bool hasError = false;

    if (email.isEmpty) {
      setState(() => _emailError = "Email is required");
      hasError = true;
    } else if (!email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = "Please enter a valid email address");
      hasError = true;
    }

    if (pass.isEmpty) {
      setState(() => _passError = "Password is required");
      hasError = true;
    }

    if (hasError) return;

    setState(() => _isLoading = true);
    String? error = await AuthService().login(email: email, password: pass);

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        setState(() => _passError = "Invalid email or password");
      } else {
        _showSuccessSnack('Welcome back!');
        String? role = await AuthService().getCurrentUserRole();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(userRole: role ?? 'student'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LOG IN',
          style: GoogleFonts.luxuriousRoman(
            fontSize: 40,
            color: midnightBlue,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),

        // Email Field
        TextFormField(
          controller: _emailController,
          style: const TextStyle(color: Color(0xFF03045E)),
          decoration: _inputDeco('Email', Icons.email, _emailError),
        ),
        const SizedBox(height: 20),

        // Password Field
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          style: const TextStyle(color: Color(0xFF03045E)),
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: _passError,
            errorStyle: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
            labelStyle: TextStyle(color: powderBlue),
            prefixIcon: Icon(Icons.lock, color: midnightBlue),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: midnightBlue,
              ),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: midnightBlue)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
          ),
        ),
        const SizedBox(height: 40),

        _submitButton(),

        const SizedBox(height: 20),
        TextButton(
          onPressed: widget.onToggle,
          child: Text(
            'NEW USER? SIGN UP HERE',
            style: TextStyle(color: powderBlue, decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, String? errorMsg) {
    return InputDecoration(
      labelText: label,
      errorText: errorMsg,
      errorStyle: const TextStyle(color: Colors.amber),
      labelStyle: TextStyle(color: powderBlue),
      prefixIcon: Icon(icon, color: midnightBlue),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: midnightBlue)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
    );
  }

  Widget _submitButton() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: midnightBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 5,
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('LOG IN!', style: GoogleFonts.oswald(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}