import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'info_list_builder.dart';
import 'package:intl/intl.dart';

class AlertsTab extends StatefulWidget {
  final String userRole;
  const AlertsTab({super.key, required this.userRole});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  void _showSuccessSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canManage = (widget.userRole.toLowerCase() == 'admin' || widget.userRole.toLowerCase() == 'hod');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 15, 40, 5),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: "Search alerts...",
              prefixIcon: const Icon(Icons.search, color: Color(0xFF03045E)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(35), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('alerts').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              DateTime now = DateTime.now();
              DateTime today = DateTime(now.year, now.month, now.day);

              final alerts = snapshot.data?.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).where((item) {
                bool matchesSearch = (item['title'] ?? "").toString().toLowerCase().contains(_searchQuery);

                DateTime alertDate = (item['startDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
                DateTime alertDayOnly = DateTime(alertDate.year, alertDate.month, alertDate.day);
                bool isUpcoming = alertDayOnly.isAtSameMomentAs(today) || alertDayOnly.isAfter(today);

                return matchesSearch && isUpcoming;
              }).toList() ?? [];

              alerts.sort((a, b) {
                DateTime dateA = (a['startDate'] as Timestamp?)?.toDate() ?? DateTime(2100);
                DateTime dateB = (b['startDate'] as Timestamp?)?.toDate() ?? DateTime(2100);
                return dateA.compareTo(dateB);
              });

              if (alerts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_outlined, size: 80, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(height: 10),
                      Text(
                        "No upcoming announcements",
                        style: GoogleFonts.oswald(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 18,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return InfoListBuilder(
                itemCount: alerts.length,
                icon: Icons.campaign,
                data: alerts,
                canManage: canManage,
                onDelete: (id) async {
                  await FirebaseFirestore.instance.collection('alerts').doc(id).delete();
                  _showSuccessSnack("Alert deleted successfully");
                },
                onEdit: (item) => _showEditAlert(context, item),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditAlert(BuildContext context, Map<String, dynamic> item) {
    final titleC = TextEditingController(text: item['title']);
    final descC = TextEditingController(text: item['description']);
    DateTime? selectedDate = (item['startDate'] as Timestamp?)?.toDate();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text("EDIT ALERT", style: GoogleFonts.oswald(color: const Color(0xFF03045E), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: "Title (Required)")),
                TextField(controller: descC, decoration: const InputDecoration(labelText: "Description (Required)"), maxLines: 3),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(selectedDate == null
                      ? "Select Date (Required)"
                      : DateFormat('dd MMM yyyy').format(selectedDate!)
                  ),
                  trailing: const Icon(Icons.date_range, color: Color(0xFF03045E)),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF03045E))),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF03045E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                if (titleC.text.trim().isEmpty || descC.text.trim().isEmpty || selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are required")));
                  return;
                }

                await FirebaseFirestore.instance.collection('alerts').doc(item['id']).update({
                  'title': titleC.text.trim(),
                  'description': descC.text.trim(),
                  'date': DateFormat('dd MMM yyyy').format(selectedDate!),
                  'startDate': Timestamp.fromDate(selectedDate!),
                  'endDate': Timestamp.fromDate(selectedDate!),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccessSnack("Alert updated successfully");
                }
              },
              child: const Text("UPDATE", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}