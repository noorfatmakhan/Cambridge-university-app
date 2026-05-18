import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'package:intl/intl.dart';
import 'new_hod.dart';

class SummaryTab extends StatefulWidget {
  final String userRole;
  const SummaryTab({super.key, required this.userRole});

  @override
  State<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<SummaryTab> {
  static const Color midnightBlue = Color(0xFF03045E);
  static const Color darkTeal = Color(0xFF0077B6);

  // Helper to parse the Holiday date string for sorting/filtering
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

  void _showInfoBox(BuildContext context, String title, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: midnightBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Text(title, style: GoogleFonts.oswald(color: Colors.white, fontSize: 20, letterSpacing: 1.2)),
              const SizedBox(height: 15),
              Expanded(child: ListView(controller: scrollController, children: [content])),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String role = widget.userRole.toLowerCase();
    final bool isStudent = role == 'student';
    final bool isAdmin = role == 'admin';
    final bool isHOD = role == 'hod';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(role),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSectionHeader("NOTICE BOARD"),
          ),
          const SizedBox(height: 15),
          _buildBentoNotices(),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isStudent) ...[
                  // Pending verification card is removed here
                  _buildSectionHeader("EVENT STATS"),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard("Total Events", "events", Icons.event, darkTeal)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildRegistrationTotalCard("Registered", Icons.group, darkTeal)),
                    ],
                  ),
                  const SizedBox(height: 25),
                ],
                if (isAdmin || isHOD) _buildHODDropdown(),
                if (isAdmin) ...[
                  const SizedBox(height: 25),
                  _buildManagementRect(
                    context,
                    title: "APPOINT NEW HOD",
                    subtitle: "Manage HOD credentials.",
                    icon: Icons.admin_panel_settings_rounded,
                    color: const Color(0xFF023E8A),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const OnboardHODScreen()),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String role) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).get(),
        builder: (context, snapshot) {
          String displayName = "...";
          if (snapshot.hasData && snapshot.data!.exists) {
            displayName = snapshot.data!.get('fullName') ?? "User";
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome Back,", style: GoogleFonts.archivo(color: midnightBlue, fontSize: 20)),
              Text(
                displayName.toUpperCase(),
                style: GoogleFonts.luxuriousRoman(
                  color: midnightBlue,
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: midnightBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: GoogleFonts.archivo(color: midnightBlue, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBentoNotices() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    Stream<Map<String, List<Map<String, dynamic>>>> bentoStream = CombineLatestStream.list([
      FirebaseFirestore.instance.collection('events').orderBy('date').snapshots(),
      FirebaseFirestore.instance.collection('holidays').snapshots(),
      FirebaseFirestore.instance.collection('alerts').orderBy('startDate').snapshots(),
    ]).map((List<QuerySnapshot> snapshots) {
      var upcomingEvents = snapshots[0].docs.map((d) => d.data() as Map<String, dynamic>).toList();
      var upcomingHolidays = snapshots[1].docs.map((d) => d.data() as Map<String, dynamic>).where((item) {
        DateTime hDate = _getDateTimeFromString(item['date'] ?? "");
        return hDate.isAtSameMomentAs(today) || hDate.isAfter(today);
      }).toList();
      upcomingHolidays.sort((a, b) => _getDateTimeFromString(a['date']).compareTo(_getDateTimeFromString(b['date'])));
      var upcomingAlerts = snapshots[2].docs.map((d) => d.data() as Map<String, dynamic>).where((item) {
        DateTime aDate = (item['startDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
        DateTime aDayOnly = DateTime(aDate.year, aDate.month, aDate.day);
        return aDayOnly.isAtSameMomentAs(today) || aDayOnly.isAfter(today);
      }).toList();
      return {'event': upcomingEvents, 'holiday': upcomingHolidays, 'alert': upcomingAlerts};
    });

    return StreamBuilder<Map<String, List<Map<String, dynamic>>>>(
      stream: bentoStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _emptyBox("Error loading notices");
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: midnightBlue));
        final data = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _bentoTile(
                title: (data['event']?.isNotEmpty ?? false) ? (data['event']![0]['title'] ?? "TBD") : "No Upcoming Events",
                subtitle: "Upcoming Event",
                gradient: const LinearGradient(colors: [Color(0xFFB88252), Color(0xFF7F5539)]),
                icon: Icons.auto_awesome,
                isSmall: true,
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _bentoTile(
                        title: (data['holiday']?.isNotEmpty ?? false) ? (data['holiday']![0]['title'] ?? "Normal Day") : "No Holidays",
                        subtitle: "Next Holiday",
                        gradient: const LinearGradient(colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)]),
                        icon: Icons.calendar_month,
                        isSmall: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _bentoTile(
                        title: (data['alert']?.isNotEmpty ?? false) ? (data['alert']![0]['title'] ?? "Alert") : "All Clear",
                        subtitle: "Urgent Alert",
                        gradient: const LinearGradient(colors: [Color(0xFF5A189A), Color(0xFF3C096C)]),
                        icon: Icons.notifications_active,
                        isSmall: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bentoTile({required String title, required String subtitle, required LinearGradient gradient, required IconData icon, required bool isSmall}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: gradient.colors.last.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle.toUpperCase(),
            style: GoogleFonts.archivo(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: isSmall ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sahitya(color: Colors.white, fontSize: isSmall ? 22 : 20, fontWeight: FontWeight.bold, height: 1.1),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String collection, IconData icon, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        String val = snapshot.hasData ? snapshot.data!.docs.length.toString() : "0";
        var docs = snapshot.data?.docs ?? [];
        return InkWell(
          onTap: () => _showInfoBox(
              context,
              "ALL EVENTS",
              Column(
                children: docs.map((doc) => ListTile(
                  leading: const Icon(Icons.bookmark, color: Colors.cyanAccent, size: 20),
                  title: Text(doc['title'] ?? "Unnamed", style: const TextStyle(color: Colors.white)),
                )).toList(),
              )
          ),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Icon(icon, color: color, size: 24),
              Text(val, style: GoogleFonts.archivo(fontSize: 24, fontWeight: FontWeight.bold, color: midnightBlue)),
              Text(title, style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildRegistrationTotalCard(String title, IconData icon, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('events').snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        var docs = snapshot.data?.docs ?? [];
        if (snapshot.hasData) {
          for (var doc in docs) {
            var d = doc.data() as Map<String, dynamic>;
            total += (d['interestedStudents'] as List? ?? []).length;
          }
        }
        return InkWell(
          onTap: () => _showInfoBox(
              context,
              "REGISTRATION LIST",
              Column(
                children: docs.map((doc) {
                  List students = doc['interestedStudents'] ?? [];
                  if (students.isEmpty) return const SizedBox();
                  return ExpansionTile(
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white70,
                    title: Text(doc['title'] ?? "Event", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("${students.length} Registered", style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                    children: students.map((s) {
                      return ListTile(
                        dense: true,
                        leading: Text(s['studentId'] ?? "N/A", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        title: Text(s['fullName'] ?? "N/A", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        trailing: const Icon(Icons.check_circle, color: Colors.green, size: 14),
                      );
                    }).toList(),
                  );
                }).toList(),
              )
          ),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Icon(icon, color: color, size: 24),
              Text(total.toString(), style: GoogleFonts.archivo(fontSize: 24, fontWeight: FontWeight.bold, color: midnightBlue)),
              Text(title, style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(text, style: GoogleFonts.oswald(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1));
  }

  Widget _buildHODDropdown() {
    return Container(
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text("DEPARTMENT HEADS", style: GoogleFonts.oswald(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          leading: const Icon(Icons.groups, color: Colors.cyanAccent),
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'hod').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                var docs = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['fullName'] ?? "Faculty", style: const TextStyle(color: Colors.white)),
                      subtitle: Text(data['department'] ?? "Dept", style: const TextStyle(color: Colors.white60)),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementRect(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: color),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.oswald(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.white70),
        ]),
      ),
    );
  }

  Widget _emptyBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
      child: Text(msg, style: const TextStyle(color: Colors.white38)),
    );
  }
}