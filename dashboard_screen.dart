import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'events_tab.dart';
import 'alerts_tab.dart';
import 'holidays_tab.dart';
import 'profile_tab.dart';
import 'summary_tab.dart';

class DashboardScreen extends StatefulWidget {
  final String userRole;
  const DashboardScreen({super.key, required this.userRole});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final Color midnightBlue = const Color(0xFF03045E);
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      SummaryTab(userRole: widget.userRole),
      EventsTab(userRole: widget.userRole, userId: currentUser?.uid ?? ""),
      AlertsTab(userRole: widget.userRole),
      HolidaysTab(userRole: widget.userRole),
      ProfileTab(onBackToEvents: () => setState(() => _selectedIndex = 0)),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFa2cffe),
        elevation: 0,
        centerTitle: true,
        title: Text(
          ['', 'EVENTS', 'ALERTS', 'HOLIDAYS', 'PROFILE'][_selectedIndex],
          style: GoogleFonts.luxuriousRoman(color: midnightBlue, fontWeight: FontWeight.bold, fontSize: 38),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFa2cffe), Color(0xFF00509D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: screens[_selectedIndex],
      ),
      floatingActionButton: (widget.userRole.toLowerCase() == 'admin' || widget.userRole.toLowerCase() == 'hod')
          ? _buildFab()
          : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      height: 65,
      decoration: BoxDecoration(
        color: midnightBlue,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            _navItem(Icons.dashboard, "Dashboard", 0),
            _navItem(Icons.event_rounded, "Events", 1),
            _navItem(Icons.campaign_rounded, "Alerts", 2),
            _navItem(Icons.beach_access_rounded, "Holidays", 3),
            _navItem(Icons.person_rounded, "Profile", 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        splashColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(bottom: 5),
              height: 3,
              width: isSelected ? 20 : 0,
              decoration: BoxDecoration(color: Colors.cyanAccent, borderRadius: BorderRadius.circular(2)),
            ),
            Icon(icon, color: isSelected ? Colors.cyanAccent : Colors.white70, size: 24),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget? _buildFab() {
    IconData icon;
    if (_selectedIndex == 1) icon = Icons.add_task;
    else if (_selectedIndex == 2) icon = Icons.notification_add;
    else if (_selectedIndex == 3) icon = Icons.add;
    else return null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FloatingActionButton(
        backgroundColor: midnightBlue,
        onPressed: () => _showFormDialog(),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  void _showFormDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController venueController = TextEditingController();
    final TextEditingController feeController = TextEditingController();

    DateTimeRange? selectedRange;
    TimeOfDay? selectedTime;

    String collection = _selectedIndex == 1 ? "events" : (_selectedIndex == 2 ? "alerts" : "holidays");

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text("ADD NEW ${collection.toUpperCase()}", style: GoogleFonts.oswald(color: midnightBlue, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title (Required)")),
                if (collection != "holidays")
                  TextField(controller: descController, decoration: const InputDecoration(labelText: "Description (Required)")),

                if (collection == "events") ...[
                  TextField(controller: venueController, decoration: const InputDecoration(labelText: "Venue (Required)")),
                  TextField(controller: feeController, decoration: const InputDecoration(labelText: "Fee (0 for free)"), keyboardType: TextInputType.number),
                ],

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      selectedRange == null
                          ? "Select Date (Required)"
                          : (selectedRange!.start == selectedRange!.end
                          ? DateFormat('dd MMM yyyy').format(selectedRange!.start)
                          : "${DateFormat('dd MMM').format(selectedRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedRange!.end)}")
                  ),
                  trailing: Icon(Icons.date_range, color: selectedRange == null ? Colors.grey : midnightBlue),

                  onTap: () async {
                    if (collection == "alerts") {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: midnightBlue)),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => selectedRange = DateTimeRange(start: picked, end: picked));
                      }
                    } else {
                      final DateTimeRange? picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: midnightBlue)),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setDialogState(() => selectedRange = picked);
                    }
                  },
                ),

                if (collection == "events")
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(selectedTime == null ? "Select Time (Required)" : selectedTime!.format(context)),
                    trailing: Icon(Icons.access_time, color: selectedTime == null ? Colors.grey : midnightBlue),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (picked != null) setDialogState(() => selectedTime = picked);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: midnightBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                bool isTitleEmpty = titleController.text.trim().isEmpty;
                bool isDescEmpty = descController.text.trim().isEmpty;
                bool isVenueEmpty = venueController.text.trim().isEmpty;
                bool isDateEmpty = selectedRange == null;
                bool isTimeEmpty = selectedTime == null;

                String? errorMsg;
                if (collection == "events") {
                  if (isTitleEmpty || isDescEmpty || isVenueEmpty || isDateEmpty || isTimeEmpty) {
                    errorMsg = "Please fill all fields for the Event";
                  }
                } else if (collection == "alerts") {
                  if (isTitleEmpty || isDescEmpty || isDateEmpty) errorMsg = "Title, Description, and Date are required";
                } else if (collection == "holidays") {
                  if (isTitleEmpty || isDateEmpty) errorMsg = "Title and Date Range are required";
                }

                if (errorMsg != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent));
                  return;
                }

                String dateString = "";
                if (selectedRange != null) {
                  dateString = selectedRange!.start == selectedRange!.end
                      ? DateFormat('dd MMM yyyy').format(selectedRange!.start)
                      : "${DateFormat('dd MMM').format(selectedRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedRange!.end)}";
                }

                Map<String, dynamic> data = {
                  "title": titleController.text.trim(),
                  if (collection != "holidays") "description": descController.text.trim(),
                  "timestamp": FieldValue.serverTimestamp(),
                  "date": dateString,
                  "startDate": selectedRange?.start,
                  "endDate": selectedRange?.end,
                };

                if (collection == "events") {
                  data["venue"] = venueController.text.trim();
                  data["fee"] = int.tryParse(feeController.text) ?? 0;
                  data["time"] = selectedTime?.format(context) ?? "";
                  data["interestedStudents"] = [];
                }

                try {
                  await FirebaseFirestore.instance.collection(collection).add(data);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("New ${collection.substring(0, collection.length - 1)} added successfully!"),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Text("SAVE", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}