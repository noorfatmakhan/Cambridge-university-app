import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cambridge_university/auth/services/auth_services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback onBackToEvents;
  const ProfileTab({super.key, required this.onBackToEvents});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  // --- FORM & CONTROLLERS ---
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // --- STATE VARIABLES ---
  Key _expansionTileKey = UniqueKey();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isUpdating = false;
  int _selectedRating = 0;
  String? _oldPasswordError;

  // --- THEME COLORS ---
  final Color midnightBlue = const Color(0xFF03045E);
  final Color powderBlue = const Color(0xFFCAF0F8);
  final Color blue = const Color(0xFFa2cffe);
  final Color royalBlue = const Color(0xFF00509D);

  @override
  void dispose() {
    _feedbackController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- LOGIC METHODS ---

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- CONTACT US LOGIC ---
  Future<void> _contactSupport(String type) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@cambridge.edu',
      query: 'subject=App Support Request',
    );

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: '+919876543210',
    );

    try {
      if (type == 'email') {
        await launchUrl(emailUri);
      } else {
        await launchUrl(phoneUri);
      }
    } catch (e) {
      _showSuccessSnackBar("Could not open $type app");
    }
  }

  void _showContactOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
        decoration: BoxDecoration(
          color: powderBlue,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20), // Corrected EdgeInsets
              decoration: BoxDecoration(color: midnightBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            ),
            Text("GET IN TOUCH", style: GoogleFonts.oswald(fontSize: 22, color: midnightBlue, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            _buildContactCard(
              icon: Icons.alternate_email_rounded,
              color: Colors.redAccent,
              title: "Email Support",
              subtitle: "support@cambridge.edu",
              onTap: () {
                Navigator.pop(context);
                _contactSupport('email');
              },
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: Icons.phone_forwarded_rounded,
              color: Colors.green.shade700,
              title: "Call Administration",
              subtitle: "+91 98765 43210",
              onTap: () {
                Navigator.pop(context);
                _contactSupport('phone');
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: midnightBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: TextStyle(color: midnightBlue.withOpacity(0.6), fontSize: 12)),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: midnightBlue.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return "Password required";
    if (value == _oldPasswordController.text) return "Cannot be same as old password";
    if (value.length < 6 || !value.contains(RegExp(r'[0-9]')) || !value.contains(RegExp(r'[!@#\$&*~]'))) {
      return "Must contain 6+ char, 1+ special char, 1+ number";
    }
    return null;
  }

  Future<void> _handlePasswordReset(String email) async {
    setState(() => _oldPasswordError = null);
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isUpdating = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: _oldPasswordController.text.trim(),
      );

      try {
        await user.reauthenticateWithCredential(credential);
      } catch (e) {
        setState(() {
          _oldPasswordError = "Incorrect current password";
          _isUpdating = false;
        });
        _formKey.currentState!.validate();
        return;
      }

      await user.updatePassword(_newPasswordController.text.trim());
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) _showSuccessSnackBar("Password updated successfully!");

      setState(() {
        _oldPasswordError = null;
        _expansionTileKey = UniqueKey();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _submitFeedback(String uid) async {
    if (_selectedRating == 0) return;
    try {
      await FirebaseFirestore.instance.collection('user_feedback').add({
        'uid': uid,
        'rating': _selectedRating,
        'sentiment': _ratingLabel,
        'comment': _feedbackController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() {
        _selectedRating = 0;
        _feedbackController.clear();
      });
      _showSuccessSnackBar("Thank you for your feedback!");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Submission failed"), backgroundColor: Colors.red));
    }
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: powderBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Privacy Policy", style: GoogleFonts.oswald(color: midnightBlue, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _policySection("Data Collection", "We collect your name, email, and academic department to provide personalized campus services and secure authentication."),
              _policySection("Data Usage", "Your information is used solely for academic purposes, event notifications, and improving campus communication."),
              _policySection("Security", "Your data is protected using university-grade SSL encryption and Firebase Secure Storage."),
              _policySection("Third Parties", "We do not sell, trade, or share your personal information with outside parties."),
              _policySection("Your Rights", "You have the right to request data deletion or update your profile information at any time."),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CLOSE", style: TextStyle(color: midnightBlue, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _policySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: royalBlue, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(color: royalBlue.withOpacity(0.8), fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  String get _ratingLabel {
    if (_selectedRating == 0) return "Select Stars";
    if (_selectedRating <= 1) return "Very Bad";
    if (_selectedRating <= 2) return "Bad";
    if (_selectedRating == 3) return "Average";
    if (_selectedRating <= 4) return "Good";
    return "Excellent!";
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [blue, royalBlue], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

              var userData = snapshot.data?.data() as Map<String, dynamic>?;
              String name = userData?['fullName'] ?? 'User';
              String email = userData?['email'] ?? user?.email ?? '';
              String dept = userData?['department'] ?? 'General';
              String role = (userData?['role'] ?? 'student').toString().toLowerCase();
              String idVal = (role == 'student') ? (userData?['studentId'] ?? 'N/A') : role.toUpperCase();

              return Column(
                children: [
                  _buildBackButton(),
                  const SizedBox(height: 10),
                  const CircleAvatar(radius: 50, backgroundColor: Color(0xFFCAF0F8), child: Icon(Icons.person, size: 60, color: Color(0xFF03045E))),
                  const SizedBox(height: 10),
                  Text(name.toUpperCase(), style: GoogleFonts.oswald(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),

                  _sectionTitle("ACCOUNT PROFILE"),
                  _cardContainer([
                    _buildListRow(Icons.badge, (role == 'student') ? "Student ID" : "Role", idVal),
                    _buildDivider(),
                    _buildListRow(Icons.email, "Email", email),
                    _buildDivider(),
                    _buildListRow(Icons.business, "Department", dept),
                  ]),
                  const SizedBox(height: 25),

                  _sectionTitle("SECURITY"),
                  _cardContainer([
                    ExpansionTile(
                      key: _expansionTileKey,
                      leading: Icon(Icons.security, color: midnightBlue),
                      title: Text("Change Password", style: TextStyle(color: midnightBlue, fontWeight: FontWeight.bold)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputField(
                                  controller: _oldPasswordController,
                                  hint: "Enter Current Password",
                                  obscure: _obscureOld,
                                  toggle: () => setState(() => _obscureOld = !_obscureOld),
                                  validator: (v) => (v == null || v.isEmpty) ? "Enter current password" : _oldPasswordError,
                                ),
                                const SizedBox(height: 12),
                                _buildInputField(
                                  controller: _newPasswordController,
                                  hint: "Enter New Password",
                                  obscure: _obscureNew,
                                  toggle: () => setState(() => _obscureNew = !_obscureNew),
                                  validator: _validateNewPassword,
                                ),
                                const SizedBox(height: 12),
                                _buildInputField(
                                  controller: _confirmPasswordController,
                                  hint: "Confirm New Password",
                                  obscure: _obscureConfirm,
                                  toggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  validator: (v) => (v != _newPasswordController.text) ? "Passwords do not match" : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text("Requirements: \n6+ char \n1+ special char \n1+ number", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.lightGreen.shade900)),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isUpdating ? null : () => _handlePasswordReset(email),
                                    style: ElevatedButton.styleFrom(backgroundColor: midnightBlue, padding: const EdgeInsets.symmetric(vertical: 12)),
                                    child: _isUpdating
                                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Text("UPDATE PASSWORD", style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ]),
                  const SizedBox(height: 25),

                  _sectionTitle("SUPPORT & LEGAL"),
                  _cardContainer([
                    ListTile(
                      leading: Icon(Icons.share, color: midnightBlue),
                      title: Text("Share App", style: TextStyle(color: midnightBlue, fontWeight: FontWeight.bold)),
                      trailing: Icon(Icons.chevron_right, color: midnightBlue),
                      onTap: () {
                        const String message = 'Join the digital campus! Download the Cambridge University App here:\n\nAndroid: [LINK]\niOS: [LINK]';
                        Share.share(message, subject: 'Cambridge University App');
                      },
                    ),
                    _buildDivider(),
                    ListTile(
                      leading: Icon(Icons.contact_support_outlined, color: midnightBlue),
                      title: Text("Contact Us", style: TextStyle(color: midnightBlue, fontWeight: FontWeight.bold)),
                      trailing: Icon(Icons.chevron_right, color: midnightBlue),
                      onTap: _showContactOptions,
                    ),
                    _buildDivider(),
                    ListTile(
                      leading: Icon(Icons.privacy_tip_outlined, color: midnightBlue),
                      title: Text("Privacy Policy", style: TextStyle(color: midnightBlue, fontWeight: FontWeight.bold)),
                      trailing: Icon(Icons.chevron_right, color: midnightBlue),
                      onTap: _showPrivacyPolicy,
                    ),
                  ]),
                  const SizedBox(height: 25),

                  _sectionTitle("INFORMATION"),
                  _cardContainer([
                    ExpansionTile(
                      leading: Icon(Icons.info_outline, color: midnightBlue),
                      title: Text("About the App", style: TextStyle(color: midnightBlue, fontWeight: FontWeight.bold)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Cambridge University", style: GoogleFonts.oswald(fontSize: 18, color: royalBlue, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Text("The Cambridge University App is a centralized digital ecosystem designed for the modern campus. By integrating real-time synchronization and secure role-based access, we bridge the communication gap between faculty and students.", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, height: 1.4, color: royalBlue)),
                              const SizedBox(height: 15),
                              _buildAboutBullet("Cloud Integrated", "Powered by Firebase for instant, real-time data updates across all devices."),
                              _buildAboutBullet("Cross-Platform", "Built with Flutter to provide a native experience on both Android and iOS."),
                              _buildAboutBullet("Smart Management", "Features automated event cleanup and professional PDF report generation."),
                              Divider(height: 30, color: midnightBlue.withOpacity(0.2)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Version: 1.0.0 (Stable)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: royalBlue)),
                                  Text("Built with Flutter & Firebase", style: TextStyle(fontSize: 10, color: royalBlue.withOpacity(0.5))),
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    )
                  ]),
                  const SizedBox(height: 25),

                  if (role != 'admin') ...[
                    _sectionTitle("APP EXPERIENCE"),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) => IconButton(
                              icon: Icon(i < _selectedRating ? Icons.star : Icons.star_border, color: Colors.green.shade900, size: 35),
                              onPressed: () => setState(() => _selectedRating = i + 1),
                            )),
                          ),
                          Text(_ratingLabel.toUpperCase(), style: TextStyle(color: _selectedRating <= 2 && _selectedRating != 0 ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _feedbackController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "What can we do better?", hintStyle: const TextStyle(color: Colors.white54),
                              filled: true, fillColor: midnightBlue.withOpacity(0.2),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => _submitFeedback(user?.uid ?? ""),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: midnightBlue),
                            child: const Text("SUBMIT FEEDBACK"),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],

                  _buildLogoutButton(),
                  const SizedBox(height: 30),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- REUSABLE WIDGETS ---

  Widget _buildAboutBullet(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10), // Corrected EdgeInsets
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: midnightBlue),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: royalBlue, height: 1.3),
                children: [
                  TextSpan(text: "$title: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String hint, required bool obscure, required VoidCallback toggle, required String? Function(String?) validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(fontSize: 14, color: midnightBlue),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: midnightBlue.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white,
        errorStyle: const TextStyle(color: Color(0xFFD00000), fontWeight: FontWeight.bold),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: midnightBlue), onPressed: toggle),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.topLeft,
      child: InkWell(
        onTap: widget.onBackToEvents,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Text("BACK", style: GoogleFonts.oswald(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
        onPressed: () => AuthService().signOut(),
        icon: const Icon(Icons.power_settings_new, color: Colors.white),
        label: Text("LOG OUT", style: GoogleFonts.oswald(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _cardContainer(List<Widget> children) => Container(decoration: BoxDecoration(color: powderBlue, borderRadius: BorderRadius.circular(20)), child: Column(children: children));

  Widget _sectionTitle(String t) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 10, bottom: 8), child: Text(t, style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13, letterSpacing: 1.2))));

  Widget _buildListRow(IconData i, String l, String v) => ListTile(leading: Icon(i, color: midnightBlue), title: Text(l, style: const TextStyle(fontSize: 11, color: Colors.black54)), subtitle: Text(v, style: TextStyle(color: midnightBlue, fontSize: 16, fontWeight: FontWeight.bold)));

  Widget _buildDivider() => Divider(color: midnightBlue.withOpacity(0.1), height: 1, indent: 15, endIndent: 15);
}