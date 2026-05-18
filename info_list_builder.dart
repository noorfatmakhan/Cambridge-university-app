import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InfoListBuilder extends StatelessWidget {
  final int itemCount;
  final IconData icon;
  final List<Map<String, dynamic>> data;
  final bool canManage;
  final Function(String docId) onDelete;
  final Function(Map<String, dynamic> item) onEdit;
  final Function(Map<String, dynamic> item)? onTap;

  const InfoListBuilder({
    super.key,
    required this.itemCount,
    required this.icon,
    required this.data,
    required this.canManage,
    required this.onDelete,
    required this.onEdit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 140),
      itemCount: itemCount,
      itemBuilder: (context, index) => HoverCard(
        item: data[index],
        icon: icon,
        canManage: canManage,
        onEdit: onEdit,
        onDelete: onDelete,
        onTap: onTap,
      ),
    );
  }
}

class HoverCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final IconData icon;
  final bool canManage;
  final Function(Map<String, dynamic>) onEdit;
  final Function(String) onDelete;
  final Function(Map<String, dynamic>)? onTap;

  const HoverCard({
    super.key,
    required this.item,
    required this.icon,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color midnightBlue = Color(0xFF03045E);
    const Color skyBlue = Color(0xFF00B4D8);

    final bool isEvent = item.containsKey('fee');
    final String displayDescription = item['description'] ?? item['subtitle'] ?? "";
    final bool showCount = item['showRegistrationCount'] ?? false;

    return GestureDetector(
      onTap: () => onTap?.call(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: midnightBlue, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 40,
              margin: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                color: midnightBlue,
                borderRadius: BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: midnightBlue, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item['title']?.toUpperCase() ?? "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.oswald(fontSize: 18, fontWeight: FontWeight.bold, color: midnightBlue),
                          ),
                        ),
                        if (canManage) ...[
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                            onPressed: () => onEdit(item),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                            onPressed: () => _confirmDelete(context, item['id']),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (displayDescription.isNotEmpty)
                      Text(
                        displayDescription,
                        style: const TextStyle(color: Colors.black, fontSize: 14, height: 1.2),
                      ),
                    const SizedBox(height: 8),
                    if (item['date'] != null) _verticalInfo(Icons.calendar_month, item['date'], skyBlue),
                    if (item['time'] != null) _verticalInfo(Icons.access_time, item['time'], Colors.orange),
                    if (item['venue'] != null) _verticalInfo(Icons.location_on, item['venue'], Colors.redAccent),
                    if (isEvent) ...[
                      const Divider(height: 16, thickness: 0.5),
                      _buildEventFooter(item, skyBlue, midnightBlue, showCount),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalInfo(IconData icon, String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildEventFooter(Map<String, dynamic> item, Color skyBlue, Color midnightBlue, bool showCount) {
    final int fee = item['fee'] ?? 0;
    final int regCount = (item['interestedStudents'] as List?)?.length ?? 0;
    final bool isRegistered = item['isUserRegistered'] ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(fee == 0 ? "FREE ENTRY" : "₹$fee", style: TextStyle(color: skyBlue, fontWeight: FontWeight.bold, fontSize: 13)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCount) ...[
              Icon(Icons.people_outline, color: midnightBlue.withOpacity(0.7), size: 15),
              const SizedBox(width: 2),
              Text("$regCount", style: TextStyle(color: midnightBlue.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 11)),
            ],
            if (!canManage) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 26,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRegistered ? Colors.grey : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                  ),
                  onPressed: () => onTap?.call(item),
                  child: Text(
                      isRegistered ? "REGISTERED" : "REGISTER",
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete permanently?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(onPressed: () {
            onDelete(docId); Navigator.pop(context); },
              child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}