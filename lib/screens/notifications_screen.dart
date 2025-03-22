import 'package:flutter/material.dart';
import 'custom_app_bar.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Notificaciones",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (context, index) => SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _buildNotificationCard(
                    icon: notification["icon"],
                    title: notification["title"],
                    subtitle: notification["subtitle"],
                    onTap: () {
                      // Acción al tocar la notificación
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 3,
      child: ListTile(
        leading: Icon(icon, size: 40, color: Colors.orange),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

final List<Map<String, dynamic>> notifications = [
  {
    "icon": Icons.pets,
    "title": "AYUDA, SE HA PERDIDO UNA MASCOTA CERCA DE TU CASA",
    "subtitle":
        "Un perrito fue visto por última vez en tu zona. ¡Revisa la publicación!",
  },
  {
    "icon": Icons.favorite,
    "title": "HEMOS ENCONTRADO UNA MASCOTA PARA TI",
    "subtitle":
        "Un rescatista ha encontrado una mascota que puede interesarte.",
  },
];
