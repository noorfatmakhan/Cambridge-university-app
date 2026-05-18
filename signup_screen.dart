import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cambridge_university/auth/services/auth_services.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onToggle;
  const SignupScreen({super.key, required this.onToggle});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _departmentController = TextEditingController();
  final _studentIdController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isHovered = false;
  bool _isLoading = false;

  final RegExp passPattern = RegExp(r'^(?=.*[0-9])(?=.*[!@#\$&*~]).{6,}$');
  static const Color midnightBlue = Color(0xFF03045E);
  static const Color powderBlue = Color(0xFFCAF0F8);

  String? _nameError, _emailError, _passError, _deptError, _sIdError;

  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    setState(() {
      _nameError = _emailError = _passError = _deptError = _sIdError = null;
    });

    bool hasError = false;
    if (_nameController.text.isEmpty) { setState(() => _nameError = "Full Name required"); hasError = true; }
    if (_studentIdController.text.length != 6) { setState(() => _sIdError = "Must be exactly 6 digits"); hasError = true; }
    if (!_emailController.text.contains('@')) { setState(() => _emailError = "Invalid email format"); hasError = true; }
    if (!passPattern.hasMatch(_passwordController.text)) { setState(() => _passError = "Need 6+ chars, 1 number, 1 symbol"); hasError = true; }
    if (_departmentController.text.isEmpty) { setState(() => _deptError = "Department required"); hasError = true; }

    if (hasError) return;

    setState(() => _isLoading = true);
    String? error = await AuthService().signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      fullName: _nameController.text.trim(),
      department: _departmentController.text.trim(),
      studentId: _studentIdController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        setState(() => _emailError = "Account creation failed");
      } else {
        // SUCCESS MESSAGE FOR SIGNUP
        _showSuccessSnack('Welcome to Cambridge University!');

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.onToggle();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('SIGN UP', style: GoogleFonts.luxuriousRoman(fontSize: 40, color: midnightBlue, letterSpacing: 2, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildField(_nameController, 'Full Name', Icons.person, _nameError),
        const SizedBox(height: 15),
        _buildField(_studentIdController, 'Student ID', Icons.badge, _sIdError, isNumeric: true),
        const SizedBox(height: 15),
        _buildField(_emailController, 'Email', Icons.email, _emailError),
        const SizedBox(height: 15),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          style: const TextStyle(color: midnightBlue),
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: _passError,
            errorStyle: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
            labelStyle: const TextStyle(color: powderBlue),
            prefixIcon: const Icon(Icons.lock, color: midnightBlue),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: midnightBlue),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: midnightBlue)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
          ),
        ),
        const SizedBox(height: 15),
        _buildField(_departmentController, 'Department', Icons.store, _deptError),
        const SizedBox(height: 30),
        _signUpButton(),
        const SizedBox(height: 10),
        TextButton(onPressed: widget.onToggle, child: const Text('EXISTING USER? LOG IN', style: TextStyle(color: powderBlue, decoration: TextDecoration.underline))),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, String? error, {bool isNumeric = false}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: midnightBlue),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)] : null,
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        errorStyle: const TextStyle(color: Colors.amber),
        labelStyle: const TextStyle(color: powderBlue),
        prefixIcon: Icon(icon, color: midnightBlue),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: midnightBlue)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
      ),
    );
  }

  Widget _signUpButton() {
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
            onPressed: _isLoading ? null : _handleSignUp,
            style: ElevatedButton.styleFrom(backgroundColor: midnightBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('SIGN UP!', style: GoogleFonts.oswald(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}