import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardHODScreen extends StatefulWidget {
  const OnboardHODScreen({super.key});

  @override
  State<OnboardHODScreen> createState() => _OnboardHODScreenState();
}

class _OnboardHODScreenState extends State<OnboardHODScreen> {
  final _emailController = TextEditingController();
  final _deptController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _appointHOD() async {
    final String email = _emailController.text.trim();
    final String dept = _deptController.text.trim().toUpperCase();
    final String password = _passController.text.trim();
    final String fullName = _nameController.text.trim();

    if (email.isEmpty || dept.isEmpty || password.isEmpty || fullName.isEmpty) {
      _showMsg("All fields are required", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    FirebaseApp? tempApp;

    try {
      var existing = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'hod')
          .where('department', isEqualTo: dept)
          .get();

      if (existing.docs.isNotEmpty) {
        _showMsg("Error: $dept already has an appointed HOD!", Colors.red);
        setState(() => _isLoading = false);
        return;
      }

      tempApp = await Firebase.initializeApp(
        name: 'TemporaryApp',
        options: Firebase.app().options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: email, password: password);

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'fullName': fullName,
        'email': email,
        'department': dept,
        'role': 'hod',
        'createdAt': FieldValue.serverTimestamp(),
        'uid': userCredential.user!.uid,
      });

      await tempApp.delete();

      _showMsg("HOD Appointed for $dept!", Colors.green);
      if (mounted) Navigator.pop(context);

    } catch (e) {
      if (tempApp != null) await tempApp.delete();
      _showMsg("Error: ${e.toString()}", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFa2cffe),
      appBar: AppBar(
        title: Text("APPOINT HOD", style: GoogleFonts.oswald(letterSpacing: 2)),
        backgroundColor: const Color(0xFF03045E),
        foregroundColor: Colors.white,
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFa2cffe), Color(0xFF00509D)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.security, size: 60, color: Color(0xFF03045E)),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "HOD Full Name", prefixIcon: Icon(Icons.person))
                  ),
                  const SizedBox(height: 15),
                  TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: "HOD Email ID", prefixIcon: Icon(Icons.email))
                  ),
                  const SizedBox(height: 15),
                  TextField(
                      controller: _deptController,
                      decoration: const InputDecoration(labelText: "Department (e.g., CS, ME)", prefixIcon: Icon(Icons.business))
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "Temporary Password",
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF03045E),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                    ),
                    onPressed: _appointHOD,
                    child: const Text("CONFIRM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}