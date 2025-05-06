

import 'package:flutter/material.dart';
import '../screens/comment_screen.dart';

class PostDetailModal extends StatelessWidget {
  final dynamic post;
  final String mediaUrl;
  final Function(int) onMessagePressed;

  const PostDetailModal({
    super.key,
    required this.post,
    required this.mediaUrl,
    required this.onMessagePressed,
  });

  @override
  Widget build(BuildContext context) {
    final pet = post['pet'];
    final images = post['images'] as List<dynamic>;
    final user = post['user'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    "$mediaUrl${images[index]['imgURL']}",
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.error)),
                      );
                    },
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: user != null && user['profilePhoto'] != null
                          ? NetworkImage("$mediaUrl${user['profilePhoto']}")
                          : const AssetImage("assets/default_profile.jpg") as ImageProvider,
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      user != null ? "${user['name']} ${user['first_name']}" : "Usuario",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  pet['name'] ?? "Sin nombre",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("Edad: ${pet['age'] ?? "Desconocida"}"),
                const SizedBox(height: 4),
                Text("Raza: ${pet['breed'] ?? "Desconocida"}"),
                const SizedBox(height: 4),
                Text("Tamaño: ${pet['size'] ?? "Desconocido"}"),
                const SizedBox(height: 16),
                Text(
                  post['description'] ?? "Sin descripción",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.comment),
                      label: const Text("Comentar"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentScreen(postId: post['id']),
                          ),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.message, color: Colors.green),
                      label: const Text("Enviar mensaje"),
                      onPressed: () => onMessagePressed(user['id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}