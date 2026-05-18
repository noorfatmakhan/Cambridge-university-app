import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'info_list_builder.dart';

class EventsTab extends StatefulWidget {
  final String userRole;
  final String userId;

  const EventsTab({super.key, required this.userRole, required this.userId});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
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

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = (widget.userRole.toLowerCase() == 'admin' ||
        widget.userRole.toLowerCase() == 'hod');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 15, 40, 5),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: "Search events...",
              prefixIcon: const Icon(Icons.search, color: midnightBlue),
              filled: true,
              fillColor: Colors.white.withAlpha(230),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(35), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('events').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData) return const SizedBox();

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              // 1. Process, Filter, and Auto-Delete
              List<Map<String, dynamic>> processedEvents = [];

              for (var doc in snapshot.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                String dateRange = d['date'] ?? "";

                if (dateRange.isNotEmpty) {
                  try {
                    // Extract end date for Auto-Delete check
                    String endDateStr = dateRange.contains('-')
                        ? dateRange.split('-').last.trim()
                        : dateRange;
                    DateTime eventEndDate = DateFormat('dd MMM yyyy').parse(endDateStr);

                    if (eventEndDate.isBefore(today)) {
                      FirebaseFirestore.instance.collection('events').doc(doc.id).delete();
                      continue; // Skip this doc
                    }

                    // Add parsed DateTime for sorting purposes
                    String startDateStr = dateRange.contains('-')
                        ? dateRange.split('-').first.trim()
                        : dateRange;

                    // If start date is missing the year (e.g. "25 Feb"), append the year from end date
                    if (!startDateStr.contains(RegExp(r'\d{4}'))) {
                      String year = endDateStr.split(' ').last;
                      startDateStr = "$startDateStr $year";
                    }

                    d['_parsedSortDate'] = DateFormat('dd MMM yyyy').parse(startDateStr);
                  } catch (e) {
                    debugPrint("Date parse error: $e");
                    d['_parsedSortDate'] = DateTime(2099); // Put errors at the end
                  }
                } else {
                  d['_parsedSortDate'] = DateTime(2099);
                }

                // Search Filter
                if ((d['title'] ?? "").toString().toLowerCase().contains(_searchQuery)) {
                  d['id'] = doc.id;
                  List interested = d['interestedStudents'] ?? [];
                  d['isUserRegistered'] = interested.any((s) => s is Map && s['uid'] == widget.userId);
                  d['showRegistrationCount'] = isAdmin;
                  processedEvents.add(d);
                }
              }

              // 2. Sort Date-Wise (Ascending: Soonest events first)
              processedEvents.sort((a, b) => (a['_parsedSortDate'] as DateTime).compareTo(b['_parsedSortDate'] as DateTime));

              if (processedEvents.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_outlined, size: 80, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(height: 10),
                      Text("No upcoming events",
                          style: GoogleFonts.oswald(color: Colors.white.withOpacity(0.8), fontSize: 18)),
                    ],
                  ),
                );
              }

              return InfoListBuilder(
                itemCount: processedEvents.length,
                icon: Icons.event_available,
                data: processedEvents,
                canManage: isAdmin,
                onDelete: (id) async {
                  await FirebaseFirestore.instance.collection('events').doc(id).delete();
                  _showSuccessSnack("Event deleted successfully");
                },
                onEdit: (item) => _showEditEventDialog(context, item),
                onTap: (item) => isAdmin ? _viewStudents(context, item) : _handleRegistration(context, item),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleRegistration(BuildContext context, Map<String, dynamic> item) async {
    List students = item['interestedStudents'] ?? [];
    int fee = int.tryParse(item['fee'].toString()) ?? 0;
    var userEntry = students.firstWhere((s) => s is Map && s['uid'] == widget.userId, orElse: () => null);

    if (userEntry != null) {
      if (fee == 0) {
        bool? confirm = await _showConfirmDialog(
            context,
            "UNREGISTER",
            "You are already registered. Do you want to unregister from this event?"
        );
        if (confirm == true) {
          _unregisterUser(item, userEntry);
        }
      } else {
        _showSimpleDialog(context, "REGISTRATION STATUS", "You are officially registered for this event.");
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(fee == 0 ? "EVENT REGISTRATION" : "PAYMENT REQUIRED",
            style: GoogleFonts.oswald(color: midnightBlue, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fee > 0) ...[
              Text("Entry Fee: ₹$fee", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              const Text("Did you complete the payment successfully?", textAlign: TextAlign.center),
            ] else
              const Text("Would you like to register for this free event?"),
          ],
        ),
        actions: [
          if (fee > 0) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showSimpleDialog(context, "PAYMENT FAILED", "Payment failed. Please retry.");
              },
              child: const Text("FAILURE", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(context);
                _finalizeRegistration(item);
              },
              child: const Text("SUCCESS", style: TextStyle(color: Colors.white)),
            ),
          ] else ...[
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: midnightBlue),
              onPressed: () {
                Navigator.pop(context);
                _finalizeRegistration(item);
              },
              child: const Text("CONFIRM", style: TextStyle(color: Colors.white)),
            )
          ]
        ],
      ),
    );
  }

  Future<void> _finalizeRegistration(Map<String, dynamic> item) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    var userData = userDoc.data() as Map<String, dynamic>?;

    await FirebaseFirestore.instance.collection('events').doc(item['id']).update({
      'interestedStudents': FieldValue.arrayUnion([{
        'uid': widget.userId,
        'fullName': _capitalize(userData?['fullName'] ?? "Student"),
        'studentId': userData?['studentId'] ?? "N/A",
        'status': 'Approved'
      }])
    });
    _showSuccessSnack("Registration successful");
  }

  Future<void> _unregisterUser(Map<String, dynamic> item, dynamic userEntry) async {
    await FirebaseFirestore.instance.collection('events').doc(item['id']).update({
      'interestedStudents': FieldValue.arrayRemove([userEntry])
    });
    _showSuccessSnack("Unregistered successfully");
  }

  void _viewStudents(BuildContext context, Map<String, dynamic> item) {
    List students = item['interestedStudents'] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("REGISTERED STUDENTS", style: GoogleFonts.oswald(fontSize: 22, color: midnightBlue, fontWeight: FontWeight.bold)),
                if (students.isNotEmpty)
                  IconButton(onPressed: () => _generatePdf(item), icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30)),
              ],
            ),
            const Divider(thickness: 1),
            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text("No registrations yet."))
                  : ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, i) {
                  var s = students[i];
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: midnightBlue, child: Icon(Icons.person, color: Colors.white, size: 20)),
                    title: Text(s['fullName'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("ID: ${s['studentId']}"),
                    trailing: const Icon(Icons.check_circle, color: Colors.green),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEventDialog(BuildContext context, Map<String, dynamic> item) {
    final titleC = TextEditingController(text: item['title']);
    final descC = TextEditingController(text: item['description']);
    final venueC = TextEditingController(text: item['venue']);
    final feeC = TextEditingController(text: (item['fee'] ?? 0).toString());
    String dateStr = item['date'] ?? "";
    String timeStr = item['time'] ?? "";

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: Text("EDIT EVENT DETAILS", style: GoogleFonts.oswald(color: midnightBlue, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: "Event Title")),
                TextField(controller: descC, decoration: const InputDecoration(labelText: "Description")),
                TextField(controller: venueC, decoration: const InputDecoration(labelText: "Venue")),
                TextField(
                  controller: feeC,
                  decoration: const InputDecoration(labelText: "Fee (0 if Free)"),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(dateStr.isEmpty ? "Select Date" : dateStr, style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.calendar_today, color: midnightBlue),
                  onTap: () async {
                    final p = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030)
                    );
                    if (p != null) {
                      setS(() => dateStr = "${DateFormat('dd MMM').format(p.start)} - ${DateFormat('dd MMM yyyy').format(p.end)}");
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(timeStr.isEmpty ? "Select Time" : timeStr, style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.access_time, color: midnightBlue),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (t != null) setS(() => timeStr = t.format(context));
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("CANCEL")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: midnightBlue),
              onPressed: () async {
                if (titleC.text.isEmpty) return;
                await FirebaseFirestore.instance.collection('events').doc(item['id']).update({
                  'title': _capitalize(titleC.text),
                  'description': _capitalize(descC.text),
                  'venue': _capitalize(venueC.text),
                  'fee': int.tryParse(feeC.text) ?? 0,
                  'date': dateStr,
                  'time': timeStr,
                });
                Navigator.pop(dialogContext);
                _showSuccessSnack("Event updated successfully");
              },
              child: const Text("UPDATE", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _showSimpleDialog(BuildContext context, String title, String msg) {
    showDialog(context: context, builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.oswald(color: midnightBlue, fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]
    ));
  }

  Future<bool?> _showConfirmDialog(BuildContext context, String title, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
          title: Text(title, style: GoogleFonts.oswald(color: midnightBlue, fontWeight: FontWeight.bold)),
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("NO")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("YES"))
          ]
      ),
    ) ?? false;
  }

  Future<void> _generatePdf(Map<String, dynamic> item) async {
    final pdf = pw.Document();
    final List students = item['interestedStudents'] ?? [];

    pdf.addPage(pw.MultiPage(
      build: (pw.Context context) => [
        pw.Header(level: 0, child: pw.Text("ATTENDEE LIST: ${item['title'].toString().toUpperCase()}")),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
          data: <List<String>>[
            <String>['No.', 'Name', 'Student ID', 'Status'],
            ...students.asMap().entries.map((e) {
              var s = e.value;
              return [
                (e.key + 1).toString(),
                s['fullName'].toString(),
                s['studentId'].toString(),
                s['status'].toString(),
              ];
            }),
          ],
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: '${item['title']}_Attendees.pdf');
    _showSuccessSnack("PDF generated successfully");
  }
}