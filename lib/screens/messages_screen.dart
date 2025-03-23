import 'package:flutter/material.dart';
import 'custom_app_bar.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

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
              "Mensajes",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: messages.length,
                separatorBuilder: (context, index) => SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _buildMessageTile(
                    avatar: message["avatar"],
                    name: message["name"],
                    lastMessage: message["lastMessage"],
                    time: message["time"],
                    onTap: () {
                      // Acción al tocar un mensaje
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

  Widget _buildMessageTile({
    required String avatar,
    required String name,
    required String lastMessage,
    required String time,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(backgroundImage: AssetImage(avatar), radius: 25),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          time,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        onTap: onTap,
      ),
    );
  }
}

final List<Map<String, dynamic>> messages = [
  {
    "avatar": "assets/images/profile.jpg",
    "name": "Usuario 1",
    "lastMessage": "Hola, ¿cómo estás?",
    "time": "10:45 AM",
  },
  {
    "avatar": "assets/images/profile.jpg",
    "name": "Usuario 2",
    "lastMessage": "Recibí la información, gracias!",
    "time": "Ayer",
  },
];
