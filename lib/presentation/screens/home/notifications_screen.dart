import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.green.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _notificationCard(
              "Bill Payment Reminder",
              "Your electricity bill (₦45,000) is due in 5 days",
              Icons.warning,
              Colors.orange,
              "2 hours ago",
            ),
            _notificationCard(
              "Receipt Printed Successfully",
              "Receipt TRX-20240407-001 has been printed",
              Icons.check_circle,
              Colors.green,
              "Today, 2:45 PM",
            ),
            _notificationCard(
              "Low Printer Paper",
              "Your printer paper is running low. Please refill soon.",
              Icons.error,
              Colors.red,
              "Today, 10:30 AM",
            ),
            _notificationCard(
              "Transaction Confirmed",
              "₦125,000 from livestock sale has been received",
              Icons.trending_up,
              Colors.blue,
              "Yesterday, 3:15 PM",
            ),
            _notificationCard(
              "Account Update",
              "Your account has been successfully updated",
              Icons.account_circle,
              Colors.purple,
              "2 days ago",
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationCard(
    String title,
    String description,
    IconData icon,
    Color color,
    String time,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
