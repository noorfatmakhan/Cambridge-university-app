import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'info_list_builder.dart';

class HolidaysTab extends StatefulWidget {
  final String userRole;
  const HolidaysTab({super.key, required this.userRole});

  @override
  State<HolidaysTab> createState() => _HolidaysTabState();
}

class _HolidaysTabState extends State<HolidaysTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  static const Color midnightBlue = Color(0xFF03045E);

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

  DateTime _getDateTimeFromString(String dateStr) {
    try {
      String firstDate = dateStr.split('-')[0].trim();
      if (!firstDate.contains(RegExp(r'\d{4}'))) {
        String year = dateStr.split(' ').last;
        firstDate = "$firstDate $year";
      }
      return DateFormat('dd MMM yyyy').parse(firstDate);
    } catch (e) {
      return DateTime(2099);
    }
  }

  // --- HELPER: GET END DATE FROM STRING ---
  DateTime _getEndDateTimeFromString(String dateStr) {
    try {
      if (!dateStr.contains('-')) return _getDateTimeFromString(dateStr);
      String lastPart = dateStr.split('-').last.trim();
      // Ensure the year is present
      if (!lastPart.contains(RegExp(r'\d{4}'))) {
        return _getDateTimeFromString(dateStr);
      }
      return DateFormat('dd MMM yyyy').parse(lastPart);
    } catch (e) {
      return _getDateTimeFromString(dateStr);
    }
  }

  void _showHolidayDialog(Map<String, dynamic>? item) {
    final titleC = TextEditingController(text: item?['title']);
    DateTimeRange? range;
    bool isEdit = item != null;

    // PRE-FILL DATES IF EDITING
    if (isEdit && item['date'] != null) {
      DateTime start = _getDateTimeFromString(item['date']);
      DateTime end = _getEndDateTimeFromString(item['date']);
      range = DateTimeRange(start: start, end: end);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text(isEdit ? "EDIT HOLIDAY" : "ADD NEW HOLIDAY",
              style: GoogleFonts.oswald(color: midnightBlue, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleC, decoration: const InputDecoration(labelText: "Holiday Name")),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: midnightBlue,
                  minimumSize: const Size(double.infinity, 45),
                ),
                onPressed: () async {
                  DateTimeRange? p = await showDateRangePicker(
                      context: context,
                      initialDateRange: range,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(primary: midnightBlue),
                          ),
                          child: child!,
                        );
                      }
                  );
                  if (p != null) setDialogState(() => range = p);
                },
                icon: const Icon(Icons.calendar_today, color: Colors.white),
                label: Text(range == null ? "Select Date Range" : "Dates Selected",
                    style: const TextStyle(color: Colors.white)),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: midnightBlue),
              onPressed: () async {
                if (titleC.text.trim().isEmpty) return;
                String formattedTitle = titleC.text.trim()[0].toUpperCase() + titleC.text.trim().substring(1);
                Map<String, dynamic> data = {'title': formattedTitle};

                if (range != null) {
                  data['date'] = range!.start == range!.end
                      ? DateFormat('dd MMM yyyy').format(range!.start)
                      : "${DateFormat('dd MMM').format(range!.start)} - ${DateFormat('dd MMM yyyy').format(range!.end)}";
                }

                if (isEdit) {
                  await FirebaseFirestore.instance.collection('holidays').doc(item['id']).update(data);
                  _showSuccessSnack("Holiday updated successfully");
                } else {
                  await FirebaseFirestore.instance.collection('holidays').add(data);
                  _showSuccessSnack("Holiday added successfully");
                }
                if (mounted) Navigator.pop(context);
              },
              child: const Text("SAVE", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
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
              hintText: "Search holidays...",
              prefixIcon: const Icon(Icons.search, color: midnightBlue),
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(35), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('holidays').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData) return const SizedBox();

              DateTime now = DateTime.now();
              DateTime today = DateTime(now.year, now.month, now.day);

              final holidays = snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).where((item) {
                String dateStr = item['date'] ?? "";
                DateTime hDate = _getDateTimeFromString(dateStr);
                DateTime hDayOnly = DateTime(hDate.year, hDate.month, hDate.day);

                bool isUpcoming = hDayOnly.isAtSameMomentAs(today) || hDayOnly.isAfter(today);
                bool matchesSearch = item['title'].toString().toLowerCase().contains(_searchQuery);

                return isUpcoming && matchesSearch;
              }).toList();

              holidays.sort((a, b) {
                DateTime dateA = _getDateTimeFromString(a['date'] ?? "");
                DateTime dateB = _getDateTimeFromString(b['date'] ?? "");
                return dateA.compareTo(dateB);
              });

              if (holidays.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.beach_access_outlined, size: 80, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(height: 10),
                      Text("No upcoming holidays",
                          style: GoogleFonts.oswald(color: Colors.white.withOpacity(0.8), fontSize: 18)),
                    ],
                  ),
                );
              }

              return InfoListBuilder(
                itemCount: holidays.length,
                icon: Icons.celebration,
                data: holidays,
                canManage: canManage,
                onDelete: (id) async {
                  await FirebaseFirestore.instance.collection('holidays').doc(id).delete();
                  _showSuccessSnack("Holiday deleted successfully");
                },
                onEdit: (item) => _showHolidayDialog(item),
              );
            },
          ),
        ),
      ],
    );
  }
}